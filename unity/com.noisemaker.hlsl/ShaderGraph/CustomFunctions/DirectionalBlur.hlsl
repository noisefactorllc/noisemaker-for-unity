#ifndef NM_DIRECTIONAL_BLUR_SG_INCLUDED
#define NM_DIRECTIONAL_BLUR_SG_INCLUDED

// Untiled Shader Graph wrapper for filter/directionalBlur. Remap the runtime's
// named uniforms so multiple Custom Function files can coexist in one graph.
#define angle nmsg_directional_blur_angle
#define blurDistance nmsg_directional_blur_distance
#include "../../Shaders/Effects/filter/DirectionalBlur.hlsl"
#undef angle
#undef blurDistance

void NM_DirectionalBlur_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    float Angle,
    float Distance,
    out float4 Out)
{
    nmsg_directional_blur_angle = Angle;
    nmsg_directional_blur_distance = Distance;
    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    Out = nm_directional_blur(InputTex.tex, SS.samplerstate, UV * float2(tw, th));
}

#endif
