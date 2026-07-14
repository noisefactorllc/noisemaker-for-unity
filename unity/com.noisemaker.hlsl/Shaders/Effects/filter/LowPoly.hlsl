#ifndef NM_LOWPOLY_INCLUDED
#define NM_LOWPOLY_INCLUDED

// =============================================================================
// LowPoly.hlsl — filter/lowPoly, ported PIXEL-IDENTICALLY from the canonical WGSL:
//   shaders/effects/filter/lowPoly/wgsl/lowPoly.wgsl
//
// Voronoi-based low-polygon art style. Generates deterministic per-cell seed
// points, finds the nearest Voronoi cell in a 3x3 neighborhood, fills with the
// input color sampled at the seed position. Modes:
//   0 flat     : pure solid cell color
//   1 edges    : solid cell color with F2-F1 edge darkening toward edgeColor
//   2 distance2: cell color * pow(clamp(F2*n),mix(0.5,3.0,edgeStrength))
//   3 distance3: cell color * pow(clamp(F3*n),mix(0.5,3.0,edgeStrength))
// Optional exact Voronoi borders and bounded exposure lighting are composed over
// the selected mode. With LP_BORDER=LP_LIGHT=0 the original 3x3 result is intact.
//
// PORTING-GUIDE notes:
//  * Single render pass (definition.js passes[].length == 1, program "lowPoly").
//  * hash2 is this effect's OWN PRNG — ported VERBATIM inline. It uses the shared
//    nm_pcg (the only shared primitive) but its sign-fold/normalize is reproduced
//    literally. WGSL select(false_val, true_val, cond) is reversed vs HLSL ?: —
//    we transcribe the resulting ternary in source order (cond ? true : false).
//    `u32(...)` is float->uint TRUNCATION toward zero -> HLSL (uint) cast.
//    Divisor is f32(0xffffffffu) = 4294967295.0 (NOT 2^32) (H11).
//  * Two distinct sample coordinates, copied literally from the WGSL:
//      uv       = pos.xy / texSize            (INPUT tex dims; for `original`)
//      cellUV   = (nearestPoint mapped back through aspect/fullResolution and
//                 tileOffset) / texSize       (for the cell color)
//    NM_FragCoord(i) is the HLSL analog of WGSL position.xy (top-left, +0.5).
//    globalUV uses NM_GlobalCoord (pos.xy + tileOffset) / fullResolution.
//  * aspect = fullResolution.x / fullResolution.y (precomputed; H-aspect).
//  * mode: WGSL `i32`; declared int uniform, branched with [branch] to mirror the
//    if/else chain. distance2/distance3 selected by `mode == 2 ? F2 : F3`.
//  * Loop bounds inclusive (-1..1 on both axes) exactly as written.
//  * Linear, clamp-to-edge, non-sRGB sampler (H7) — set in LowPoly.shader.
//  * TODO(verify): the cellColor sample uv can fall outside [0,1] for edge cells;
//    clamp-to-edge addressing must match WebGL2/WebGPU (CLAMP_TO_EDGE) for parity.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

static const float NM_LOWPOLY_TAU = 6.28318530718;

// ---- Per-effect named uniforms (definition.js globals[*].uniform) -----------
// Bound by the runtime via MaterialPropertyBlock under these exact names.
int    scale;        // globals.scale.uniform        default 50  (WGSL f32)
int    seed;         // globals.seed.uniform         default 1   (WGSL f32)
int    mode;         // globals.mode.uniform         default 1
float  edgeStrength; // globals.edgeStrength.uniform default 0.15
float3 edgeColor;    // globals.edgeColor.uniform    default (0,0,0)
float  alpha;        // globals.alpha.uniform        default 1.0
int    speed;        // globals.speed.uniform        default 0   (WGSL f32)
int    LP_BORDER;    // globals.borderWidth.define   default 0
int    LP_LIGHT;     // globals.lightIntensity.define default 0

