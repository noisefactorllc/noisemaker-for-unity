#ifndef NM_EFFECT_PARALLAX_INCLUDED
#define NM_EFFECT_PARALLAX_INCLUDED

// =============================================================================
// Parallax.hlsl — filter/parallax (func: "parallax")
//
// Ported PIXEL-IDENTICALLY from the canonical WGSL source:
//   shaders/effects/filter/parallax/wgsl/parallax.wgsl   (upstream 2144316f)
//
// Pseudo-3D perspective shift driven by a height map: ray-marched parallax
// occlusion mapping with a configurable pivot height. The view ray for each
// fragment crosses the fragment's UV at height == pivot; the input is sampled
// where the ray first dips below the height field. Single render pass.
//
// PORTING-GUIDE notes / hazards handled:
//  * The ray starts in global full-frame UV. Both input and height-map samples
//    map that global UV back into the current tile's local texture coordinates.
//  * heightMap defaults to the pipeline input (definition.js
//    globals.heightMap.default = "inputTex"); the expander binds the live
//    cursor when the user doesn't wire a surface.
//  * textureSampleLevel(t, s, uv, 0.0) → t.SampleLevel(sampler_t, uv, 0.0)
//    (explicit mip 0 — the WGSL samples inside non-uniform control flow).
//  * Loop bound is INCLUSIVE (i <= MARCH_STEPS) — copy literally.
//  * mix(rayUV, prevUV, vec2f(w)) → lerp(rayUV, prevUV, w) (scalar splat).
//  * getLuminosity uses vec3(0.299, 0.587, 0.114) — copy literally.
//  * No PCG/PRNG, no nm_mod, no float-bit hazards.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// ---- Input textures + samplers (reference: inputSampler@0, inputTex@1,
//      heightMap@2 — one shared sampler in WGSL; both HLSL samplers must carry
//      the same runtime state: point/clamp/non-sRGB, see TextureStore) --------
Texture2D    inputTex;
SamplerState sampler_inputTex;
Texture2D    heightMap;
SamplerState sampler_heightMap;

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) ------
float3 direction;   // default [0.5, 0.5, 1.0]
float  pivot;       // default 0.0   [0, 1]

// ---- Constants (verbatim from WGSL) ------------------------------------------
static const int   NM_PARALLAX_MARCH_STEPS = 32;
static const float NM_PARALLAX_SHIFT_SCALE = 0.15;

// -----------------------------------------------------------------------------
// getLuminosity — verbatim from WGSL
//   return dot(color, vec3f(0.299, 0.587, 0.114));
// -----------------------------------------------------------------------------
float nm_parallax_getLuminosity(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

// -----------------------------------------------------------------------------
// getHeight — verbatim from WGSL
//   return getLuminosity(textureSampleLevel(heightMap, inputSampler, uv, 0.0).rgb);
// -----------------------------------------------------------------------------
float nm_parallax_getHeight(float2 uv)
{
    uint mw, mh;
    heightMap.GetDimensions(mw, mh);
    float2 mapSize = float2((float)mw, (float)mh);
    float2 localUV = (uv * fullResolution - tileOffset) / mapSize;
    return nm_parallax_getLuminosity(heightMap.SampleLevel(sampler_heightMap, localUV, 0.0).rgb);
}

float4 nm_parallax_getInput(float2 uv)
{
    uint tw, th;
    inputTex.GetDimensions(tw, th);
    float2 texSize = float2((float)tw, (float)th);
    float2 localUV = (uv * fullResolution - tileOffset) / texSize;
    return inputTex.SampleLevel(sampler_inputTex, localUV, 0.0);
}

// =============================================================================
// NMFrag_parallax — main fragment for pass "parallax" (single pass).
// Mirrors the WGSL @fragment main() body verbatim.
// =============================================================================
float4 NMFrag_parallax(NMVaryings i) : SV_Target
{
    float2 uv = NM_GlobalCoord(i) / fullResolution;

    // WGSL: var v = vec3f(0.0, 0.0, 1.0);
    //       if (length(uniforms.direction) > 0.0) { v = normalize(direction); }
    float3 v = float3(0.0, 0.0, 1.0);
    if (length(direction) > 0.0)
    {
        v = normalize(direction);
    }
    float2 shift = v.xy * NM_PARALLAX_SHIFT_SCALE;

    // Large-format tile rendering is limited to the 256 full-frame-pixel
    // overlap budget. Untiled rendering is deliberately unchanged.
    bool isTileRendering = length(tileOffset) > 0.0;
    if (isTileRendering)
    {
        float maxDispPixels = 256.0;
        float dispPixels = length(shift * fullResolution);
        if (dispPixels > maxDispPixels)
        {
            shift = shift * (maxDispPixels / dispPixels);
        }
    }

    // View ray crosses this fragment's UV at height == pivot
    float  t     = 1.0;
    float2 rayUV = uv + shift * (1.0 - pivot);
    float  f     = t - nm_parallax_getHeight(rayUV);

    [branch]
    if (f > 0.0)
    {
        float stepSize = 1.0 / (float)NM_PARALLAX_MARCH_STEPS;
        [loop]
        for (int j = 1; j <= NM_PARALLAX_MARCH_STEPS; j = j + 1)
        {
            float  prevF  = f;
            float2 prevUV = rayUV;
            t     = 1.0 - (float)j * stepSize;
            rayUV = uv + shift * (t - pivot);
            f     = t - nm_parallax_getHeight(rayUV);
            if (f <= 0.0)
            {
                // Refine: interpolate between the straddling samples
                float wgt = f / (f - prevF);
                rayUV = lerp(rayUV, prevUV, wgt);
                break;
            }
        }
    }

    return nm_parallax_getInput(rayUV);
}

#endif // NM_EFFECT_PARALLAX_INCLUDED
