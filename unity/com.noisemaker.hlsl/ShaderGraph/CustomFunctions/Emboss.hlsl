#ifndef NM_EMBOSS_SG_INCLUDED
#define NM_EMBOSS_SG_INCLUDED

// =============================================================================
// ShaderGraph/CustomFunctions/Emboss.hlsl
//
// Shader Graph Custom Function wrapper for filter/emboss. Add a Custom Function
// node, point it at this file, select NM_Emboss_float, and wire inputs.
//
// Inputs:
//   InputTex — source surface
//   SS       — caller-provided sampler; use point, clamp, linear/non-sRGB
//   UV       — 0..1 fragment UV (top-left origin, WGSL convention)
//   Style    — 0=color (default), 1=gray
//   Amount   — color convolution strength (default 1.0)
//   Angle    — direction in degrees (default 135)
//   Height   — sample displacement (default 1)
//   ColorAmount — source chroma traced into gray relief (default 100)
// Output:
//   Out      — RGBA with embossed RGB, original alpha
// =============================================================================

#include "../../Shaders/Effects/filter/Emboss.hlsl"

void NM_Emboss_float(
    UnityTexture2D    InputTex,
    UnitySamplerState SS,
    float2            UV,
    int               Style,
    float             Amount,
    float             Angle,
    float             Height,
    float             ColorAmount,
    out float4        Out)
{
    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);

    STYLE      = Style;
    amount     = Amount;
    angle      = Angle;
    height     = Height;
    colorAmount = ColorAmount;
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);
    _NM_FullResolution = float4(texSize, 0.0, 0.0);
    _NM_RenderScale = 1.0;

    Out = nm_emboss(InputTex.tex, SS.samplerstate, UV * texSize);
}

#endif // NM_EMBOSS_SG_INCLUDED
