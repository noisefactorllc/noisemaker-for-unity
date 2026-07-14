#ifndef NM_SPIN_BLUR_SG_INCLUDED
#define NM_SPIN_BLUR_SG_INCLUDED

// Untiled Shader Graph wrapper for filter/spinBlur.
#define amount nmsg_spin_blur_amount
#define centerX nmsg_spin_blur_center_x
#define centerY nmsg_spin_blur_center_y
#include "../../Shaders/Effects/filter/SpinBlur.hlsl"
#undef amount
#undef centerX
#undef centerY

void NM_SpinBlur_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    float Amount,
    float CenterX,
    float CenterY,
    out float4 Out)
{
    nmsg_spin_blur_amount = Amount;
    nmsg_spin_blur_center_x = CenterX;
    nmsg_spin_blur_center_y = CenterY;

    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    float2 dims = float2(tw, th);
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);
    _NM_FullResolution = float4(dims, 0.0, 0.0);
    Out = nm_spin_blur(InputTex.tex, SS.samplerstate, UV * dims);
}

#endif
