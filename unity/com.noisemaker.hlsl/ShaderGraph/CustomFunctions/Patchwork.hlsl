#ifndef NM_PATCHWORK_SG_INCLUDED
#define NM_PATCHWORK_SG_INCLUDED

// Untiled Shader Graph wrapper for filter/patchwork.
#define squareSize nmsg_patchwork_square_size
#define relief nmsg_patchwork_relief
#define lightAngle nmsg_patchwork_light_angle
#include "../../Shaders/Effects/filter/Patchwork.hlsl"
#undef squareSize
#undef relief
#undef lightAngle

void NM_Patchwork_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    float SquareSize,
    float Relief,
    float LightAngle,
    out float4 Out)
{
    nmsg_patchwork_square_size = SquareSize;
    nmsg_patchwork_relief = Relief;
    nmsg_patchwork_light_angle = LightAngle;

    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    float2 dims = float2(tw, th);
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);
    _NM_FullResolution = float4(dims, 0.0, 0.0);
    Out = nm_patchwork(InputTex.tex, SS.samplerstate, UV * dims);
}

#endif
