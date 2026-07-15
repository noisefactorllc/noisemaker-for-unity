// TextureStore.cs — owns the pooled physical RenderTextures (phys_N) and the raw
// RT factory used by SurfaceManager too. Mirrors reference/04 §1 (pooling), §8
// (formats) and §9 (resolveDimension + recreateTextures size logic).
//
// The runtime never re-runs the JS liveness allocator: the normalized graph JSON
// already carries graph.allocations (virtual texId -> "phys_N"). So this store:
//   * resolves a virtual/pooled texId to its physical slot id via allocations,
//   * creates one provisional RenderTexture per distinct phys_N at the maximum
//     mapped dimensions; ResolvePhysical gives incompatible format/is3D aliases
//     dedicated virtual-id textures,
//   * resolves dimensions with the EXACT reference rounding rules.
//
// Formats (GRAPH-JSON-SCHEMA.md "## Formats", reference/04 §8): rgba16f->ARGBHalf,
// rgba32f->ARGBFloat, rgba8->ARGB32. ALL created RenderTextureReadWrite.Linear,
// 4-channel, no sRGB. Surfaces that compute passes write also need enableRandomWrite
// = false (we use fragment MRT, not UAV) but DO need to be valid render targets;
// point/clamp filtering to match current reference render-surface sampling.

using System.Collections.Generic;
using UnityEngine;
using Noisemaker.Hlsl.Compiler.Graph;

namespace Noisemaker.Hlsl
{
    public sealed class TextureStore
    {
        // texId / surface-buffer-id -> RenderTexture handle.
        private readonly Dictionary<string, RenderTexture> _textures =
            new Dictionary<string, RenderTexture>();

        // Logical is3D identity cannot be inferred from RenderTexture.dimension:
        // volume specs intentionally remain 2D atlases. Track it beside each RT so
        // pooling can reject aliases that differ only in logical texture identity.
        private readonly Dictionary<RenderTexture, bool> _logicalIs3D =
            new Dictionary<RenderTexture, bool>();

        public int ScreenWidth { get; private set; }
        public int ScreenHeight { get; private set; }

        public void SetScreenSize(int w, int h)
        {
            ScreenWidth = Mathf.Max(1, w);
            ScreenHeight = Mathf.Max(1, h);
        }

        public RenderTexture Get(string id)
        {
            RenderTexture rt;
            return _textures.TryGetValue(id, out rt) ? rt : null;
        }

        public bool Has(string id) { return _textures.ContainsKey(id); }

        public IEnumerable<string> Keys { get { return _textures.Keys; } }

        public bool MatchesLogical3D(RenderTexture texture, bool is3D)
        {
            bool existingIs3D;
            return texture != null &&
                _logicalIs3D.TryGetValue(texture, out existingIs3D) &&
                existingIs3D == is3D;
        }

        // ---- format map (reference/04 §8) ---------------------------------
        public static RenderTextureFormat MapFormat(string format)
        {
            // Default rgba16f when absent (pipeline default, GRAPH-JSON-SCHEMA §Formats).
            if (string.IsNullOrEmpty(format)) return RenderTextureFormat.ARGBHalf;
            switch (format)
            {
                case "rgba16f":
                case "rgba16float":
                    return RenderTextureFormat.ARGBHalf;
                case "rgba32f":
                case "rgba32float":
                    return RenderTextureFormat.ARGBFloat;
                case "rgba8":
                case "rgba8unorm":
                    return RenderTextureFormat.ARGB32;
                default:
                    return RenderTextureFormat.ARGBHalf;
            }
        }