// -----------------------------------------------------------------------------
// hash2 — ported VERBATIM from lowPoly.wgsl. Per-effect PRNG; uses shared nm_pcg.
// WGSL:
//   fn hash2(p: vec2<f32>, s: f32) -> vec2<f32> {
//       let v = pcg(vec3<u32>(
//           u32(select(-p.x * 2.0 + 1.0, p.x * 2.0, p.x >= 0.0)),
//           u32(select(-p.y * 2.0 + 1.0, p.y * 2.0, p.y >= 0.0)),
//           u32(select(-s   * 2.0 + 1.0, s   * 2.0, s   >= 0.0)),
//       ));
//       return vec2<f32>(v.xy) / f32(0xffffffffu);
//   }
// WGSL select(a,b,c) == c ? b : a, so each component is (cond ? cond*2 : -*2+1).
// -----------------------------------------------------------------------------
float2 nm_lowpoly_hash2(float2 p, float s)
{
    uint3 v = nm_pcg(uint3(
        (uint)(p.x >= 0.0 ? p.x * 2.0 : -p.x * 2.0 + 1.0),
        (uint)(p.y >= 0.0 ? p.y * 2.0 : -p.y * 2.0 + 1.0),
        (uint)(s   >= 0.0 ? s   * 2.0 : -s   * 2.0 + 1.0)
    ));
    return float2(v.xy) / 4294967295.0;
}

float2 nm_lowpoly_site(int2 siteCell, float n, float s, float spd)
{
    float2 siteCellF = float2(siteCell);
    float2 offset = nm_lowpoly_hash2(siteCellF, s);

    if (spd > 0.0)
    {
        float2 animRand = nm_lowpoly_hash2(siteCellF, s + 100.0);
        float angle = time * NM_LOWPOLY_TAU + animRand.x * NM_LOWPOLY_TAU;
        float radius = animRand.y * spd;
        offset = clamp(offset + float2(cos(angle), sin(angle)) * radius,
            float2(0.0, 0.0), float2(1.0, 1.0));
    }

    return (siteCellF + offset) / n;
}

