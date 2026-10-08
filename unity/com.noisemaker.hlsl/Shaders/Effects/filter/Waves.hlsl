#ifndef NM_EFFECT_WAVES_INCLUDED
#define NM_EFFECT_WAVES_INCLUDED

// =============================================================================
// Waves.hlsl — filter/waves (func: "waves")
//
// Ported PIXEL-IDENTICALLY from the canonical WGSL source:
//   shaders/effects/filter/waves/wgsl/waves.wgsl
//
// Sine wave distortion. Rotates the UV field, applies a sine-wave Y
// displacement, wraps according to `wrap` mode, reverse-rotates, then
// optionally applies a 4-tap RGSS antialias blit. Single render pass.
//
// PORTING-GUIDE notes / hazards handled:
//  * WGSL `uv = pos.xy / textureDimensions(inputTex)` — fragCoord divided by
//    the INPUT TEXTURE's own dimensions, not fullResolution. Matches exactly.
//  * `aspectRatio` derived from input texture size (texSize.x / texSize.y)
//    exactly as in WGSL (not the engine `aspectRatio` alias).
//  * Wrap is the GLSL's: mirror abs(mod(uv + 1.0, 2.0) - 1.0), repeat
//    mod(uv, 1.0), each one nm_mod (floored, never fmod). The old WGSL
//    `((x % k) + k) % k` agrees only in exact arithmetic; it rounds differently.
//  * `antialias` is an int uniform; test != 0 matching WGSL `antialias != 0`.
//  * dpdx/dpdy -> ddx/ddy (HLSL quads).
//  * rotate2D helper copied verbatim per-effect (PORTING-GUIDE rule 2).
//  * No PCG/PRNG/bit-exact paths in this effect.
//  * Linear, clamp-to-edge sampler (wrap applied in shader, not sampler).
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// ---- Input texture + sampler (reference binding: inputSampler@0, inputTex@1) -
Texture2D    inputTex;
SamplerState sampler_inputTex;

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) ------
float strength;   // [0, 100]  default 25
float scale;      // [1, 5]    default 1
int   speed;      // [-5, 5]   default 0
int   wrap;       // 0=mirror, 1=repeat, 2=clamp   default 0
float rotation;   // [-180, 180] default 0
int   antialias;  // bool as int  default 1

// ---- Constants ---------------------------------------------------------------
static const float NM_WAVES_PI  = 3.14159265359;
static const float NM_WAVES_TAU = 6.28318530718;

// ---- rotate2D — verbatim from WGSL rotate2D(st_in, rot, aspectRatio) ---------
//   st.x = st.x * aspectRatio
//   angle = rot * PI
//   st = st - (0.5 * aspectRatio, 0.5)
//   c = cos(angle); s = sin(angle)
//   st = (c*st.x - s*st.y, s*st.x + c*st.y)
//   st = st + (0.5 * aspectRatio, 0.5)
//   st.x = st.x / aspectRatio
// -----------------------------------------------------------------------------
float2 nm_waves_rotate2D(float2 st, float rot, float ar)
{
    st.x = st.x * ar;
    float angle = rot * NM_WAVES_PI;
    st = st - float2(0.5 * ar, 0.5);
    float c = cos(angle);
    float s = sin(angle);
    // GLSL golden: mat2(cos,-sin,sin,cos) * st. GLSL mat2 is COLUMN-MAJOR, so it
    // equals (c*st.x + s*st.y, -s*st.x + c*st.y) — opposite rotation direction from
    // the WGSL transcription (c*x-s*y, s*x+c*y). Only diverges for nonzero rotation.
    st = float2(c * st.x + s * st.y, -s * st.x + c * st.y);
    st = st + float2(0.5 * ar, 0.5);
    st.x = st.x / ar;
    return st;
}

// ---- Pass: "waves" (progName "waves") ----------------------------------------
float4 NMFrag_waves(NMVaryings i) : SV_Target
{
    // GLSL: aspectRatio = fullResolution.x / fullResolution.y;
    //       globalCoord = gl_FragCoord.xy + tileOffset;
    //       uv = globalCoord / fullResolution;
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2((float)w, (float)h);
    float ar = fullResolution.x / fullResolution.y;
    float2 globalCoord = NM_GlobalCoord(i);
    float2 uv = globalCoord / fullResolution;

    // GLSL: uv = rotate2D(uv, rotation / 180.0, aspectRatio);
    uv = nm_waves_rotate2D(uv, rotation / 180.0, ar);

    // Sine wave distortion
    float displacement = sin(uv.x * scale * 10.0 + time * NM_WAVES_TAU * (float)speed) * (strength * 0.01);

    // Bound displacement to overlap in tile mode to prevent seams
    if (any(tileOffset != float2(0.0, 0.0)))
    {
        float maxDisplacementUV = 256.0 / fullResolution.y;
        displacement = clamp(displacement, -maxDisplacementUV, maxDisplacementUV);
    }

    uv.y = uv.y + displacement;

    // Apply wrap mode
    [branch]
    if (wrap == 0)
    {
        // mirror: GLSL abs(mod(uv + 1.0, 2.0) - 1.0)
        uv = abs(nm_mod(uv + 1.0, 2.0) - 1.0);
    }
    else if (wrap == 1)
    {
        // repeat: GLSL mod(uv, 1.0)
        uv = nm_mod(uv, 1.0);
    }
    else
    {
        // clamp
        uv = clamp(uv, float2(0.0, 0.0), float2(1.0, 1.0));
    }

    // GLSL: uv = rotate2D(uv, -rotation / 180.0, aspectRatio);
    uv = nm_waves_rotate2D(uv, -rotation / 180.0, ar);

    // Convert distorted global UV to tile-local UV.
    float2 localCoord = (uv * fullResolution - tileOffset) / texSize;

    // In tile mode, wrap to enable seamless tiling. In normal mode, clamp to preserve original behavior.
    float2 sampleUV = any(tileOffset != float2(0.0, 0.0)) ? frac(localCoord) : clamp(localCoord, 0.0, 1.0);

    // WGSL antialias path (4-tap RGSS)
    [branch]
    if (antialias != 0)
    {
        float2 dx = ddx(sampleUV);
        float2 dy = ddy(sampleUV);
        float4 col = float4(0.0, 0.0, 0.0, 0.0);
        col += inputTex.Sample(sampler_inputTex, sampleUV + dx * -0.375 + dy * -0.125);
        col += inputTex.Sample(sampler_inputTex, sampleUV + dx *  0.125 + dy * -0.375);
        col += inputTex.Sample(sampler_inputTex, sampleUV + dx *  0.375 + dy *  0.125);
        col += inputTex.Sample(sampler_inputTex, sampleUV + dx * -0.125 + dy *  0.375);
        return col * 0.25;
    }
    else
    {
        return inputTex.Sample(sampler_inputTex, sampleUV);
    }
}

#endif // NM_EFFECT_WAVES_INCLUDED
