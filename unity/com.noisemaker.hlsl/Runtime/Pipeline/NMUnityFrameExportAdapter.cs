using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace Noisemaker.Hlsl
{
    public sealed class NMUnityFrameExportAdapter : INMFrameExportAdapter
    {
        public const string ResolveShaderName = "Noisemaker/FrameExportResolve";

        private enum SlotState
        {
            Idle,
            Pending,
            Ready,
            Failed,
            Destroyed
        }

        private sealed class Slot
        {
            public int Width;
            public int Height;
            public NMOutputAlphaMode AlphaMode;
            public RenderTexture ResolveTexture;
            public Material Material;
            public CommandBuffer Commands;
            public byte[] Data;
            public NMFrameExportFrame Frame;
            public SlotState State;
            public Exception Error;
            public int Generation;
            public bool Registered;
            public bool DestroyRequested;
        }

        private static readonly int SourceId = Shader.PropertyToID("_NMExportSource");
        private static readonly int ExtentId = Shader.PropertyToID("_NMExportExtent");
        private static readonly int AlphaModeId = Shader.PropertyToID("_NMExportAlphaMode");

        private readonly Shader _resolveShader;

        public NMUnityFrameExportAdapter(Shader resolveShader = null)
        {
            if (resolveShader == null && NMShaderRegistry.ExternalResolver != null)
                resolveShader = NMShaderRegistry.ExternalResolver(ResolveShaderName);
            if (resolveShader == null) resolveShader = Shader.Find(ResolveShaderName);
            if (resolveShader == null)
                throw new InvalidOperationException("Shader not found: " + ResolveShaderName);
            _resolveShader = resolveShader;
        }

        public object CreateSlot(int index, NMOutputDescriptor descriptor)
        {
            if (descriptor == null) throw new ArgumentNullException(nameof(descriptor));
            if (descriptor.Format != NMOutputFormat.Rgba8Unorm)
                throw new ArgumentException("Unity frame export requires RGBA8 UNorm", nameof(descriptor));
            if (descriptor.ColorSpace != NMOutputColorSpace.Srgb &&
                descriptor.ColorSpace != NMOutputColorSpace.DisplayP3)
                throw new ArgumentException("Unsupported frame export color space", nameof(descriptor));

            int byteLength = checked(checked(descriptor.Width * descriptor.Height) * 4);
            var slot = new Slot
            {
                Width = descriptor.Width,
                Height = descriptor.Height,
                AlphaMode = descriptor.AlphaMode,
                Data = new byte[byteLength],
                State = SlotState.Idle
            };
            slot.Frame = new NMFrameExportFrame(slot.Width, slot.Height,
                checked(slot.Width * 4), slot.Data);

            try
            {
                slot.ResolveTexture = new RenderTexture(slot.Width, slot.Height, 0,
                    RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear)
                {
                    name = "NMFrameExportResolve" + index,
                    filterMode = FilterMode.Point,
                    wrapMode = TextureWrapMode.Clamp,
                    useMipMap = false,
                    autoGenerateMips = false,
                    enableRandomWrite = false
                };
                if (!slot.ResolveTexture.Create())
                    throw new InvalidOperationException("Failed to create Unity frame export texture");
                slot.Material = new Material(_resolveShader)
                {
                    hideFlags = HideFlags.HideAndDontSave
                };
                slot.Material.SetVector(ExtentId,
                    new Vector4(slot.Width, slot.Height, 0f, 0f));
                slot.Material.SetInt(AlphaModeId, (int)slot.AlphaMode);
                slot.Commands = new CommandBuffer { name = "Noisemaker Frame Export " + index };
                slot.Registered = true;
                return slot;
            }
            catch
            {
                Cleanup(slot);
                throw;
            }
        }

        public void Begin(object adapterSlot, RenderTexture texture,
            double timestampMilliseconds)
        {
            Slot slot = RequireUsable(adapterSlot);
            if (slot.State != SlotState.Idle)
                throw new InvalidOperationException("Unity frame export slot is already pending");
            if (texture == null)
                throw new ArgumentNullException(nameof(texture));
            if (texture.width != slot.Width || texture.height != slot.Height)
                throw new ArgumentException("Unity frame export source extent " + texture.width + "x" +
                    texture.height + " does not match configured extent " + slot.Width + "x" +
                    slot.Height, nameof(texture));

            CommandBuffer commands = slot.Commands;
            commands.Clear();
            commands.SetRenderTarget(slot.ResolveTexture);
            commands.SetViewport(new Rect(0f, 0f, slot.Width, slot.Height));
            commands.ClearRenderTarget(false, true, Color.clear);
            commands.SetGlobalTexture(SourceId, texture);
            commands.DrawProcedural(Matrix4x4.identity, slot.Material, 0,
                MeshTopology.Triangles, 3, 1);

            int generation = ++slot.Generation;
            slot.Error = null;
            slot.State = SlotState.Pending;
            try
            {
                commands.RequestAsyncReadback(slot.ResolveTexture, 0, TextureFormat.RGBA32,
                    request => Complete(slot, generation, request));
                Graphics.ExecuteCommandBuffer(commands);
            }
            catch
            {
                slot.Generation++;
                slot.State = SlotState.Idle;
                throw;
            }
        }

        public bool Poll(object adapterSlot)
        {
            Slot slot = RequireUsable(adapterSlot);
            if (slot.State == SlotState.Pending) return false;
            if (slot.State == SlotState.Ready) return true;
            if (slot.State == SlotState.Failed)
            {
                Exception error = slot.Error ??
                    new InvalidOperationException("Unity frame export readback failed");
                slot.Error = null;
                slot.State = SlotState.Idle;
                throw error;
            }
            throw new InvalidOperationException("Unity frame export slot has no pending readback");
        }

        public NMFrameExportFrame Read(object adapterSlot)
        {
            Slot slot = RequireUsable(adapterSlot);
            if (slot.State != SlotState.Ready)
                throw new InvalidOperationException("Unity frame export slot is not ready");
            slot.State = SlotState.Idle;
            return slot.Frame;
        }

        public void DestroySlot(object adapterSlot)
        {
            Slot slot = adapterSlot as Slot;
            if (slot == null || slot.DestroyRequested) return;
            slot.DestroyRequested = true;
            slot.Registered = false;
            if (slot.State == SlotState.Pending) return;
            Cleanup(slot);
        }

        private static Slot RequireUsable(object adapterSlot)
        {
            Slot slot = adapterSlot as Slot;
            if (slot == null || !slot.Registered || slot.DestroyRequested ||
                slot.State == SlotState.Destroyed)
                throw new InvalidOperationException("Unity frame export slot is not usable");
            return slot;
        }

        private static void Complete(Slot slot, int generation, AsyncGPUReadbackRequest request)
        {
            if (slot.Generation != generation || slot.State != SlotState.Pending) return;
            if (slot.DestroyRequested)
            {
                Cleanup(slot);
                return;
            }

            if (request.hasError)
            {
                slot.Error = new InvalidOperationException("Unity frame export GPU readback failed");
                slot.State = SlotState.Failed;
                return;
            }

            try
            {
                request.GetData<byte>().CopyTo(slot.Data);
                // Unity's texture byte arrays are bottom-up; the export contract is top-down.
                FlipRowsTopDown(slot.Data, slot.Width * 4, slot.Height);
                slot.State = SlotState.Ready;
            }
            catch (Exception error)
            {
                slot.Error = error;
                slot.State = SlotState.Failed;
            }
        }

        private static void FlipRowsTopDown(byte[] data, int rowStride, int height)
        {
            for (int top = 0, bottom = height - 1; top < bottom; top++, bottom--)
            {
                int topOffset = top * rowStride;
                int bottomOffset = bottom * rowStride;
                for (int x = 0; x < rowStride; x++)
                {
                    byte value = data[topOffset + x];
                    data[topOffset + x] = data[bottomOffset + x];
                    data[bottomOffset + x] = value;
                }
            }
        }

        private static void Cleanup(Slot slot)
        {
            if (slot == null || slot.State == SlotState.Destroyed) return;
            slot.State = SlotState.Destroyed;
            slot.Registered = false;
            slot.Error = null;
            if (slot.Commands != null)
            {
                slot.Commands.Release();
                slot.Commands = null;
            }
            if (slot.Material != null)
            {
                DestroyObject(slot.Material);
                slot.Material = null;
            }
            if (slot.ResolveTexture != null)
            {
                slot.ResolveTexture.Release();
                DestroyObject(slot.ResolveTexture);
                slot.ResolveTexture = null;
            }
        }

        private static void DestroyObject(UnityEngine.Object value)
        {
#if UNITY_EDITOR
            UnityEngine.Object.DestroyImmediate(value);
#else
            UnityEngine.Object.Destroy(value);
#endif
        }
    }
}