// -----------------------------------------------------------------------------
// nm_lowpoly — core per-pixel evaluation. Samples InputTex through the provided
// Texture2D/SamplerState so the Shader Graph wrapper and the render pass share
// identical math. Ported VERBATIM from lowPoly.wgsl main(). `globalUV` and `uv`
// are passed in (computed once from fragcoord) to match the WGSL exactly.
//   texSize = vec2<f32>(textureDimensions(inputTex))   (INPUT tex dims)
//   uv      = pos.xy / texSize
//   globalUV= (pos.xy + tileOffset) / fullResolution
// -----------------------------------------------------------------------------
float4 nm_lowpoly(Texture2D inputTex, SamplerState ss, float2 texSize, float2 uv, float2 globalUV)
{
    float n = max(102.0 - (float)scale, 2.0);
    float s = (float)seed;
    float spd = (float)speed * 0.3;

    // Aspect-corrected coordinates for square Voronoi cells
    float aspect = fullResolution.x / fullResolution.y;
    float2 auv = float2(globalUV.x * aspect, globalUV.y);

    // Scale to grid in corrected space
    float2 scaled = auv * n;
    int2 cell = int2(floor(scaled));

    float minDist = 1e10;
    float secondDist = 1e10;
    float thirdDist = 1e10;
    float2 nearestPoint = float2(0.0, 0.0);
    int2 nearestCell = int2(0, 0);

    // Search 3x3 neighborhood of cells
    for (int dy = -1; dy <= 1; dy = dy + 1) {
        for (int dx = -1; dx <= 1; dx = dx + 1) {
            int2 neighbor = cell + int2(dx, dy);
            float2 neighborF = float2(neighbor);

            // Generate seed point in this cell
            float2 offset = nm_lowpoly_hash2(neighborF, s);

            // Animate: per-cell circular drift with unique phase/radius
            if (spd > 0.0) {
                float2 animRand = nm_lowpoly_hash2(neighborF, s + 100.0);
                float angle = time * NM_LOWPOLY_TAU + animRand.x * NM_LOWPOLY_TAU;
                float radius = animRand.y * spd;
                offset = clamp(offset + float2(cos(angle), sin(angle)) * radius, float2(0.0, 0.0), float2(1.0, 1.0));
            }

            float2 cellPoint = (neighborF + offset) / n;
            float d = distance(auv, cellPoint);

            if (d < minDist) {
                thirdDist = secondDist;
                secondDist = minDist;
                minDist = d;
                nearestPoint = cellPoint;
                nearestCell = neighbor;
            } else if (d < secondDist) {
                thirdDist = secondDist;
                secondDist = d;
            } else if (d < thirdDist) {
                thirdDist = d;
            }
        }
    }

    // Convert nearest point back to UV space for texture sampling
    float4 cellColor = inputTex.Sample(ss, (float2(nearestPoint.x / aspect, nearestPoint.y) * fullResolution - tileOffset) / texSize);

    float3 result;
    [branch]
    if (mode == 0) {
        // Flat: pure solid cell color
        result = cellColor.rgb;
    } else if (mode == 1) {
        // Edges: solid cell color with F2-F1 edge darkening
        float edgeDist = clamp((secondDist - minDist) * n * 2.0, 0.0, 1.0);
        float edgeFactor = lerp(edgeStrength, 0.0, edgeDist);
        result = lerp(cellColor.rgb, edgeColor, edgeFactor);
    } else {
        // Distance: multiply distance field with cell color
        float selectedDist;
        if (mode == 2) { selectedDist = secondDist; }
        else { selectedDist = thirdDist; }
        float raw = clamp(selectedDist * n, 0.0, 1.0);
        float distField = pow(raw, lerp(0.5, 3.0, edgeStrength));
        result = cellColor.rgb * distField;
    }

    // Optional border and lighting layer. Default zero values skip both blocks
    // and leave the established mode arithmetic/result untouched.
    float3 modeResult = result;
    float borderMask = 0.0;

    [branch]
    if (LP_BORDER != 0)
    {
        float2 borderNearestPoint = nearestPoint;
        int2 borderNearestCell = nearestCell;
        float borderNearestDist = minDist;
        [loop]
        for (int borderDy = -2; borderDy <= 2; borderDy = borderDy + 1)
        {
            [loop]
            for (int borderDx = -2; borderDx <= 2; borderDx = borderDx + 1)
            {
                int2 candidateCell = cell + int2(borderDx, borderDy);
                float2 candidatePoint = nm_lowpoly_site(candidateCell, n, s, spd);
                float candidateDist = distance(auv, candidatePoint);
                if (candidateDist < borderNearestDist)
                {
                    borderNearestDist = candidateDist;
                    borderNearestPoint = candidatePoint;
                    borderNearestCell = candidateCell;
                }
            }
        }

        float distToEdge = 1e10;
        [loop]
        for (int edgeDy = -2; edgeDy <= 2; edgeDy = edgeDy + 1)
        {
            [loop]
            for (int edgeDx = -2; edgeDx <= 2; edgeDx = edgeDx + 1)
            {
                int2 candidateCell = cell + int2(edgeDx, edgeDy);
                if (any(candidateCell != borderNearestCell))
                {
                    float2 candidatePoint = nm_lowpoly_site(candidateCell, n, s, spd);
                    float2 siteVector = candidatePoint - borderNearestPoint;
                    float siteDistance = max(length(siteVector), 1e-8);
                    float bisectorDistance = dot(
                        (borderNearestPoint + candidatePoint) * 0.5 - auv,
                        siteVector / siteDistance);
                    distToEdge = min(distToEdge, bisectorDistance);
                }
            }
        }

        float cellRadius = 0.5 / n;
        float borderHalfWidth = ((float)LP_BORDER / 100.0) * cellRadius;
        float borderFeather = max(fwidth(distToEdge), 1e-6);
        borderMask = 1.0 - smoothstep(
            borderHalfWidth - borderFeather,
            borderHalfWidth + borderFeather,
            distToEdge);
        result = lerp(modeResult, edgeColor, borderMask);
    }

    [branch]
    if (LP_LIGHT != 0)
    {
        float intensity = clamp((float)LP_LIGHT / 100.0, 0.0, 1.0);
        float paneValue = max(max(modeResult.r, modeResult.g), modeResult.b);
        float exposure = lerp(1.0, 2.25, intensity);
        float litValue = 1.0 - pow(max(1.0 - paneValue, 0.0), exposure);
        float3 litMode = modeResult;
        if (paneValue > 1e-6)
        {
            litMode = modeResult * (litValue / paneValue);
        }
        result = lerp(litMode, edgeColor, borderMask);
    }

    // Alpha blend with original
    float4 original = inputTex.Sample(ss, uv);
    return float4(lerp(original.rgb, result, alpha), original.a);
}

#endif // NM_LOWPOLY_INCLUDED
