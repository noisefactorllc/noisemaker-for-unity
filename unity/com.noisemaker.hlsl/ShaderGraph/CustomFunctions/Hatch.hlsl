#ifndef NM_HATCH_SG_INCLUDED
#define NM_HATCH_SG_INCLUDED

// Untiled Shader Graph wrapper for filter/hatch. Runtime uniforms are remapped
// into this node's namespace so several Custom Functions can coexist.
#define MODE nmsg_hatch_mode
#define strokeLength nmsg_hatch_stroke_length
#define direction nmsg_hatch_direction
#define balance nmsg_hatch_balance
#define pressure nmsg_hatch_pressure
#define inkColor nmsg_hatch_ink_color
#define paperColor nmsg_hatch_paper_color
#include "../../Shaders/Effects/filter/Hatch.hlsl"
#undef MODE
#undef strokeLength
#undef direction
#undef balance
#undef pressure
#undef inkColor
#undef paperColor

void NM_Hatch_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    int Mode,
    float StrokeLength,
    int Direction,
    float Balance,
    float Pressure,
    float3 InkColor,
    float3 PaperColor,
    out float4 Out)
{
    nmsg_hatch_mode = Mode;
    nmsg_hatch_stroke_length = StrokeLength;
    nmsg_hatch_direction = (float)Direction;
    nmsg_hatch_balance = Balance;
    nmsg_hatch_pressure = Pressure;
    nmsg_hatch_ink_color = InkColor;
    nmsg_hatch_paper_color = PaperColor;
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);

    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    Out = nm_hatch(InputTex.tex, SS.samplerstate, UV * float2(tw, th));
}

#endif