        // ---- resolveDimension (reference/04 §9, EXACT) --------------------
        // screenSize is W for width dims, H for height dims; uniforms supplies param/
        // screenDivide values. Returns an int >= 1.
        public static int ResolveDimension(Dim spec, int screenSize,
            System.Func<string, double?> uniformLookup)
        {
            if (spec == null) return Mathf.Max(1, screenSize);

            switch (spec.Kind)
            {
                case DimKind.Number:
                    // number -> max(1, floor(spec))
                    return Mathf.Max(1, (int)System.Math.Floor(spec.Number));

                case DimKind.Screen:
                    // 'screen' / 'auto' -> screenSize
                    return Mathf.Max(1, screenSize);

                case DimKind.Percent:
                    // "p%" -> max(1, floor(screenSize * p / 100))
                    return Mathf.Max(1, (int)System.Math.Floor(
                        screenSize * spec.Percent / 100.0));

                case DimKind.Param:
                {
                    // hasTransform = power!=undefined || multiply!=undefined
                    bool hasTransform = spec.Power.HasValue || spec.Multiply.HasValue;
                    // paramDefault = spec.paramDefault ?? 64
                    double paramDefault = spec.ParamDefault.HasValue ? spec.ParamDefault.Value : 64.0;
                    double? u = uniformLookup != null ? uniformLookup(spec.Param) : null;
                    double value = u.HasValue ? u.Value : paramDefault;
                    if (spec.Multiply.HasValue) value *= spec.Multiply.Value;
                    if (spec.Power.HasValue) value = System.Math.Pow(value, spec.Power.Value);
                    // hasTransform && uniforms[param]===undefined && spec.default!==undefined
                    if (hasTransform && !u.HasValue && spec.DefaultValue.HasValue)
                        value = spec.DefaultValue.Value;
                    return Mathf.Max(1, (int)System.Math.Floor(value));
                }

                case DimKind.ScreenDivide:
                {
                    // divisor = uniforms[screenDivide] ?? spec.default ?? 1
                    double? u = uniformLookup != null ? uniformLookup(spec.ScreenDivide) : null;
                    double divisor = u.HasValue ? u.Value
                        : (spec.DefaultValue.HasValue ? spec.DefaultValue.Value : 1.0);
                    if (divisor == 0.0) divisor = 1.0; // guard div-by-zero (JS would yield Infinity)
                    // ROUND, not floor.
                    return Mathf.Max(1, (int)System.Math.Round(
                        screenSize / divisor, System.MidpointRounding.AwayFromZero));
                    // TODO(verify): JS Math.round rounds .5 toward +Inf; .NET AwayFromZero
                    // matches for positive operands (all sizes positive).
                }

                case DimKind.Scale:
                {
                    // computed = floor(screenSize*scale); clamp; max(1,..)
                    double computed = System.Math.Floor(screenSize * spec.Scale);
                    if (spec.ClampMin.HasValue) computed = System.Math.Max(computed, spec.ClampMin.Value);
                    if (spec.ClampMax.HasValue) computed = System.Math.Min(computed, spec.ClampMax.Value);
                    return Mathf.Max(1, (int)computed);
                }

                default:
                    return Mathf.Max(1, screenSize);
            }
        }

        // True if the dim forces recreation on resize (reference/04 isDynamicDimension:
        // a fixed Number is static; everything else depends on screen/uniforms).
        public static bool IsDynamic(Dim spec)
        {
            if (spec == null) return true;
            return spec.Kind != DimKind.Number;
        }

        // VOLUME ATLAS CONVENTION (reference/04 §8, render3d/renderLit3d/synth3d JSON).
        // The reference has NO true 3D sampler in the volume path: every "3D" volume is
        // a 2D ATLAS RenderTexture of `volumeSize` x `volumeSize^2` (default 64 x 4096 =
        // 64 stacked slices of 64x64), rgba16f LINEAR. Both the synth3d/filter3d WRITERS
        // and the render3d/renderLit3d RAYMARCH consumers address it as a 2D texture by
        // INTEGER texel fetch:
        //     atlasTexel(voxel.xyz, volSize) = int2( voxel.x, voxel.y + voxel.z*volSize )
        //     density = volumeCache.Load(int3(atlasTexel, 0));   // point fetch, no filter
        // Trilinear filtering, when needed, is done MANUALLY in the shader (8-corner
        // fetch + lerp) — never via a hardware 3D sampler. A real UnityEngine Tex3D
        // (volumeDepth>1) is therefore WRONG here: it cannot be `.Load`-ed as a flat
        // 64x4096 sheet and would mis-address every voxel. We map an `is3D` graph spec
        // to a 2D RT sized width x height (the atlas dims the spec already carries:
        // width = volumeSize, height = volumeSize^2). `depth` is informational only.
        // TODO(verify): if a future effect needs a hardware Tex3D, gate it on an
        // explicit spec flag; none of the 13+ ported 3D effects do (all atlas).

