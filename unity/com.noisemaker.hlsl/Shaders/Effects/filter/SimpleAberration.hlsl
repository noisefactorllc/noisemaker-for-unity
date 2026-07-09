#ifndef NM_SIMPLEABERRATION_INCLUDED
#define NM_SIMPLEABERRATION_INCLUDED

// =============================================================================
// SimpleAberration.hlsl — filter/simpleAberration, ported PIXEL-IDENTICALLY
// from the GLSL reference (the WebGL2 golden):
//   shaders/effects/filter/simpleAberration/glsl/chromaticAberration.glsl
// (the WGSL variant agrees except as noted below).
//
// Chromatic aberration: sample R at (uv.x + displacement, uv.y),
//                        G at uv,
//                        B at (uv.x - displacement, uv.y).
// Alpha from the green sample. (The WGSL clamps each offset UV.x to [0,1]
// instead of bounding the displacement; we follow the GLSL bound.)
//
// MATCH THE GLSL (the WebGL2 golden) for the displacement BOUND, which the WGSL
// omits. The GLSL (simpleAberration/glsl/chromaticAberration.glsl) main():
//   globalUV     = (gl_FragCoord.xy + tileOffset) / fullResolution;
//   bounded      = clamp(displacement, -256/fullResolution.x, 256/fullResolution.x);
//   redLocalUV   = (globalUV + vec2(bounded,0)) * fullResolution - tileOffset) / texSize;
//   red          = texture(inputTex, redLocalUV);
//   green        = same with no x offset; blue = globalUV - vec2(bounded,0).
//   return vec4(red.r, green.g, blue.b, green.a);
// Y ORIENTATION: the GLSL used to flip Y per channel (localUV.y = 1.0 - localUV.y),
// and this port copied that. Upstream cee90aaf declared the flip the GL2 bug and
// removed it — GLSL and WGSL now agree; sample the local UV unflipped.
//
// PORTING-GUIDE notes:
//  * texSize = textureDimensions(inputTex); fullResolution/tileOffset = engine
//    globals (NMFullscreen). For the untiled square case texSize==fullResolution
//    and tileOffset==0, so the localUV transform reduces to globalUV.
//  * No helpers from NMCore are needed (no pcg/prng/random/nm_mod).
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// Per-effect uniform (definition.js globals.displacement.uniform = "displacement")
float displacement;

// -----------------------------------------------------------------------------
// nm_simpleAberration — core per-pixel chromatic aberration, ported from the
// GLSL golden. globalPixel = NM_GlobalCoord(i) (= fragCoord + tileOffset).
// -----------------------------------------------------------------------------
float4 nm_simpleAberration(
    Texture2D    inputTex,
    SamplerState sampler_inputTex,
    float2       globalPixel,
    float2       texSize)
{
    float2 globalUV = globalPixel / fullResolution;

    // GLSL: bounded = clamp(displacement, -256/fullResolution.x, 256/fullResolution.x)
    float maxDisp = 256.0 / fullResolution.x;
    float bd      = clamp(displacement, -maxDisp, maxDisp);

    // Red: +x displacement
    float2 redL = ((globalUV + float2(bd, 0.0)) * fullResolution - tileOffset) / texSize;
    float4 red = inputTex.Sample(sampler_inputTex, redL);

    // Green: no x offset
    float2 greenL = (globalUV * fullResolution - tileOffset) / texSize;
    float4 green = inputTex.Sample(sampler_inputTex, greenL);

    // Blue: -x displacement
    float2 blueL = ((globalUV - float2(bd, 0.0)) * fullResolution - tileOffset) / texSize;
    float4 blue = inputTex.Sample(sampler_inputTex, blueL);

    // GLSL: fragColor = vec4(red.r, green.g, blue.b, green.a);
    return float4(red.r, green.g, blue.b, green.a);
}

#endif // NM_SIMPLEABERRATION_INCLUDED
