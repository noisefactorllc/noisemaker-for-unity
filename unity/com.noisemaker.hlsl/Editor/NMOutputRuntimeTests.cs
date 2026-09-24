#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.Reflection;
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
            public bool Defer;
            public bool ThrowOnDefer;

            public bool DeferRender()
            {
                if (ThrowOnDefer) throw new InvalidOperationException("defer failure");
                return Defer;
            }

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

        private sealed class DefaultInterfaceSink : INMOutputSink
        {
            public void Configure(NMOutputDescriptor descriptor) { }
            public bool Submit(RenderTexture texture, double timestampMilliseconds) => true;
            public void Close(NMOutputCloseOptions options = null) { }
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
                TestDeviceLimitPolicy();
                TestPipelineSinkIntegration();
                TestMeshChainScopeResolution();
                TestMeshRenderShadedOutput();
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

                Check(!manager.ShouldDeferRender(), "non-deferring sink should not defer render");
                first.Defer = true;
                Check(manager.ShouldDeferRender(), "active deferring sink did not defer render");
                first.Defer = false;
                Check(!manager.ShouldDeferRender(), "restored non-deferring sink deferred render");

                first.ThrowOnDefer = true;
                Check(!manager.ShouldDeferRender(), "throwing defer sink should not defer render");
                Check(manager.Stats[first].Failed == 2, "throwing defer stat was not incremented");
                Check(reported == 2, "throwing defer error was not isolated and reported");
                first.ThrowOnDefer = false;
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
            Check(!manager.ShouldDeferRender(), "closed manager reported deferral");
            manager.Close();
            Check(!manager.ShouldDeferRender(), "double-closed manager reported deferral");

            var multiMgr = new NMSinkManager((error, sink) => reported++);
            var sinkA = new RecordingSink();
            var sinkB = new RecordingSink();
            var defaultSink = new DefaultInterfaceSink();
            multiMgr.Add(sinkA);
            multiMgr.Add(sinkB);
            multiMgr.Add(defaultSink);
            Check(!multiMgr.ShouldDeferRender(), "multi-sink manager with non-deferring sinks deferred render");

            sinkB.Defer = true;
            Check(multiMgr.ShouldDeferRender(), "second sink deferral was not honoured");

            sinkA.ThrowOnDefer = true;
            Check(multiMgr.ShouldDeferRender(), "throwing sink prevented subsequent sink deferral");
            Check(multiMgr.Stats[sinkA].Failed == 1, "throwing sink stat in multi-mgr not incremented");
            sinkA.ThrowOnDefer = false;
            sinkB.Defer = false;
            Check(!multiMgr.ShouldDeferRender(), "reset multi-sink manager deferred render");
            multiMgr.Close();
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

        private static void TestDeviceLimitPolicy()
        {
            RenderGraph graph = CreateDeviceLimitGraph();
            var pipeline = new NMPipeline(graph);
            try
            {
                ApplyDeviceLimits(pipeline, 8192, 32);

                Pass pass = graph.Passes[0];
                Check(pass.Uniforms["volumeSize"].Number == 64.0,
                    "unscoped volumeSize was not clamped to the texture limit");
                Check(pass.Uniforms["volumeSize_chain_0"].Number == 64.0,
                    "chain-scoped volumeSize was not clamped to the texture limit");
                Check(pass.Uniforms["volumeSize_node_0"].Number == 64.0,
                    "node-scoped volumeSize was not clamped to the texture limit");
                Check(pass.Uniforms["volumeSizeExtra"].Number == 128.0,
                    "an unrelated uniform was modified by volumeSize clamping");

                Check(graph.Textures["xyz"].Format == "rgba32f",
                    "the leading high-precision MRT attachment was demoted");
                Check(graph.Textures["vel"].Format == "rgba16f",
                    "the trailing high-precision MRT attachment was not demoted");
                Check(graph.Textures["rgba"].Format == "rgba8",
                    "the low-precision MRT attachment was modified");

                pipeline.SetUniform("volumeSize", 128.0);
                Check(pass.Uniforms["volumeSize"].Number == 64.0 &&
                    pass.Uniforms["volumeSize_chain_0"].Number == 64.0 &&
                    pass.Uniforms["volumeSize_node_0"].Number == 64.0,
                    "runtime volumeSize update bypassed the device clamp or scoped fan-out");
            }
            finally
            {
                pipeline.Dispose();
            }

            graph = CreateDeviceLimitGraph();
            pipeline = new NMPipeline(graph);
            try
            {
                ApplyDeviceLimits(pipeline, 16384, 64);
                Check(graph.Passes[0].Uniforms["volumeSize"].Number == 128.0,
                    "an admissible volumeSize was clamped");
                Check(graph.Textures["xyz"].Format == "rgba32f" &&
                    graph.Textures["vel"].Format == "rgba32f",
                    "an admissible MRT group was demoted");
            }
            finally
            {
                pipeline.Dispose();
            }

            graph = CreateDeviceLimitGraph();
            pipeline = new NMPipeline(graph);
            try
            {
                ApplyDeviceLimits(pipeline, 2048, 0);
                Check(graph.Passes[0].Uniforms["volumeSize"].Number == 32.0,
                    "volumeSize did not snap down again for a smaller texture limit");
                Check(graph.Textures["vel"].Format == "rgba32f",
                    "a missing MRT budget modified attachment formats");
            }
            finally
            {
                pipeline.Dispose();
            }
        }

        private static RenderGraph CreateDeviceLimitGraph()
        {
            var graph = new RenderGraph();
            var pass = new Pass { Id = "device-limits" };
            pass.Uniforms.Add("volumeSize", UniformValue.Of(128.0));
            pass.Uniforms.Add("volumeSize_chain_0", UniformValue.Of(128.0));
            pass.Uniforms.Add("volumeSize_node_0", UniformValue.Of(128.0));
            pass.Uniforms.Add("volumeSizeExtra", UniformValue.Of(128.0));
            pass.Outputs.Add("color", "xyz");
            pass.Outputs.Add("color1", "vel");
            pass.Outputs.Add("color2", "rgba");
            graph.Passes.Add(pass);
            graph.Textures.Add("xyz", new TextureSpec { Format = "rgba32f" });
            graph.Textures.Add("vel", new TextureSpec { Format = "rgba32f" });
            graph.Textures.Add("rgba", new TextureSpec { Format = "rgba8" });
            return graph;
        }

        private static void ApplyDeviceLimits(NMPipeline pipeline, int maxTextureSize,
            int maxColorBytesPerSample)
        {
            MethodInfo apply = typeof(NMPipeline).GetMethod("ApplyDeviceLimits",
                BindingFlags.Instance | BindingFlags.NonPublic);
            Check(apply != null, "NMPipeline device-limit policy is missing");
            apply.Invoke(pipeline, new object[] { maxTextureSize, maxColorBytesPerSample });
        }

        // Shared mesh fixture for the mesh certification tests: a tiny closed
        // tetrahedron with explicit per-vertex normals (OBJ v//vn form, the same
        // shape the parity corpus exercises via share/meshes/sphere.obj).
        private const string MeshTestObj =
            "# parity tetra\n" +
            "v 0 1 0\n" +
            "v -1 -1 1\n" +
            "v 1 -1 1\n" +
            "v 0 -1 -1\n" +
            "vn 0 1 0\n" +
            "vn -0.5 -0.5 0.5\n" +
            "vn 0.5 -0.5 0.5\n" +
            "vn 0 -0.5 -0.5\n" +
            "f 1//1 2//2 3//3\n" +
            "f 1//1 3//3 4//4\n";

        // Certifies the chain-scoped mesh-binding fix: the compiled graph binds
        // global_mesh0_<attr>_chain_<n> aliases, which MUST resolve to the static
        // mesh-data triplet. Regression: the resolver treated the chain suffix as
        // part of the attribute name, fell through to a zeroed pooled RT, and
        // every mesh vertex read position (0,0,0,w=0) — nothing rasterized.
        private static void TestMeshChainScopeResolution()
        {
            PreloadPackageShaders();
            RenderGraph graph = Noisemaker.Hlsl.Compiler.DslCompiler.Compile(
                "search render\n\nmeshLoader()\n.meshRender()\n.write(o0)\n\nrender(o0)",
                LoadEffectRegistry());
            var pipeline = new NMPipeline(graph);
            try
            {
                pipeline.Init(64, 64);
                var staticPos = pipeline.GetStoredTexture("global_mesh0_positions");
                var staticNrm = pipeline.GetStoredTexture("global_mesh0_normals");
                Check(staticPos != null, "mesh0 positions RT missing after Init");
                Check(staticNrm != null, "mesh0 normals RT missing after Init");
                Check(ReferenceEquals(pipeline.ResolveRead("global_mesh0_positions_chain_0"), staticPos),
                    "chain-scoped positions binding did not resolve to the static mesh triplet");
                Check(ReferenceEquals(pipeline.ResolveRead("global_mesh0_normals_chain_0"), staticNrm),
                    "chain-scoped normals binding did not resolve to the static mesh triplet");

                int verts = pipeline.LoadMeshObj("mesh0", MeshTestObj);
                Check(verts == 6, "mesh upload vertex count mismatch: got " + verts);
                Check(ReadMeshTexelW(staticPos) == 1.0f,
                    "uploaded position texel lost its valid flag (w != 1)");
            }
            finally
            {
                pipeline.Dispose();
            }
        }

        // Certifies the mesh winding fix end-to-end: with the WGSL-style manual
        // clip-Y flip, Metal/Unity culls the NEAR hemisphere under Cull Back and
        // shades the far one — visible normals point -z, diffuse clamps to zero,
        // and the interior collapses to a flat ambient+rim field (measured
        // 131/255 = 0.514 on the parity sphere).
        private static void TestMeshRenderShadedOutput()
        {
            PreloadPackageShaders();
            RenderGraph graph = Noisemaker.Hlsl.Compiler.DslCompiler.Compile(
                "search render\n\nmeshLoader()\n.meshRender()\n.write(o0)\n\nrender(o0)",
                LoadEffectRegistry());
            var pipeline = new NMPipeline(graph);
            try
            {
                pipeline.Init(64, 64);
                string sphere = SphereObj(16, 8);
                int verts = pipeline.LoadMeshObj("mesh0", sphere);
                Check(verts > 0, "sphere upload rejected: " + verts);
                pipeline.Render(0.25f);

                RenderTexture output = pipeline.GetOutput();
                Check(output != null, "mesh program produced no output texture");
                RenderTexture prev = RenderTexture.active;
                RenderTexture.active = output;
                var tex = new Texture2D(64, 64, TextureFormat.RGBAFloat, false);
                tex.ReadPixels(new Rect(0, 0, 64, 64), 0, 0);
                tex.Apply();
                var px = tex.GetPixelData<UnityEngine.Color>(0);
                // GetPixelData returns a native view over the texture; copy out
                // BEFORE destroying it or every later read throws
                // ObjectDisposedException.
                var pixels = new UnityEngine.Color[64 * 64];
                for (int i = 0; i < 64 * 64; i++) pixels[i] = px[i];
                RenderTexture.active = prev;
                UnityEngine.Object.DestroyImmediate(tex);

                float bg = pixels[2 * 64 + 2].r; // corner = background
                var geometry = new System.Collections.Generic.List<float>();
                for (int i = 0; i < 64 * 64; i++)
                    if (Math.Abs(pixels[i].r - bg) > 0.05f)
                        geometry.Add(pixels[i].r);
                Check(geometry.Count > 400,
                    "mesh program rendered too little geometry: " + geometry.Count + " px");

                // Discriminator: the geometry-center normal is (0,0,+1) on the NEAR
                // hemisphere — color = ambient 0.08 + diffuse 0.41*0.7*0.8 + spec
                // ≈ 0.318 linear → 0.598 after the FS gamma. On the FAR hemisphere
                // (the winding regression) the center normal is (0,0,-1): diffuse
                // and spec clamp to zero, rim = 0.15 → 0.23 linear → 0.514 (the
                // measured flat 131/255). Assert the near-hemisphere value.
                float center = 0f;
                for (int y = 28; y < 36; y++)
                    for (int x = 28; x < 36; x++)
                        center += pixels[y * 64 + x].r;
                center /= 64f;
                Check(center >= 0.56f,
                    $"mesh output center is {center:F3} — the far hemisphere is being " +
                    "shaded (winding regression; near-hemisphere center measures ≈0.598, " +
                    "far-hemisphere flat field measures ≈0.514)");
            }
            finally
            {
                pipeline.Dispose();
            }
        }

        // Unit UV sphere as OBJ text (v and vn share indices; quads fan into two
        // triangles). Smooth shading needs a curved mesh: the flat-face tetrahedron
        // would defeat the dominant-value metric this test relies on.
        private static string SphereObj(int segU, int segV)
        {
            var sb = new System.Text.StringBuilder();
            for (int iv = 0; iv <= segV; iv++)
            {
                double phi = Math.PI * iv / segV;
                for (int iu = 0; iu < segU; iu++)
                {
                    double theta = 2.0 * Math.PI * iu / segU;
                    double x = Math.Sin(phi) * Math.Cos(theta);
                    double y = Math.Cos(phi);
                    double z = Math.Sin(phi) * Math.Sin(theta);
                    sb.AppendLine($"v {x:F6} {y:F6} {z:F6}");
                    sb.AppendLine($"vn {x:F6} {y:F6} {z:F6}");
                }
            }
            for (int iv = 0; iv < segV; iv++)
            {
                for (int iu = 0; iu < segU; iu++)
                {
                    int iu2 = (iu + 1) % segU;
                    int a = iv * segU + iu + 1;
                    int b = iv * segU + iu2 + 1;
                    int c = (iv + 1) * segU + iu2 + 1;
                    int d = (iv + 1) * segU + iu + 1;
                    // Authored CW-outward to match share/meshes/sphere.obj (the
                    // loader reverses every face to CCW; the test asserts the
                    // NEAR hemisphere renders, so the convention must match the
                    // reference-authored meshes).
                    sb.AppendLine($"f {a}//{a} {c}//{c} {b}//{b}");
                    sb.AppendLine($"f {a}//{a} {d}//{d} {c}//{c}");
                }
            }
            return sb.ToString();
        }

        // Read the w component of texel (0,0) of a float mesh-data RT.
        private static float ReadMeshTexelW(RenderTexture rt)
        {
            RenderTexture prev = RenderTexture.active;
            RenderTexture.active = rt;
            var tex = new Texture2D(1, 1, TextureFormat.RGBAFloat, false);
            tex.ReadPixels(new Rect(0, 0, 1, 1), 0, 0);
            tex.Apply();
            float w = tex.GetPixel(0, 0).a;
            RenderTexture.active = prev;
            UnityEngine.Object.DestroyImmediate(tex);
            return w;
        }

        // NMParityRunner.LoadRegistryFromPackage is private; reach it by reflection
        // so the registry path logic lives in exactly one place.
        private static Noisemaker.Hlsl.Compiler.EffectRegistry LoadEffectRegistry()
        {
            var method = typeof(NMParityRunner).GetMethod("LoadRegistryFromPackage",
                BindingFlags.NonPublic | BindingFlags.Static);
            Check(method != null, "NMParityRunner.LoadRegistryFromPackage is not reachable");
            return (Noisemaker.Hlsl.Compiler.EffectRegistry)method.Invoke(null, null);
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

                Check(!pipeline.ShouldDeferRender(), "pipeline should not defer render without deferring sink");
                sink.Defer = true;
                Check(pipeline.ShouldDeferRender(), "pipeline did not forward shouldDeferRender");
                sink.Defer = false;
                Check(!pipeline.ShouldDeferRender(), "pipeline deferred render after sink deferral reset");
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