        // Create (or reuse if size, mapped format, and logical identity match) an RT
        // for a given id. Matching instances preserve sim/volume state; incompatible
        // instances are destroyed and recreated. `is3D` selects the logical 2D
        // VOLUME-ATLAS identity (see convention above); `depth` is informational.
        public RenderTexture CreateOrReuse(string id, int width, int height,
            string format, bool is3D, int depth)
        {
            var fmt = MapFormat(format);
            RenderTexture existing;
            if (_textures.TryGetValue(id, out existing) && existing != null)
            {
                bool sizeMatch = existing.width == width && existing.height == height;
                bool formatMatch = existing.format == fmt;
                // Atlas RTs are 2D; identity is fully determined by width/height
                // plus tracked logical is3D (height encodes the slice stack). Do NOT
                // compare volumeDepth — it is always 1 for the physical 2D atlas.
                if (sizeMatch && formatMatch && MatchesLogical3D(existing, is3D))
                    return existing;
                Destroy(id);
            }

            // ALWAYS a 2D RenderTexture, including the volume atlas (is3D). See the
            // VOLUME ATLAS CONVENTION above: the 64x4096 atlas is a 2D sheet, read by
            // integer texel fetch, NOT a hardware Tex3D.
            RenderTexture rt = new RenderTexture(
                width, height, 0, fmt, RenderTextureReadWrite.Linear);
            rt.name = "NM_" + id;
            rt.enableRandomWrite = false; // fragment MRT model, no UAV writes
            rt.useMipMap = false;
            rt.autoGenerateMips = false;
            // PARITY (webgl2.js createTexture, lines 221-224): the reference backend
            // creates EVERY surface/intermediate render texture with NEAREST filtering
            // and CLAMP_TO_EDGE wrap. Only externally-loaded video/image textures
            // (updateTextureFromSource) use LINEAR — those are a separate path (loaded
            // as Texture2D assets in Unity, not RenderTextures). Surfaces that get
            // sampled as `inputTex` MUST be point-sampled or transform/UV-remap effects
            // (scale/tile/pixels/seamless/refract/…) diverge by a bilinear-vs-nearest
            // delta at every fractional sample point.
            rt.filterMode = FilterMode.Point;     // reference surface sampler = NEAREST
            rt.wrapMode = TextureWrapMode.Clamp;  // reference surface wrap = CLAMP_TO_EDGE
            rt.Create();

            // PARITY (webgl2.js createFBO): every newly-created texture is cleared to
            // transparent black on creation. Persistent feedback/state textures
            // (_h1.._h8, _selfTex, _rollFb, global_*_state, ns_velocity/pressure) rely
            // on a known-zero initial frame (alpha==0 => "empty" fallback; sims start
            // clean). Unity does NOT zero a fresh RenderTexture, so clear explicitly.
            ClearToTransparentBlack(rt);

            _textures[id] = rt;
            _logicalIs3D[rt] = is3D;
            return rt;
        }

