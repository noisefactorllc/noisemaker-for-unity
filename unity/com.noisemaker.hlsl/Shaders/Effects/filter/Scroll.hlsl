#ifndef NM_SCROLL_INCLUDED
#define NM_SCROLL_INCLUDED

// =============================================================================
// Scroll.hlsl — filter/scroll, ported PIXEL-IDENTICALLY from the reference GLSL:
//   shaders/effects/filter/scroll/glsl/scroll.glsl
//
// Scrolls texture coordinates with wraparound (mirror / repeat / clamp).
//
// GLSL main():
//   vec2 globalUV = (gl_FragCoord.xy + tileOffset) / fullResolution;
//   globalUV.x *= aspect;
//   vec2 offset = vec2(-x + time * -speedX, y + time * speedY);
//   offset.x *= aspect;
//   globalUV += offset;
//   globalUV.x /= aspect;
//   vec2 localUV = (globalUV * fullResolution - tileOffset) / vec2(textureSize(inputTex, 0));
//   // apply wrap mode to localUV
//   if (wrap == 0)  { localUV = abs(mod(localUV + 1.0, 2.0) - 1.0); }  // mirror
//   else if (wrap == 1) { localUV = fract(localUV); }                 // repeat
//   else            { localUV = clamp(localUV, 0.0, 1.0); }           // clamp
//   fragColor = vec4(texture(inputTex, localUV).rgb, 1.0);
//
// PORTING-GUIDE notes:
//  * The offset is applied in global (full-image) UV; the wrap applies to the
//    tile-local UV. Untiled, the two are equal.
//  * `aspect` in WGSL is a standalone uniform = fullResolution.x / fullResolution.y.
//    NMFullscreen.hlsl provides `aspectRatio` as that same value.
//  * Wrap is the GLSL's: mirror abs(mod(uv + 1.0, 2.0) - 1.0) -> one nm_mod
//    (never fmod); repeat fract(uv) -> frac.
//  * `time` alias from NMFullscreen.hlsl = _NM_Time.
//  * Offset sign conventions copied VERBATIM: x uses -(x) and -(speedX),
//    y uses +(y) and +(speedY).
//  * wrap is an int (definition.js type: "int", choices: mirror=0, repeat=1, clamp=2).
//  * Output alpha is always 1.0 (WGSL: vec4<f32>(color.rgb, 1.0)).
//  * No PRNG / no per-effect helper functions beyond nm_mod (from NMCore via NMFullscreen).
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// Per-effect named uniforms (definition.js globals[*].uniform):
float x;       // offset x,   default 0,  range [-10..10]
float y;       // offset y,   default 0,  range [-10..10]
float speedX;  // speed x,    default 1,  range [-10..10]
float speedY;  // speed y,    default 1,  range [-10..10]
int   wrap;    // wrap mode:  0=mirror, 1=repeat, 2=clamp. default 1

// -----------------------------------------------------------------------------
// nm_scroll — core per-pixel evaluation.
// fragCoord : pixel-center coord in render-target space (NM_FragCoord output).
// Returns RGBA with alpha = 1.0.
// -----------------------------------------------------------------------------
float4 nm_scroll(float2 fragCoord, Texture2D inputTex, SamplerState samp_inputTex)
{
    // GLSL: vec2 globalCoord = gl_FragCoord.xy + tileOffset;
    //       vec2 globalUV = globalCoord / fullResolution;
    float2 globalCoord = fragCoord + tileOffset;
    float2 st = globalCoord / fullResolution;

    // GLSL: globalUV.x *= aspect;
    st.x *= aspectRatio;

    // WGSL: var offset = vec2<f32>(-x + time * -speedX, y + time * speedY);
    float2 offset = float2(-x + time * -speedX, y + time * speedY);

    // WGSL: offset.x *= aspect;
    offset.x *= aspectRatio;

    // WGSL: st += offset;
    st += offset;

    // WGSL: st.x /= aspect;
    st.x /= aspectRatio;

    // GLSL: vec2 localUV = (globalUV * fullResolution - tileOffset) / vec2(textureSize(inputTex, 0));
    // The wrap below applies to this tile-local UV (equal to st when untiled).
    uint texW, texH;
    inputTex.GetDimensions(texW, texH);
    st = (st * fullResolution - tileOffset) / float2(texW, texH);

    // Apply wrap mode.
    // GLSL mod -> nm_mod, GLSL fract -> frac.
    [branch]
    if (wrap == 0)
    {
        // GLSL mirror: abs(mod(uv + 1.0, 2.0) - 1.0)
        st = abs(nm_mod(st + 1.0, (float2)2.0) - 1.0);
    }
    else if (wrap == 1)
    {
        // GLSL repeat: fract(uv)
        st = frac(st);
    }
    else
    {
        // WGSL: st = clamp(st, vec2<f32>(0.0), vec2<f32>(1.0));
        st = clamp(st, (float2)0.0, (float2)1.0);
    }

    // WGSL: textureSampleLevel(inputTex, samp, st, 0.0)
    float3 color = inputTex.SampleLevel(samp_inputTex, st, 0.0).rgb;

    // WGSL: return vec4<f32>(color, 1.0);
    return float4(color, 1.0);
}

#endif // NM_SCROLL_INCLUDED
