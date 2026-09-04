// NMPipeline.cs — the per-frame executor. Ports reference/04 §10 (render(time))
// control flow EXACTLY: normalized 0..1 time, deltaTime wrap = 1/60/10,
// updateGlobalUniforms, per-frame frameRead/Write seeding, per-pass
// shouldSkipPass + resolveRepeatCount + iterate + within-frame ping-pong,
// present renderSurface, end-of-frame swapBuffers.
//
// "Compile programs" is a no-op in Unity (shaders are precompiled assets); init
// instead validates that the registry resolves a Shader for every pass.
//
// Texture resolution (ITextureResolver): graph texIds map to RenderTextures as:
//   * "global_<name>_read"/"_write" handled implicitly: a pass input "global_<name>"
//     resolves to the surface's CURRENT FRAME-READ texture; a pass output
//     "global_<name>" resolves to the surface's CURRENT FRAME-WRITE texture.
//   * "none"/null -> handled by the backend (black).
//   * other texIds -> the pooled phys_N RT via graph.allocations (else the texId RT).

using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Noisemaker.Hlsl.Compiler;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl
{
    public sealed class NMPipeline : ITextureResolver
    {
        // Normalized wrap delta: one 60fps frame mapped onto a 10s loop (reference §10.2).
        private const float WrapDelta = 1f / 60f / 10f;

        public RenderGraph Graph { get; private set; }

        private readonly TextureStore _store;
        private readonly SurfaceManager _surfaces;
        private readonly NMShaderRegistry _registry;
        private readonly UniformBinder _binder;
        private readonly NMRenderBackend _backend;
        private readonly NMMeshData _meshData; // uploadMeshData path (mesh surfaces)
        private readonly NMSinkManager _sinkManager;
        private readonly EffectRegistry _effectRegistry;

        private int _width, _height;
        public int Width { get { return _width; } }
        public int Height { get { return _height; } }

        public int FrameIndex { get; private set; }
        private float _lastTime;

        // Tile / scale state (tiled hi-res export). Defaults: no tiling.
        private Vector2? _tileOffset;
        private Vector2? _fullResolution;
        private float _renderScale = 1f;

        // Live global uniform values (mutable host-set + engine). Used for repeat
        // count resolution, conditions, and dimension param lookups.
        private readonly Dictionary<string, double> _globalUniforms =
            new Dictionary<string, double>();

        // Reused command buffer.
        private readonly CommandBuffer _cmd;

        // Cached uniform-lookup delegate (avoids a per-frame method-group allocation).
        private readonly System.Func<string, double?> _uniformLookup;
        private readonly HashSet<string> _warnedVolumeClamps = new HashSet<string>();
        private int _maxTextureSize;
        private bool _disposed;

        public NMPipeline(RenderGraph graph, EffectRegistry effectRegistry = null)
        {
            Graph = graph;
            _effectRegistry = effectRegistry;
            _store = new TextureStore();
            _surfaces = new SurfaceManager(_store);
            _registry = new NMShaderRegistry();
            _binder = new UniformBinder();
            _backend = new NMRenderBackend(_registry, this, _binder);
            _meshData = new NMMeshData(_store, _surfaces);
            _sinkManager = new NMSinkManager();
            _cmd = new CommandBuffer { name = "Noisemaker" };
            _uniformLookup = UniformLookup;
        }

        public System.Action AddSink(INMOutputSink sink)
        {
            return _sinkManager.Add(sink);
        }

        public void SetMidiState(MidiState state)
        {
            _binder.MidiState = state;
        }

        public void SetAudioState(AudioState state)
        {
            _binder.AudioState = state;
        }

        public AudioInputRequirements GetAudioInputRequirements()
        {
            return Automation.GetAudioInputRequirements(Graph.Passes,
                EffectNeedsLegacyAudio);
        }

        private bool EffectNeedsLegacyAudio(Pass pass)
        {
            if (_effectRegistry == null || pass == null) return false;
            if (_effectRegistry.EffectHasTag(pass.EffectKey, "audio")) return true;
            string qualified = !string.IsNullOrEmpty(pass.Namespace) &&
                !string.IsNullOrEmpty(pass.Func)
                ? pass.Namespace + "." + pass.Func : null;
            return _effectRegistry.EffectHasTag(qualified, "audio") ||
                _effectRegistry.EffectHasTag(pass.Func, "audio");
        }

        public NMFrameExportQueue CreateFrameExportQueue(int slots = 3,
            System.Action<System.Exception> onError = null, Shader resolveShader = null)
        {
            return new NMFrameExportQueue(new NMUnityFrameExportAdapter(resolveShader),
                slots, onError);
        }

        // ---- init / resize -------------------------------------------------
        public void Init(int width, int height)
        {
            ApplyDeviceLimits(SystemInfo.maxTextureSize, DetectMrtFormatBudget());
            ValidatePrograms();
            SeedScopedUniforms();
            Resize(width, height);
        }

        private static int DetectMrtFormatBudget()
        {
            // Apple2/Apple3 mobile GPUs permit only 32 bytes per sample across
            // color attachments. Unity does not expose the Metal GPU family, so
            // use the supported-family floor on iOS/tvOS and leave other APIs
            // untouched rather than reducing precision without a device limit.
            if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Metal &&
                (Application.platform == RuntimePlatform.IPhonePlayer ||
                 Application.platform == RuntimePlatform.tvOS))
                return 32;
            return 0;
        }

        private void ApplyDeviceLimits(int maxTextureSize, int maxColorBytesPerSample)
        {
            _maxTextureSize = maxTextureSize;
            ClampGraphVolumeSizes();
            ApplyMrtFormatBudget(maxColorBytesPerSample);
        }

        private static bool IsVolumeSizeUniform(string name)
        {
            return name == "volumeSize" ||
                name.StartsWith("volumeSize_chain_", System.StringComparison.Ordinal) ||
                name.StartsWith("volumeSize_node_", System.StringComparison.Ordinal);
        }

        private double ClampVolumeSize(double value)
        {
            if (_maxTextureSize <= 0 || value * value <= _maxTextureSize)
                return value;

            int clamped = 16;
            while ((clamped * 2) * (clamped * 2) <= _maxTextureSize &&
                clamped * 2 < value)
                clamped *= 2;

            string warningKey = value + "->" + clamped;
            if (_warnedVolumeClamps.Add(warningKey))
            {
                Debug.LogWarning("[Noisemaker] Capping volumeSize from " + value +
                    " to " + clamped + ": the " + value + "x" + (value * value) +
                    " volume atlas exceeds this device's max texture size (" +
                    _maxTextureSize + ").");
            }
            return clamped;
        }

        private void ClampGraphVolumeSizes()
        {
            foreach (Pass pass in Graph.Passes)
            {
                int count = pass.Uniforms.Count;
                for (int i = 0; i < count; i++)
                {
                    var kv = pass.Uniforms.EntryAt(i);
                    if (!IsVolumeSizeUniform(kv.Key) ||
                        kv.Value.Kind != UniformValueKind.Number)
                        continue;
                    double clamped = ClampVolumeSize(kv.Value.Number);
                    if (clamped != kv.Value.Number)
                        pass.Uniforms[kv.Key] = UniformValue.Of(clamped);
                }
            }
        }

        private static int MrtFormatBytes(string format)
        {
            if (format == "rgba32f" || format == "rgba32float") return 16;
            if (format == "rgba8" || format == "rgba8unorm") return 4;
            return 8;
        }

        private void ApplyMrtFormatBudget(int budget)
        {
            if (budget <= 0) return;
            foreach (Pass pass in Graph.Passes)
            {
                int count = pass.Outputs.Count;
                if (count <= 1) continue;

                var specs = new TextureSpec[count];
                var texIds = new string[count];
                int total = 0;
                for (int i = 0; i < count; i++)
                {
                    string texId = pass.Outputs.EntryAt(i).Value;
                    TextureSpec spec;
                    Graph.Textures.TryGetValue(texId, out spec);
                    texIds[i] = texId;
                    specs[i] = spec;
                    total += MrtFormatBytes(spec != null ? spec.Format : null);
                }
                if (total <= budget) continue;

                for (int i = count - 1; i >= 0 && total > budget; i--)
                {
                    TextureSpec spec = specs[i];
                    if (spec == null ||
                        (spec.Format != "rgba32f" && spec.Format != "rgba32float"))
                        continue;
                    Debug.LogWarning("[Noisemaker] Demoting MRT attachment " + texIds[i] +
                        " from " + spec.Format + " to rgba16f: pass " + pass.Id +
                        " needs " + total + " bytes/sample, device allows " + budget + ".");
                    spec.Format = "rgba16f";
                    total -= 8;
                }
            }
        }

        // Reference §13 setUniform fans scoped (_node_/_chain_) uniform variants into
        // the global uniform set. The Unity port binds per-pass uniforms for shaders but
        // does NOT fan out scoped variants to _globalUniforms, so chain-scoped SIZING
        // params (e.g. stateSize_node_2 sizing pointsEmit's xyz/vel/rgba state textures)
        // are unresolvable at surface-creation time and ResolveDimension falls back to a
        // wrong default (the agent state collapsed to 64x64 instead of stateSize=128).
        // Seed them from the graph's pass uniforms; scoped names are unique per node so
        // there is no cross-pass conflict.
        private void SeedScopedUniforms()
        {
            foreach (Pass pass in Graph.Passes)
            {
                int n = pass.Uniforms.Count;
                for (int i = 0; i < n; i++)
                {
                    var kv = pass.Uniforms.EntryAt(i);
                    string name = kv.Key;
                    if (name.IndexOf("_node_", System.StringComparison.Ordinal) < 0 &&
                        name.IndexOf("_chain_", System.StringComparison.Ordinal) < 0)
                        continue;
                    if (_globalUniforms.ContainsKey(name)) continue;
                    UniformValue v = kv.Value;
                    if (v.Kind == UniformValueKind.Number)
                        _globalUniforms[name] = v.Number;
                }
            }
        }

        // "compilePrograms" analog: Unity shaders are precompiled; just verify the
        // registry resolves a Shader for each unique pass (reference §7 dedupe).
        private void ValidatePrograms()
        {
            var seen = new HashSet<string>();
            foreach (Pass pass in Graph.Passes)
            {
                string name = NMShaderRegistry.ShaderNameForPass(pass);
                if (!seen.Add(name)) continue;
                Shader sh = _registry.ResolveShader(pass);
                if (sh == null)
                    Debug.LogError("[Noisemaker] Shader not found: " + name +
                        " (pass " + pass.Id + "). Ensure it is in a Resources/Always-" +
                        "Included list so Shader.Find resolves it at runtime.");
            }
        }

        public void Resize(int width, int height)
        {
            _width = Mathf.Max(1, width);
            _height = Mathf.Max(1, height);
            _sinkManager.Configure(new NMOutputDescriptor(_width, _height,
                NMOutputAlphaMode.Premultiplied));
            _store.SetScreenSize(_width, _height);
            _surfaces.CreateSurfaces(Graph, _width, _height, UniformLookup);
            _store.AllocatePooled(Graph, UniformLookup);
            // TODO(scope): initAsyncEffects (CPU texture generation) not ported.
        }

        // ---- host API: uniforms -------------------------------------------
        public void SetUniform(string name, double value)
        {
            // reference setUniform: cap stateSize to maxStateSize (2048).
            if (name == "stateSize" || name.StartsWith("stateSize_node_",
                System.StringComparison.Ordinal))
            {
                if (value > 2048.0)
                {
                    Debug.LogWarning("[Noisemaker] " + name + " capped to maxStateSize 2048.");
                    value = 2048.0;
                }
            }
            if (IsVolumeSizeUniform(name))
                value = ClampVolumeSize(value);
            _globalUniforms[name] = value;

            bool affectsDimensions = DimensionReferencesParam(name);
            if (IsVolumeSizeUniform(name))
            {
                bool scoped = name.IndexOf("_node_", System.StringComparison.Ordinal) >= 0 ||
                    name.IndexOf("_chain_", System.StringComparison.Ordinal) >= 0;
                foreach (Pass pass in Graph.Passes)
                {
                    int count = pass.Uniforms.Count;
                    for (int i = 0; i < count; i++)
                    {
                        var kv = pass.Uniforms.EntryAt(i);
                        bool target = kv.Key == name || (!scoped &&
                            (kv.Key.StartsWith(name + "_node_", System.StringComparison.Ordinal) ||
                             kv.Key.StartsWith(name + "_chain_", System.StringComparison.Ordinal)));
                        if (!target || kv.Value.Kind == UniformValueKind.Object) continue;
                        pass.Uniforms[kv.Key] = UniformValue.Of(value);
                        _globalUniforms[kv.Key] = value;
                        affectsDimensions |= DimensionReferencesParam(kv.Key);
                    }
                }
            }

            // If any texture spec references this param, surfaces/pool must resize.
            if (affectsDimensions)
            {
                _surfaces.CreateSurfaces(Graph, _width, _height, UniformLookup);
                _store.AllocatePooled(Graph, UniformLookup);
            }
            // TODO(scope): per-pass uniform fan-out (_node_/_chain_) and palette
            // expansion (reference §13 setUniform) not ported; the named uniform is
            // bound at the pass level from graph.uniforms.
        }

        // ---- host API: mesh loading (reference loadOBJ + uploadMeshData) ----
        // Parse an OBJ string and upload it into the named mesh surface ("mesh0".."mesh7").
        // The surface triplet must already be allocated (a pass references
        // global_<meshName>_positions, so SurfaceManager.CreateSurfaces created it).
        // Returns the uploaded vertex count (0 if the surface is missing). Call after
        // Init/Resize and before Render. Host resolves the OBJ text from the effect's
        // externalMesh / builtinMeshes path (e.g. share/meshes/sphere.obj) — that mapping
        // lives in the effect definition, not the normalized graph, so it is host-driven.
        public int LoadMeshObj(string meshName, string objText)
        {
            return _meshData.UploadObj(meshName, objText);
        }

        // Uploaded vertex count for a mesh surface (drives count:"input" sizing; the draw
        // count is meshPositions.width*height = 65536, with unused texels carrying w=0).
        public int GetMeshVertexCount(string meshName)
        {
            return _meshData.GetVertexCount(meshName);
        }

        private double? UniformLookup(string name)
        {
            double v;
            return _globalUniforms.TryGetValue(name, out v) ? (double?)v : null;
        }

        private bool DimensionReferencesParam(string name)
        {
            foreach (var kv in Graph.Textures)
            {
                TextureSpec s = kv.Value;
                if (s == null) continue;
                if (DimRefs(s.Width, name) || DimRefs(s.Height, name) ||
                    DimRefs(s.Depth, name)) return true;
            }
            return false;
        }

        private static bool DimRefs(Dim d, string name)
        {
            if (d == null) return false;
            if (d.Kind == DimKind.Param) return d.Param == name;
            if (d.Kind == DimKind.ScreenDivide) return d.ScreenDivide == name;
            return false;
        }

        // ---- per-frame render (reference/04 §10) --------------------------
        public void Render(float time, double? presentationTimestampMilliseconds = null)
        {
            double wallTimeMilliseconds =
                (double)System.Diagnostics.Stopwatch.GetTimestamp() * 1000.0 /
                System.Diagnostics.Stopwatch.Frequency;
            double frameTimestampMilliseconds = presentationTimestampMilliseconds ??
                wallTimeMilliseconds;
            _binder.WallTimeMilliseconds = wallTimeMilliseconds;

            // 2. deltaTime + wrap.
            float deltaTime = _lastTime > 0f ? time - _lastTime : 0f;
            if (deltaTime < 0f) deltaTime = WrapDelta; // time wrapped
            _lastTime = time;

            // 3. updateGlobalUniforms.
            float frX = _fullResolution.HasValue ? _fullResolution.Value.x : _width;
            float frY = _fullResolution.HasValue ? _fullResolution.Value.y : _height;
            float tX = _tileOffset.HasValue ? _tileOffset.Value.x : 0f;
            float tY = _tileOffset.HasValue ? _tileOffset.Value.y : 0f;
            _binder.SetEngineGlobals(_width, _height, frX, frY, tX, tY,
                time, deltaTime, _renderScale, FrameIndex);
            // Tell the backend the screen resolution so it can RESTORE _NM_Resolution
            // after a volume-write pass overrides it to the atlas dims (NMRenderBackend
            // viewport handling).
            _backend.ScreenWidth = _width;
            _backend.ScreenHeight = _height;
            // Per-frame normalized time for automation (oscillator) uniform evaluation
            // (reference/04 §10.4 / §11). Same value passed to Render(time).
            _backend.NormalizedTime = time;

            // 4. seed frameRead/frameWrite from surfaces.
            _surfaces.BeginFrame();

            // 6. execute passes in order.
            _cmd.Clear();
            for (int i = 0; i < Graph.Passes.Count; i++)
            {
                Pass pass = Graph.Passes[i];

                // DSL LOOPS: a contiguous run of passes sharing a non-zero LoopGroupId is
                // an iterated subchain bracket. Run the whole run N times, ping-ponging
                // its global outputs between iterations (reference/04 §10.6). The grouping
                // is contiguous by construction (the Expander tags passes only while inside
                // the bracket), so scan forward for the run end and iterate the block.
                if (pass.LoopGroupId != 0)
                {
                    i = ExecuteLoopBracket(i, time);
                    continue;
                }

                if (ShouldSkipPass(pass)) continue;

                int repeatCount = ResolveRepeatCount(pass, time);
                for (int iter = 0; iter < repeatCount; iter++)
                {
                    _backend.ExecutePass(_cmd, pass, _uniformLookup);
                    _surfaces.UpdateFrameSurfaceBindings(pass); // §10.2
                    if (repeatCount > 1)
                        _surfaces.AdoptIterationBindings(pass); // §10.6
                }
            }

            // 8. present renderSurface -> nothing here; the output RT is the frame-read
            // texture of renderSurface. The Driver reads Output after Render.

            // execute the queued GPU work.
            Graphics.ExecuteCommandBuffer(_cmd);

            RenderTexture output = GetOutput();
            if (output != null)
            {
                _sinkManager.Submit(output, frameTimestampMilliseconds);
            }

            // 9. end-of-frame swap.
            _surfaces.SwapBuffers(FrameIndex);

            // 10.
            FrameIndex++;
        }

        // DSL LOOPS: execute one iterated subchain bracket starting at pass index
        // `start`. Returns the LAST pass index of the bracket (the caller's for-loop
        // then increments past it). The bracket is the maximal contiguous run of passes
        // with the same non-zero LoopGroupId; the whole run executes LoopIterations
        // times, adopting its frame-local global bindings between iterations
        // (reference/04 §10.6). Per-pass `repeat` still applies inside each iteration.
        // TODO(verify): no JS reference exists for subchain N-fold expansion (the JS
        // reference loops via loopBegin/loopEnd accumulator effects, not a bracket), so
        // the exact buffer holding the presented result after N iterations must be
        // validated against captured frames once a Unity runtime is available.
        private int ExecuteLoopBracket(int start, float normalizedTime)
        {
            int groupId = Graph.Passes[start].LoopGroupId;
            int end = start;
            while (end + 1 < Graph.Passes.Count && Graph.Passes[end + 1].LoopGroupId == groupId)
                end++;
            int loopIters = Mathf.Max(1, Graph.Passes[start].LoopIterations);

            for (int iter = 0; iter < loopIters; iter++)
            {
                for (int p = start; p <= end; p++)
                {
                    Pass lp = Graph.Passes[p];
                    if (ShouldSkipPass(lp)) continue;
                    int rc = ResolveRepeatCount(lp, normalizedTime);
                    for (int r = 0; r < rc; r++)
                    {
                        _backend.ExecutePass(_cmd, lp, _uniformLookup);
                        _surfaces.UpdateFrameSurfaceBindings(lp); // §10.2
                        if (rc > 1)
                            _surfaces.AdoptIterationBindings(lp); // §10.6 (inner repeat)
                    }
                }
                // At each boundary, mirror frame-local bindings for every bracket output
                // into its persistent record. The frame maps already make the next
                // iteration read this iteration's output. Preserve the existing final-
                // iteration skip so post-loop/end-of-frame handling remains unchanged.
                if (iter < loopIters - 1)
                    for (int p = start; p <= end; p++)
                        _surfaces.AdoptIterationBindings(Graph.Passes[p]); // §10.6
            }
            return end;
        }

        // shouldSkipPass — reference §10.3 Pipeline.shouldSkipPass. A pass with no
        // conditions never skips. skipIf: skip if ANY predicate matches. runIf: skip
        // unless ALL predicates match. Each predicate resolves its uniform from the
        // live globals first, then the pass uniforms (same chain as resolveRepeatCount),
        // and compares numerically against `equals` (the JS `=== condition.equals`).
        //
        // NOTE (reference dead-code parity): the port never attaches Pass.Conditions
        // (the reference expander omits conditions from compiled passes — see Pass.cs),
        // so c is always null here and this method always returns false. In particular
        // pointsBillboardRender's two deposit passes (additive + premultiplied-alpha)
        // BOTH run every frame, exactly as in the reference; the blendMode switch is
        // effected by the blend-pass shader branch, not by skipping a deposit. The method
        // is kept as the faithful mirror of Pipeline.shouldSkipPass (and to honor an
        // explicit host-set condition if one is ever introduced).
        private bool ShouldSkipPass(Pass pass)
        {
            PassConditions c = pass.Conditions;
            if (c == null) return false;

            // skipIf: skip if ANY condition matches.
            if (c.SkipIf != null)
            {
                for (int i = 0; i < c.SkipIf.Count; i++)
                {
                    PassCondition cond = c.SkipIf[i];
                    double? v = ResolveConditionValue(pass, cond.Uniform);
                    if (v.HasValue && v.Value == cond.EqualsValue) return true;
                }
            }

            // runIf: skip if ANY condition does NOT match (run only when all match).
            if (c.RunIf != null)
            {
                for (int i = 0; i < c.RunIf.Count; i++)
                {
                    PassCondition cond = c.RunIf[i];
                    double? v = ResolveConditionValue(pass, cond.Uniform);
                    if (!v.HasValue || v.Value != cond.EqualsValue) return true;
                }
            }

            return false;
        }

        // Resolve a condition's uniform value: live globals (_globalUniforms) take
        // precedence, then the pass's own numeric uniform literal. Returns null when
        // unresolved (treated as "not equal" by the runIf/skipIf logic, mirroring the
        // reference's `undefined !== equals`).
        private double? ResolveConditionValue(Pass pass, string uniform)
        {
            if (string.IsNullOrEmpty(uniform)) return null;
            double? gu = UniformLookup(uniform);
            if (gu.HasValue) return gu;
            UniformValue uv;
            if (pass.Uniforms.TryGetValue(uniform, out uv) &&
                uv.Kind == UniformValueKind.Number)
                return uv.Number;
            return null;
        }

        // resolveRepeatCount — reference §10.5.
        private int ResolveRepeatCount(Pass pass, float normalizedTime)
        {
            return Automation.ResolveRepeatCount(pass, normalizedTime, UniformLookup,
                _binder.MidiState, _binder.AudioState, _binder.WallTimeMilliseconds);
        }

        // ---- ITextureResolver ---------------------------------------------
        // A pass input "global_<name>" samples the surface's CURRENT frame-read RT.
        public RenderTexture ResolveRead(string texId)
        {
            string surfName = SurfaceManager.ParseGlobalName(texId);
            if (surfName != null)
            {
                // mesh-data names resolve to the static triplet (read side).
                RenderTexture mesh = ResolveMeshTexture(surfName);
                if (mesh != null) return mesh;
                RenderTexture rt = _surfaces.GetFrameReadTexture(surfName);
                if (rt != null) return rt;
            }
            return ResolvePhysical(texId);
        }

        // A pass output "global_<name>" renders into the surface's CURRENT frame-write RT.
        public RenderTexture ResolveWrite(string texId)
        {
            string surfName = SurfaceManager.ParseGlobalName(texId);
            if (surfName != null)
            {
                RenderTexture mesh = ResolveMeshTexture(surfName);
                if (mesh != null) return mesh;
                string writeId = _surfaces.GetFrameWriteId(surfName);
                if (writeId != null)
                {
                    RenderTexture rt = _store.Get(writeId);
                    if (rt != null) return rt;
                }
            }
            return ResolvePhysical(texId);
        }

        // mesh-data triplet ids: "<meshN>_positions|normals|uvs".
        private RenderTexture ResolveMeshTexture(string surfName)
        {
            // mesh-data global names are like "meshN_positions"; surfName here is the
            // global suffix. Match meshN_ prefix directly.
            int underscore = surfName.IndexOf('_');
            if (underscore <= 0) return null;
            string meshName = surfName.Substring(0, underscore);
            string attr = surfName.Substring(underscore + 1);
            if (!meshName.StartsWith("mesh", System.StringComparison.Ordinal)) return null;
            SurfaceRecord rec = _surfaces.GetSurface(meshName);
            if (rec == null || !rec.IsMesh) return null;
            switch (attr)
            {
                case "positions": return _store.Get(rec.Positions);
                case "normals": return _store.Get(rec.Normals);
                case "uvs": return _store.Get(rec.Uvs);
                default: return null;
            }
        }

        // Pooled / non-global texId: map through graph.allocations to phys_N, else
        // use the texId directly (some specs are stored under their own id).
        //
        // POOLING ALIAS GUARD (reference parity): the JS liveness allocator
        // (resources.js) freely reuses a phys_N slot for texIds of DIFFERENT logical
        // sizes, but the JS WebGL2 runtime NEVER actually collapses to phys_N — it
        // allocates one real texture per VIRTUAL id at its own logical size
        // (pipeline.js recreateTextures keys by virtual texId). Our TextureStore pools
        // by phys_N at the MAX size across aliased virtuals. That is safe ONLY when the
        // aliased virtuals share dimensions; it BREAKS volume atlases (e.g.
        // node_0_volumeCache 64x4096 aliased with node_3_out screen 256x256 grows phys
        // to 256x4096): NM_FragCoord then spans the wrong width and fullscreen samplers
        // read by normalized UV across the oversized RT, scrambling the atlas. When this
        // texId's LOGICAL size, mapped format, or logical is3D identity differs from
        // the pooled physical, fall back to the reference behavior: a DEDICATED RT
        // keyed by the virtual texId at its logical specification.
        private RenderTexture ResolvePhysical(string texId)
        {
            if (string.IsNullOrEmpty(texId) || texId == "none") return null;
            string phys;
            if (Graph.Allocations.TryGetValue(texId, out phys) && phys != null)
            {
                RenderTexture rt = _store.Get(phys);
                if (rt != null)
                {
                    // If this virtual's logical specification differs from the pooled
                    // physical RT, the alias is unsafe — use a dedicated RT instead.
                    TextureSpec s;
                    if (Graph.Textures.TryGetValue(texId, out s) && s != null)
                    {
                        int lw = TextureStore.ResolveDimension(s.Width, _width, UniformLookup);
                        int lh = TextureStore.ResolveDimension(s.Height, _height, UniformLookup);
                        if (lw != rt.width || lh != rt.height ||
                            rt.format != TextureStore.MapFormat(s.Format) ||
                            !_store.MatchesLogical3D(rt, s.Is3D))
                            return CreateLazyPhysical(texId, texId);
                    }
                    return rt;
                }
                // lazily create from the texId's spec.
                return CreateLazyPhysical(phys, texId);
            }
            RenderTexture direct = _store.Get(texId);
            if (direct != null) return direct;
            return CreateLazyPhysical(texId, texId);
        }

        private RenderTexture CreateLazyPhysical(string physId, string specTexId)
        {
            TextureSpec spec;
            if (!Graph.Textures.TryGetValue(specTexId, out spec) || spec == null)
                return null;
            int w = TextureStore.ResolveDimension(spec.Width, _width, UniformLookup);
            int h = TextureStore.ResolveDimension(spec.Height, _height, UniformLookup);
            int d = 1;
            if (spec.Is3D && spec.Depth != null)
                d = TextureStore.ResolveDimension(spec.Depth, _height, UniformLookup);
            return _store.CreateOrReuse(physId, w, h, spec.Format, spec.Is3D, d);
        }

        // ---- presentation / output ----------------------------------------
        // Output RT = the frame-read texture of renderSurface (freshest written
        // content), matching reference §10 step 8 presentId.
        public RenderTexture GetOutput()
        {
            if (string.IsNullOrEmpty(Graph.RenderSurface)) return null;
            return _surfaces.GetFrameReadTexture(Graph.RenderSurface);
        }

        public RenderTexture GetOutput(string surfaceName)
        {
            string name = string.IsNullOrEmpty(surfaceName) ? Graph.RenderSurface : surfaceName;
            if (string.IsNullOrEmpty(name)) return null;
            return _surfaces.GetFrameReadTexture(name);
        }

        // Blit the current renderSurface output into an external destination RT.
        // Used by NMParityRunner and host present paths. This is a STRAIGHT copy —
        // the single Y-flip reconciliation lives in NMBlit / NM_FLIP_Y (see
        // ARCHITECTURE.md), not here. Call after Render() for the freshest content.
        public void PresentTo(RenderTexture dst)
        {
            if (dst == null) return;
            RenderTexture src = GetOutput();
            if (src == null) return;
            Graphics.Blit(src, dst);
        }

        // ---- seamless cubemap rendering (reference pipeline.renderCubemap) ------
        // Render the full graph 6 times — once per cube face — and assemble a Unity
        // TextureCube (a RenderTexture with dimension=Cube). Mirrors the reference
        // pipeline.renderCubemap (cubeCamera.js CUBE_FACE_BASES): per face, set the
        // cubeBasis mat3 on every pass that declares it, render at faceSize, then copy
        // the chosen surface's output into that cube face. GL face order +X,-X,+Y,-Y,
        // +Z,-Z == UnityEngine.CubemapFace indices. The caller owns the returned RT.
        //
        // Each face re-renders the WHOLE graph (volume generation included) with only
        // cubeBasis changed — exactly as the reference does. Only the cube effects
        // (renderCubemap3d/Surface) declare a cubeBasis uniform; for any other graph
        // this simply renders identical content into all 6 faces.
        public RenderTexture RenderCubemap(int faceSize, string surfaceName, float time,
            bool flipU = true, bool flipV = true)
        {
            int prevW = _width, prevH = _height;
            if (_width != faceSize || _height != faceSize) Resize(faceSize, faceSize);

            string surf = string.IsNullOrEmpty(surfaceName) ? Graph.RenderSurface : surfaceName;

            var cube = new RenderTexture(faceSize, faceSize, 0,
                RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear)
            {
                name = "NMCubemap",
                dimension = UnityEngine.Rendering.TextureDimension.Cube,
                useMipMap = false,
                autoGenerateMips = false,
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp
            };
            cube.Create();

            // Reference faces are rendered with cubeCamera's (right,up,forward) basis and
            // stored top-down; Unity samples cube faces with the D3D (sc,tc) convention,
            // whose in-face axes run opposite the reference's on every face (derived from
            // the per-face sc/tc table vs cubeCamera). Reconcile with a uniform per-face
            // flip (flipU/flipV) applied via a Blit before the face copy, so the assembled
            // TextureCube samples seamlessly under Unity's hardware cube sampler.
            RenderTexture flipTmp = (flipU || flipV)
                ? RenderTexture.GetTemporary(faceSize, faceSize, 0,
                    RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear)
                : null;
            Vector2 scale = new Vector2(flipU ? -1f : 1f, flipV ? -1f : 1f);
            Vector2 offset = new Vector2(flipU ? 1f : 0f, flipV ? 1f : 0f);

            for (int face = 0; face < NMCubeCamera.FaceCount; face++)
            {
                SetCubeBasis(NMCubeCamera.FaceBases[face]);
                Render(time);
                RenderTexture faceRT = GetOutput(surf);
                if (faceRT == null) continue;
                if (flipTmp != null)
                {
                    Graphics.Blit(faceRT, flipTmp, scale, offset);
                    Graphics.CopyTexture(flipTmp, 0, 0, cube, face, 0);
                }
                else
                {
                    Graphics.CopyTexture(faceRT, 0, 0, cube, face, 0);
                }
            }

            if (flipTmp != null) RenderTexture.ReleaseTemporary(flipTmp);
            if (prevW != faceSize || prevH != faceSize) Resize(prevW, prevH);
            return cube;
        }

        // Override the cubeBasis mat3 (9 floats, column-major [right|up|forward]) on
        // every pass that declares it — mirrors the reference setUniform writing
        // pass.uniforms['cubeBasis'] each face. The 9-array binds via UniformBinder
        // (BindMatrix3 -> float4x4). No-op for graphs without a cubeBasis uniform.
        private void SetCubeBasis(double[] basis9)
        {
            for (int i = 0; i < Graph.Passes.Count; i++)
            {
                Pass p = Graph.Passes[i];
                if (p.Uniforms != null && p.Uniforms.ContainsKey("cubeBasis"))
                    p.Uniforms["cubeBasis"] = UniformValue.Of(basis9);
            }
        }

        // ---- tiled export (data path present; logic TODO) -----------------
        public void SetTileRegion(Vector2 offset, Vector2 fullResolution, float renderScale)
        {
            _tileOffset = offset;
            _fullResolution = fullResolution;
            _renderScale = renderScale;
            // TODO(scope): tiled hi-res export full control flow not ported.
        }

        public void ClearTileRegion()
        {
            _tileOffset = null;
            _fullResolution = null;
            _renderScale = 1f;
        }

        public void SyncTime(float t) { _lastTime = t; }

        // ---- teardown ------------------------------------------------------
        public void Dispose(bool backendLost = false)
        {
            if (_disposed) return;
            _disposed = true;
            System.Exception firstError = null;
            System.Action<System.Action> cleanup = action =>
            {
                try { action(); }
                catch (System.Exception error) { if (firstError == null) firstError = error; }
            };

            cleanup(() => _sinkManager.Close(backendLost
                ? new NMOutputCloseOptions(true) : null));
            cleanup(() => _meshData.Dispose());
            cleanup(() => _surfaces.DestroyAll());
            cleanup(() => _store.DestroyAll());
            cleanup(() => _backend.Dispose());
            cleanup(() => _registry.Dispose());
            cleanup(() => { if (_cmd != null) _cmd.Release(); });
            _globalUniforms.Clear();
            if (firstError != null) throw firstError;
        }
    }
}