        // Clear a render texture to transparent black (0,0,0,0). Matches the
        // reference webgl2 createFBO clear. ALL RTs here are 2D — including the 64x4096
        // volume atlas (see VOLUME ATLAS CONVENTION in CreateOrReuse) — so a single
        // GL.Clear fully zeroes the surface (every voxel slice) in one pass.
        private static void ClearToTransparentBlack(RenderTexture rt)
        {
            if (rt == null) return;
            RenderTexture prev = RenderTexture.active;
            RenderTexture.active = rt;
            GL.Clear(false, true, new Color(0f, 0f, 0f, 0f));
            RenderTexture.active = prev;
        }

        public void Destroy(string id)
        {
            RenderTexture rt;
            if (_textures.TryGetValue(id, out rt))
            {
                if (rt != null)
                {
                    _logicalIs3D.Remove(rt);
                    rt.Release();
#if UNITY_EDITOR
                    Object.DestroyImmediate(rt);
#else
                    Object.Destroy(rt);
#endif
                }
                _textures.Remove(id);
            }
        }

        // Allocate one RenderTexture per distinct phys_N from graph.allocations.
        // The JS liveness allocator (resources.js allocateResources) is a plain
        // linear-scan register allocator: it reuses any freed slot WITHOUT a size
        // check, so a single phys_N can be shared by texIds of DIFFERENT sizes (e.g.
        // filter/normalize shares phys_2 between a 1x1 reduce2 and the full-res
        // output). The JS WebGL2 runtime never collapses to phys_N — it allocates a
        // real texture per virtual id at its own logical size. AllocatePooled therefore
        // creates only a provisional phys_N candidate at the maximum dimensions, using
        // the first-seen format/is3D. ResolvePhysical may reuse that candidate only when
        // the virtual texture's width, height, mapped format, and dimensionality all
        // match exactly; every incompatible alias receives a dedicated virtual-id RT.
        public void AllocatePooled(RenderGraph graph, System.Func<string, double?> uniforms)
        {
            // phys_N -> max (w,h,d) + first-seen provisional format/is3D.
            var maxW = new Dictionary<string, int>();
            var maxH = new Dictionary<string, int>();
            var maxD = new Dictionary<string, int>();
            var fmt  = new Dictionary<string, string>();
            var is3d = new Dictionary<string, bool>();
            var order = new List<string>(); // deterministic creation order

            foreach (var kv in graph.Allocations)
            {
                string virtualId = kv.Key;
                string physId = kv.Value;
                if (string.IsNullOrEmpty(physId)) continue;

                TextureSpec spec;
                if (!graph.Textures.TryGetValue(virtualId, out spec) || spec == null)
                    continue; // no spec -> created lazily on demand by ResolvePhysical

                int w = ResolveDimension(spec.Width, ScreenWidth, uniforms);
                int h = ResolveDimension(spec.Height, ScreenHeight, uniforms);
                int d = 1;
                if (spec.Is3D && spec.Depth != null)
                    d = ResolveDimension(spec.Depth, ScreenHeight, uniforms);

                if (!maxW.ContainsKey(physId))
                {
                    order.Add(physId);
                    maxW[physId] = w; maxH[physId] = h; maxD[physId] = d;
                    fmt[physId] = spec.Format; is3d[physId] = spec.Is3D;
                }
                else
                {
                    if (w > maxW[physId]) maxW[physId] = w;
                    if (h > maxH[physId]) maxH[physId] = h;
                    if (d > maxD[physId]) maxD[physId] = d;
                    // Keep the provisional identity; incompatible aliases are dedicated.
                }
            }

            foreach (string physId in order)
                CreateOrReuse(physId, maxW[physId], maxH[physId],
                    fmt[physId], is3d[physId], maxD[physId]);
        }

        public void DestroyAll()
        {
            foreach (var rt in _textures.Values)
            {
                if (rt != null)
                {
                    rt.Release();
#if UNITY_EDITOR
                    Object.DestroyImmediate(rt);
#else
                    Object.Destroy(rt);
#endif
                }
            }
            _textures.Clear();
            _logicalIs3D.Clear();
        }
    }
}
