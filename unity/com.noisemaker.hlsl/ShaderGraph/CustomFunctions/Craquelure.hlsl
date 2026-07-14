#ifndef NM_CRAQUELURE_SG_INCLUDED
#define NM_CRAQUELURE_SG_INCLUDED

// Untiled Shader Graph wrapper for filter/craquelure.
#define spacing nmsg_craquelure_spacing
#define depth nmsg_craquelure_depth
#define brightness nmsg_craquelure_brightness
#define seed nmsg_craquelure_seed
#include "../../Shaders/Effects/filter/Craquelure.hlsl"
#undef spacing
#undef depth
#undef brightness
#undef seed

void NM_Craquelure_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    float Spacing,
    float Depth,
    float Brightness,
    int Seed,
    out float4 Out)
{
    nmsg_craquelure_spacing = Spacing;
    nmsg_craquelure_depth = Depth;
    nmsg_craquelure_brightness = Brightness;
    nmsg_craquelure_seed = (float)Seed;
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);

    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    Out = nm_craquelure(InputTex.tex, SS.samplerstate, UV * float2(tw, th));
}

#endif
