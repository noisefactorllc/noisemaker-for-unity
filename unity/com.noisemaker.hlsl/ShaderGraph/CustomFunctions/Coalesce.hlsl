#ifndef NM_COALESCE_SG_INCLUDED
#define NM_COALESCE_SG_INCLUDED

// =============================================================================
// ShaderGraph/CustomFunctions/Coalesce.hlsl
//
// Shader Graph Custom Function wrapper for classicNoisedeck/coalesce.
// Add a Custom Function node, point it at this file, select NM_Coalesce_float,
// and wire the named inputs.
//
// NOTE: The core nm_coalesce()/nm_coalesce_cloak() now take the input
// resources as function parameters; this wrapper binds the UnityTexture2D/
// UnitySamplerState node inputs by passing the wrapped resources through.
//
// Param mapping (definition.js globals[*].uniform -> node input):
//   InputTex    : inputTex (base / input A)
//   Tex         : tex      (layer / input B)
//   SS          : sampler state (bilinear, clamp, linear/non-sRGB) for both
//   UV          : 0..1 fragment UV (top-left origin, WGSL convention)
//   BlendMode_  : blendMode (int, 0..18, 100, 1000..1005), default 10
//   MixAmt      : mixAmt   (-100..100), default 0   (definition.js key "mix")
//   RefractAAmt : refractAAmt (0..100),  default 0
//   RefractBAmt : refractBAmt (0..100),  default 0
//   RefractADir : refractADir (-180..180), default 0
//   RefractBDir : refractBDir (-180..180), default 0
//
// IMPORTANT: Both the cloak mode (blendMode==100) and the non-cloak refract
// path sample at derived UVs computed from st (the UV passed in), wrapped with
// frac() before sampling, as the GLSL and (since upstream bc3b9f53) the WGSL do.
// =============================================================================

Texture2D inputTex;
SamplerState sampler_inputTex;
Texture2D tex;
SamplerState sampler_tex;
#include "../../Shaders/Effects/classicNoisedeck/Coalesce.hlsl"

void NM_Coalesce_float(
    UnityTexture2D    InputTex,
    UnityTexture2D    Tex,
    UnitySamplerState SS,
    float2            UV,
    int               BlendMode_,
    float             MixAmt,
    float             RefractAAmt,
    float             RefractBAmt,
    float             RefractADir,
    float             RefractBDir,
    out float4        Out)
{
    // Bridge node inputs into the core function's module-scope named uniforms.
    blendMode   = BlendMode_;
    mixAmt      = MixAmt;
    refractAAmt = RefractAAmt;
    refractBAmt = RefractBAmt;
    refractADir = RefractADir;
    refractBDir = RefractBDir;

    // The core nm_coalesce()/nm_coalesce_cloak() now take the input resources
    // as parameters, so bind the node's UnityTexture2D/UnitySamplerState inputs
    // by passing the wrapped resources through.
    Out = nm_coalesce(UV, InputTex.tex, SS.samplerstate, Tex.tex, SS.samplerstate);
}

#endif // NM_COALESCE_SG_INCLUDED
