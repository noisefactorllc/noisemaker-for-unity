#ifndef NM_LENS_FLARE_SG_INCLUDED
#define NM_LENS_FLARE_SG_INCLUDED

// Untiled Shader Graph wrapper for filter/lensFlare.
#define LENS_TYPE nmsg_lens_flare_type
#define brightness nmsg_lens_flare_brightness
#define centerX nmsg_lens_flare_center_x
#define centerY nmsg_lens_flare_center_y
#define tint nmsg_lens_flare_tint
#include "../../Shaders/Effects/filter/LensFlare.hlsl"
#undef LENS_TYPE
#undef brightness
#undef centerX
#undef centerY
#undef tint

void NM_LensFlare_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    float Brightness,
    float CenterX,
    float CenterY,
    int LensType,
    float3 Tint,
    out float4 Out)
{
    nmsg_lens_flare_brightness = Brightness;
    nmsg_lens_flare_center_x = CenterX;
    nmsg_lens_flare_center_y = CenterY;
    nmsg_lens_flare_type = LensType;
    nmsg_lens_flare_tint = Tint;

    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    float2 dims = float2(tw, th);
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);
    _NM_FullResolution = float4(dims, 0.0, 0.0);
    Out = nm_lens_flare(InputTex.tex, SS.samplerstate, UV * dims);
}

#endif
