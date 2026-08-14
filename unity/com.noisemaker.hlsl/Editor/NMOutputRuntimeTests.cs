#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using Noisemaker.Hlsl.Compiler.Graph;
using UnityEditor;
using UnityEngine;

namespace Noisemaker.Hlsl.Editor
{
    public static class NMOutputRuntimeTests
    {
        private sealed class RecordingSink : INMOutputSink
        {
            public NMOutputDescriptor Descriptor;
            public int Submissions;
            public int Closes;
            public double LastTimestamp;
            public RenderTexture LastTexture;
            public NMOutputCloseOptions CloseOptions;
            public Action OnConfigure;
            public Action OnSubmit;
            public bool Accept = true;
            public bool ThrowOnClose;

            public void Configure(NMOutputDescriptor descriptor)
            {
                Descriptor = descriptor;
                OnConfigure?.Invoke();
            }

            public bool Submit(RenderTexture texture, double timestampMilliseconds)
            {
                Check(texture != null, "sink received a null texture");
                Check(timestampMilliseconds >= 0.0, "sink received a negative timestamp");
                Submissions++;
                LastTimestamp = timestampMilliseconds;
                LastTexture = texture;
                OnSubmit?.Invoke();
                return Accept;
            }

            public void Close(NMOutputCloseOptions options = null)
            {
                Closes++;
                CloseOptions = options;
                if (ThrowOnClose) throw new InvalidOperationException("close failure");
            }
        }

        private sealed class FakeFrameExportAdapter : INMFrameExportAdapter
        {
            internal sealed class Slot
            {
                public bool Pending;
                public bool Ready;
                public bool Destroyed;
                public readonly NMFrameExportFrame Frame =
                    new NMFrameExportFrame(1, 1, 4, new byte[] { 1, 2, 3, 4 });
            }

            public readonly List<Slot> Slots = new List<Slot>();
            public int DestroyCalls;
            public bool ThrowOnBegin;
            public int ThrowOnCreateIndex = -1;

            public object CreateSlot(int index, NMOutputDescriptor descriptor)
            {
                if (index == ThrowOnCreateIndex) throw new InvalidOperationException("create failure");
                var slot = new Slot();
                Slots.Add(slot);
                return slot;
            }

            public void Begin(object adapterSlot, RenderTexture texture, double timestampMilliseconds)
            {
                if (ThrowOnBegin) throw new InvalidOperationException("begin failure");
                ((Slot)adapterSlot).Pending = true;
            }

            public bool Poll(object adapterSlot)
            {
                var slot = (Slot)adapterSlot;
                if (!slot.Pending) throw new InvalidOperationException("slot is not pending");
                return slot.Ready;
            }

            public NMFrameExportFrame Read(object adapterSlot)
            {
                var slot = (Slot)adapterSlot;
                slot.Pending = false;
                slot.Ready = false;
                return slot.Frame;
            }

            public void DestroySlot(object adapterSlot)
            {
                var slot = (Slot)adapterSlot;
                if (slot.Destroyed) return;
                slot.Destroyed = true;
                DestroyCalls++;
            }
        }

        private static readonly List<NMFrameExportQueue> GpuQueues =
            new List<NMFrameExportQueue>();
        private static RenderTexture _gpuSource;
        private static Texture2D _gpuSourceTexture;
        private static double _gpuDeadline;
        private static Exception _gpuFailure;
        private static bool _gpuCompleted;
        private static bool _gpuReuseEnqueued;
        private static int _gpuCallbacks;

        public static void VerifyFromCommandLine()
        {
            try
            {
                TestSinkManager();
                TestFrameExportQueue();
                TestPipelineSinkIntegration();
                StartGpuExportTest();
            }
            catch (Exception error)
            {
                FailAndExit(error);
            }
        }

