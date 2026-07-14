#ifndef NM_STIPPLE_SG_INCLUDED
#define NM_STIPPLE_SG_INCLUDED

// Untiled, fragment-stage Shader Graph wrapper for filter/stipple.
// Pointillize antialiasing uses fwidth().
#define MODE nmsg_stipple_mode
#define cellSize nmsg_stipple_cell_size
#define grainSize nmsg_stipple_grain_size
#define density nmsg_stipple_density
#define paperColor nmsg_stipple_paper_color
#define seed nmsg_stipple_seed
#include "../../Shaders/Effects/filter/Stipple.hlsl"
#undef MODE
#undef cellSize
#undef grainSize
#undef density
#undef paperColor
#undef seed

void NM_Stipple_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    int Mode,
    float CellSize,
    float GrainSize,
    float Density,
    float3 PaperColor,
    int Seed,
    out float4 Out)
{
    nmsg_stipple_mode = Mode;
    nmsg_stipple_cell_size = CellSize;
    nmsg_stipple_grain_size = GrainSize;
    nmsg_stipple_density = Density;
    nmsg_stipple_paper_color = PaperColor;
    nmsg_stipple_seed = (float)Seed;
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);

    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    Out = nm_stipple(InputTex.tex, SS.samplerstate, UV * float2(tw, th));
}

#endif
