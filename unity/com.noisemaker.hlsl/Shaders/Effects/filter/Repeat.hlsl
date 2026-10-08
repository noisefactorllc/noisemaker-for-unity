#ifndef NM_REPEAT_INCLUDED
#define NM_REPEAT_INCLUDED

// =============================================================================
// Repeat.hlsl — filter/repeat, ported PIXEL-IDENTICALLY from the reference GLSL:
//   shaders/effects/filter/repeat/glsl/repeat.glsl
//
// Tiles the input texture across the screen with configurable repeat count,
// offset, and wrap mode (mirror / repeat / clamp).
//
// GLSL main() summary:
//   vec2 st = (gl_FragCoord.xy + tileOffset) / fullResolution;
//   st.x *= aspect;
//   st = st * vec2(x, y) + vec2(offsetX * aspect, offsetY);
//   st.x /= aspect;
//   // wrap mode applied to st (global UV)
//   vec2 localUV = (st * fullResolution - tileOffset) / vec2(textureSize(inputTex, 0));
//   // wrap mode applied again to localUV (tile-local UV)
//   fragColor = vec4(texture(inputTex, localUV).rgb, 1.0);
//
// PORTING-GUIDE notes:
//  * Single render pass (definition.js passes.length == 1, program "repeat").
//  * The repeat is computed in global (full-image) UV, then converted back to
//    the tile-local UV and wrapped again. Untiled, both wraps coincide.
//  * `aspect` in WGSL is bound as a f32 uniform from fullResolution.x/y.
//    We use the `aspectRatio` alias from NMFullscreen.hlsl (same value).
//  * GLSL mod -> nm_mod, never fmod (H6); GLSL fract -> frac.
//  * Mirror wrap:  GLSL abs(mod(st + 1.0, 2.0) - 1.0)  → one nm_mod call.
//  * Repeat wrap:  GLSL fract(st)                      → frac.
//  * No PRNG / no atan2 / no select / no hsv helpers in this effect.
//  * Alpha is always 1.0 (WGSL: return ...rgb, 1.0).
//  * Linear, clamp-to-edge, non-sRGB sampler (H7) — set on SamplerState in
//    Repeat.shader / supplied by the Shader Graph node.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// ---- Per-effect named uniforms (definition.js globals[*].uniform) -----------
float x;       // globals.x.uniform "x",       default 3, range [1, 20]
float y;       // globals.y.uniform "y",        default 3, range [1, 20]
float offsetX; // globals.offsetX.uniform "offsetX", default 0, range [-1, 1]
float offsetY; // globals.offsetY.uniform "offsetY", default 0, range [-1, 1]
int   wrap;    // globals.wrap.uniform "wrap",   default 1 (repeat); choices: mirror=0, repeat=1, clamp=2

// -----------------------------------------------------------------------------
// nm_repeat — core per-pixel evaluation. Returns RGBA (alpha always 1.0).
// Ported VERBATIM from repeat.wgsl main(), with coordinate derivation from i.uv.
// -----------------------------------------------------------------------------
float4 nm_repeat(NMVaryings i, Texture2D inputTex, SamplerState sampler_inputTex)
{
    // GLSL: vec2 globalCoord = gl_FragCoord.xy + tileOffset;
    //       vec2 globalUV = globalCoord / fullResolution;
    // The repeat runs in full-image space so tiled renders stay seamless.
    float2 globalCoord = NM_GlobalCoord(i);
    float2 globalUV = globalCoord / fullResolution;
    float2 st = globalUV;

    // WGSL: st.x = st.x * aspect;
    float aspect = aspectRatio;
    st.x = st.x * aspect;

    // WGSL: st = st * vec2<f32>(x, y) + vec2<f32>(offsetX * aspect, offsetY);
    st = st * float2(x, y) + float2(offsetX * aspect, offsetY);

    // WGSL: st.x = st.x / aspect;
    st.x = st.x / aspect;

    // Apply wrap mode
    [branch]
    if (wrap == 0) {
        // GLSL mirror: st = abs(mod(st + 1.0, 2.0) - 1.0);
        st = abs(nm_mod(st + 1.0, float2(2.0, 2.0)) - 1.0);
    } else if (wrap == 1) {
        // GLSL repeat: st = fract(st);
        st = frac(st);
    } else {
        // WGSL clamp: st = clamp(st, vec2<f32>(0.0), vec2<f32>(1.0));
        st = clamp(st, float2(0.0, 0.0), float2(1.0, 1.0));
    }

    // GLSL: vec2 localUV = (st * fullResolution - tileOffset) / vec2(textureSize(inputTex, 0));
    // then the same wrap again on the tile-local UV (identity when untiled).
    uint texW, texH;
    inputTex.GetDimensions(texW, texH);
    float2 localUV = (st * fullResolution - tileOffset) / float2(texW, texH);

    [branch]
    if (wrap == 0) {
        // GLSL mirror: localUV = abs(mod(localUV + 1.0, 2.0) - 1.0);
        localUV = abs(nm_mod(localUV + 1.0, float2(2.0, 2.0)) - 1.0);
    } else if (wrap == 1) {
        // GLSL repeat: localUV = fract(localUV);
        localUV = frac(localUV);
    } else {
        // GLSL clamp: localUV = clamp(localUV, 0.0, 1.0);
        localUV = clamp(localUV, float2(0.0, 0.0), float2(1.0, 1.0));
    }

    // GLSL: fragColor = vec4(texture(inputTex, localUV).rgb, 1.0);
    return float4(inputTex.Sample(sampler_inputTex, localUV).rgb, 1.0);
}

#endif // NM_REPEAT_INCLUDED