        private static void TestSinkManager()
        {
            int reported = 0;
            var manager = new NMSinkManager((error, sink) => reported++);
            var descriptor = new NMOutputDescriptor(4, 3, NMOutputAlphaMode.Premultiplied);
            manager.Configure(descriptor);

            var first = new RecordingSink();
            var second = new RecordingSink();
            manager.Add(first);
            Action removeSecond = manager.Add(second);
            first.OnSubmit = removeSecond;

            Check(ReferenceEquals(first.Descriptor, descriptor), "late sink was not configured");
            Check(ReferenceEquals(second.Descriptor, descriptor), "late sink descriptor changed");
            Throws<InvalidOperationException>(() => manager.Add(first), "duplicate sink accepted");

            var source = new RenderTexture(1, 1, 0);
            try
            {
                manager.Submit(source, 10.0);
                Check(first.Submissions == 1, "active sink missed submission");
                Check(second.Submissions == 0, "removed sink ran during reentrant submit");
                Check(second.Closes == 1, "removed sink was not closed exactly once");
                removeSecond();
                Check(second.Closes == 1, "removal callback was not idempotent");
                Check(manager.Stats[first].Accepted == 1, "accepted sink stat is wrong");

                first.OnConfigure = () => throw new InvalidOperationException("configure failure");
                manager.Configure(descriptor);
                Check(manager.Stats[first].Failed == 1, "configure failure stat is wrong");
                Check(reported == 1, "configure failure was not isolated and reported");
            }
            finally
            {
                source.Release();
                UnityEngine.Object.DestroyImmediate(source);
            }

            first.ThrowOnClose = true;
            var closeOptions = new NMOutputCloseOptions(true);
            Throws<InvalidOperationException>(() => manager.Close(closeOptions),
                "sink close failure was swallowed");
            Check(first.Closes == 1, "manager did not close its sink");
            Check(ReferenceEquals(first.CloseOptions, closeOptions), "close options were not forwarded");
            manager.Close();
        }

        private static void TestFrameExportQueue()
        {
            int errors = 0;
            var adapter = new FakeFrameExportAdapter();
            var queue = new NMFrameExportQueue(adapter, 2, error => errors++);
            var descriptor = new NMOutputDescriptor(1, 1, NMOutputAlphaMode.Straight);
            queue.Configure(descriptor);
            Check(queue.Available, "configured queue should be available");

            var source = new RenderTexture(1, 1, 0);
            object firstContext = new object();
            bool firstCalled = false;
            try
            {
                Check(queue.Enqueue(source, 11.0, (frame, timestamp, context) =>
                {
                    Check(frame.Data[2] == 3, "frame payload changed");
                    Check(timestamp == 11.0, "frame timestamp changed");
                    Check(ReferenceEquals(context, firstContext), "frame context changed");
                    firstCalled = true;
                }, firstContext), "first frame was not accepted");

                Check(queue.Enqueue(source, 12.0, (frame, timestamp, context) =>
                {
                    throw new InvalidOperationException("callback failure");
                }), "second frame was not accepted");
                Check(!queue.Available, "saturated queue reported availability");
                Check(!queue.Enqueue(source, 13.0, (frame, timestamp, context) => { }),
                    "saturated queue accepted a frame");

                adapter.Slots[0].Ready = true;
                adapter.Slots[1].Ready = true;
                queue.Poll();
                Check(firstCalled, "ready frame callback did not run");
                Check(queue.Stats.Accepted == 2 && queue.Stats.Dropped == 1,
                    "queue accepted/dropped stats are wrong");
                Check(queue.Stats.Completed == 1 && queue.Stats.Failed == 1,
                    "queue completed/failed stats are wrong");
                Check(errors == 1, "callback failure was not isolated and reported");
                Check(queue.Available, "completed slots were not released");

                adapter.ThrowOnBegin = true;
                Check(!queue.Enqueue(source, 14.0, (frame, timestamp, context) => { }),
                    "begin failure was reported as accepted");
                Check(queue.Stats.Failed == 2 && errors == 2,
                    "begin failure stats are wrong");
            }
            finally
            {
                source.Release();
                UnityEngine.Object.DestroyImmediate(source);
            }

            queue.Close(new NMOutputCloseOptions(true));
            Check(adapter.DestroyCalls == 0, "backend-lost close touched adapter slots");
            queue.Close();

            adapter = new FakeFrameExportAdapter { ThrowOnCreateIndex = 1 };
            queue = new NMFrameExportQueue(adapter, 2);
            Throws<InvalidOperationException>(() => queue.Configure(descriptor),
                "partial slot allocation failure was swallowed");
            Check(adapter.DestroyCalls == 1, "partial slot allocation was not rolled back");
            Check(!queue.Available, "failed configuration left queue available");
            queue.Close();
        }

        private static void TestPipelineSinkIntegration()
        {
            PreloadPackageShaders();
            RenderGraph graph = CreateSolidGraph();
            var pipeline = new NMPipeline(graph);
            var sink = new RecordingSink();
            pipeline.AddSink(sink);
            try
            {
                pipeline.Init(2, 2);
                Check(sink.Descriptor.Width == 2 && sink.Descriptor.Height == 2,
                    "pipeline did not configure sink extent");
                Check(sink.Descriptor.AlphaMode == NMOutputAlphaMode.Premultiplied,
                    "pipeline sink alpha mode differs from reference");
                pipeline.Render(0.25f, 4321.5);
                Check(sink.Submissions == 1, "pipeline did not submit its rendered frame");
                Check(sink.LastTimestamp == 4321.5,
                    "pipeline did not preserve an explicit presentation timestamp");
                Check(ReferenceEquals(sink.LastTexture, pipeline.GetOutput()),
                    "pipeline did not submit its selected pre-swap output texture");
            }
            finally
            {
                pipeline.Dispose();
            }
            Check(sink.Closes == 1, "pipeline did not close its sink");
        }

