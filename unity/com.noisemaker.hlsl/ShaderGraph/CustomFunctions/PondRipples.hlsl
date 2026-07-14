#ifndef NM_POND_RIPPLES_SG_INCLUDED
#define NM_POND_RIPPLES_SG_INCLUDED

// Untiled, fragment-stage Shader Graph wrapper for filter/pondRipples.
// Antialiasing uses ddx()/ddy().
#define STYLE nmsg_pond_ripples_style
#define WRAP nmsg_pond_ripples_wrap
#define amount nmsg_pond_ripples_amount
#define ridges nmsg_pond_ripples_ridges
#define antialias nmsg_pond_ripples_antialias
#include "../../Shaders/Effects/filter/PondRipples.hlsl"
#undef STYLE
#undef WRAP
#undef amount
#undef ridges
#undef antialias

void NM_PondRipples_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    float Amount,
    int Ridges,
    int Style,
    int Wrap,
    float Antialias,
    out float4 Out)
{
    nmsg_pond_ripples_amount = Amount;
    nmsg_pond_ripples_ridges = (float)Ridges;
    nmsg_pond_ripples_style = Style;
    nmsg_pond_ripples_wrap = Wrap;
    nmsg_pond_ripples_antialias = Antialias;

    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    float2 dims = float2(tw, th);
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);
    _NM_FullResolution = float4(dims, 0.0, 0.0);
    Out = nm_pond_ripples(InputTex.tex, SS.samplerstate, UV * dims);
}

#endif