        private static RenderGraph CreateSolidGraph()
        {
            var graph = new RenderGraph { Id = "output-test", RenderSurface = "o0" };
            var solid = new Pass
            {
                Id = "solid",
                PassType = PassType.Effect,
                Namespace = "synth",
                Func = "solid",
                ProgName = "solid"
            };
            solid.Outputs.Add("color", "solid_out");
            solid.Uniforms.Add("color", UniformValue.Of(new double[] { 0.2, 0.4, 0.6 }));
            solid.Uniforms.Add("alpha", UniformValue.Of(1.0));
            graph.Passes.Add(solid);

            var blit = new Pass
            {
                Id = "write",
                PassType = PassType.Blit,
                Func = "blit",
                ProgName = "blit"
            };
            blit.Inputs.Add("src", "solid_out");
            blit.Outputs.Add("color", "global_o0");
            graph.Passes.Add(blit);
            graph.Textures.Add("solid_out", new TextureSpec
            {
                Width = Dim.FromScreen(),
                Height = Dim.FromScreen(),
                Format = "rgba16f"
            });
            graph.Allocations.Add("solid_out", "phys_0");
            return graph;
        }

        private static void StartGpuExportTest()
        {
            Shader shader = FindShader(NMUnityFrameExportAdapter.ResolveShaderName);
            Check(shader != null, "frame-export resolve shader was not imported");

            _gpuSourceTexture = new Texture2D(2, 2, TextureFormat.RGBAFloat, false, true)
            {
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp
            };
            _gpuSourceTexture.SetPixels(new[]
            {
                new Color(1f, 0.5f, 0.25f, 0.5f), new Color(0f, 1f, 0f, 1f),
                new Color(0.25f, 0.5f, 0.75f, 0.25f), new Color(2f, -1f, 0.5f, 1f)
            });
            _gpuSourceTexture.Apply(false);

            _gpuSource = new RenderTexture(2, 2, 0, RenderTextureFormat.ARGBFloat,
                RenderTextureReadWrite.Linear)
            {
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp,
                useMipMap = false,
                autoGenerateMips = false
            };
            _gpuSource.Create();
            Graphics.Blit(_gpuSourceTexture, _gpuSource);

            GpuQueues.Clear();
            _gpuCompleted = false;
            _gpuReuseEnqueued = false;
            _gpuCallbacks = 0;
            NMOutputAlphaMode[] modes =
            {
                NMOutputAlphaMode.Straight,
                NMOutputAlphaMode.Opaque,
                NMOutputAlphaMode.Premultiplied
            };
            for (int i = 0; i < modes.Length; i++)
            {
                var queue = new NMFrameExportQueue(new NMUnityFrameExportAdapter(shader), 2,
                    error => _gpuFailure = error);
                queue.Configure(new NMOutputDescriptor(2, 2, modes[i]));
                Check(queue.Enqueue(_gpuSource, 123.5 + i, VerifyGpuFrame, i),
                    "Unity GPU frame was not accepted for " + modes[i]);
                GpuQueues.Add(queue);
            }

            SetGpuSource(new Color(1f, 0f, 0f, 0.5f));
            Check(GpuQueues[2].Enqueue(_gpuSource, 126.5, VerifyGpuFrame, 3),
                "second in-flight Unity GPU frame was not accepted");
            _gpuDeadline = EditorApplication.timeSinceStartup + 15.0;
            EditorApplication.update += PollGpuExport;
        }

        private static void PollGpuExport()
        {
            try
            {
                for (int i = 0; i < GpuQueues.Count; i++) GpuQueues[i].Poll();
                if (_gpuFailure != null) throw _gpuFailure;
                if (_gpuCallbacks == 4 && !_gpuReuseEnqueued)
                {
                    _gpuReuseEnqueued = true;
                    SetGpuSource(new Color(0f, 0f, 1f, 0.25f));
                    Check(GpuQueues[2].Enqueue(_gpuSource, 127.5, VerifyGpuFrame, 4),
                        "reused Unity GPU slot did not accept a frame");
                }
                if (_gpuCompleted)
                {
                    CleanupGpuExport();
                    Debug.Log("[NMOutputRuntimeTests] PASS");
                    EditorApplication.Exit(0);
                    return;
                }
                if (EditorApplication.timeSinceStartup > _gpuDeadline)
                    throw new TimeoutException("Unity GPU frame export did not complete asynchronously");
            }
            catch (Exception error)
            {
                CleanupGpuExport();
                FailAndExit(error);
            }
        }

        private static void VerifyGpuFrame(NMFrameExportFrame frame, double timestamp,
            object context)
        {
            Check(frame.Width == 2 && frame.Height == 2 && frame.RowStride == 8,
                "Unity GPU frame layout is wrong");
            int frameKind = (int)context;
            Check(timestamp == 123.5 + frameKind,
                "Unity GPU timestamp changed");
            byte[] expectedTopDown;
            if (frameKind == 0)
            {
                expectedTopDown = new byte[]
                {
                    64, 128, 191, 64, 255, 0, 128, 255,
                    255, 128, 64, 128, 0, 255, 0, 255
                };
            }
            else if (frameKind == 1)
            {
                expectedTopDown = new byte[]
                {
                    64, 128, 191, 255, 255, 0, 128, 255,
                    255, 128, 64, 255, 0, 255, 0, 255
                };
            }
            else if (frameKind == 2)
            {
                expectedTopDown = new byte[]
                {
                    16, 32, 48, 64, 255, 0, 128, 255,
                    128, 64, 32, 128, 0, 255, 0, 255
                };
            }
            else
            {
                byte r = frameKind == 3 ? (byte)128 : (byte)0;
                byte b = frameKind == 4 ? (byte)64 : (byte)0;
                byte a = frameKind == 3 ? (byte)128 : (byte)64;
                expectedTopDown = new byte[16];
                for (int i = 0; i < 4; i++)
                {
                    expectedTopDown[i * 4] = r;
                    expectedTopDown[i * 4 + 2] = b;
                    expectedTopDown[i * 4 + 3] = a;
                }
            }
            Check(frame.Data.Length == expectedTopDown.Length, "Unity GPU byte length is wrong");
            for (int i = 0; i < expectedTopDown.Length; i++)
                Check(frame.Data[i] == expectedTopDown[i],
                    "Unity GPU byte mismatch at " + i + ": got " + frame.Data[i] +
                    ", expected " + expectedTopDown[i]);
            _gpuCallbacks++;
            _gpuCompleted = _gpuCallbacks == 5;
        }

        private static void SetGpuSource(Color color)
        {
            _gpuSourceTexture.SetPixels(new[] { color, color, color, color });
            _gpuSourceTexture.Apply(false);
            Graphics.Blit(_gpuSourceTexture, _gpuSource);
        }

        private static void CleanupGpuExport()
        {
            EditorApplication.update -= PollGpuExport;
            for (int i = 0; i < GpuQueues.Count; i++) GpuQueues[i].Close();
            GpuQueues.Clear();
            if (_gpuSource != null)
            {
                _gpuSource.Release();
                UnityEngine.Object.DestroyImmediate(_gpuSource);
                _gpuSource = null;
            }
            if (_gpuSourceTexture != null)
            {
                UnityEngine.Object.DestroyImmediate(_gpuSourceTexture);
                _gpuSourceTexture = null;
            }
        }

        private static void PreloadPackageShaders()
        {
            var byName = new Dictionary<string, Shader>();
            foreach (string guid in AssetDatabase.FindAssets("t:Shader",
                new[] { "Packages/com.noisemaker.hlsl" }))
            {
                Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(
                    AssetDatabase.GUIDToAssetPath(guid));
                if (shader != null) byName[shader.name] = shader;
            }
            NMShaderRegistry.ExternalResolver = name =>
            {
                Shader shader;
                return byName.TryGetValue(name, out shader) ? shader : null;
            };
        }

        private static Shader FindShader(string shaderName)
        {
            foreach (string guid in AssetDatabase.FindAssets("t:Shader",
                new[] { "Packages/com.noisemaker.hlsl" }))
            {
                Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(
                    AssetDatabase.GUIDToAssetPath(guid));
                if (shader != null && shader.name == shaderName) return shader;
            }
            return null;
        }

        private static void Check(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }

        private static void Throws<T>(Action action, string message) where T : Exception
        {
            try
            {
                action();
            }
            catch (T)
            {
                return;
            }
            throw new InvalidOperationException(message);
        }

        private static void FailAndExit(Exception error)
        {
            Debug.LogError("[NMOutputRuntimeTests] FAIL: " + error);
            EditorApplication.Exit(1);
        }
    }
}
#endif
