#ifndef NM_MANDALA_SG_INCLUDED
#define NM_MANDALA_SG_INCLUDED

// =============================================================================
// ShaderGraph/CustomFunctions/Mandala.hlsl
//
// Shader Graph Custom Function wrapper for synth/mandala. Add a Custom Function
// node, point it at this file, select NM_Mandala_float, and wire the named
// inputs. Outputs RGBA.
//
// The core nm_mandala() in Shaders/Effects/synth/Mandala.hlsl reads effect
// parameters from named GLOBAL uniforms. This wrapper copies each node input
// into the corresponding global before calling the core, following the standard
// Custom-Function bridging pattern used by other effects in this package.
//
// Engine globals (fullResolution/aspectRatio/time) are seeded from the Resolution
// and Time inputs. Untiled node usage has globalCoord == UV * Resolution.
// =============================================================================

#include "../../Shaders/Effects/synth/Mandala.hlsl"

void NM_Mandala_float(
    float2 UV,
    float2 Resolution,
    float  Time,
    float  Scale,
    float  Rotation,
    float  Thickness,
    float  Smoothness,
    int    Symmetry,
    int    Bindu,
    int    Shape,
    int    Layers,
    float  LayerSpacing,
    float  Twist,
    float  ShapeGrowth,
    float3 FgColor,
    float3 BgColor,
    int    Animation,
    int    Speed,
    float  PulseDepth,
    out float4 Out)
{
    // Bridge node inputs -> the core's named global uniforms.
    scale        = Scale;
    rotation     = Rotation;
    thickness    = Thickness;
    smoothness   = Smoothness;
    symmetry     = Symmetry;
    bindu        = Bindu;
    shape        = Shape;
    layers       = Layers;
    layerSpacing = LayerSpacing;
    twist        = Twist;
    shapeGrowth  = ShapeGrowth;
    fgColor      = FgColor;
    bgColor      = BgColor;
    animation    = Animation;
    speed        = Speed;
    pulseDepth   = PulseDepth;

    // Seed engine globals used inside nm_mandala (fullResolution, aspectRatio, time).
    _NM_Resolution     = float4(Resolution, 0.0, 0.0);
    _NM_FullResolution = float4(Resolution, 0.0, 0.0);
    _NM_Time           = Time;

    float2 globalCoord = UV * Resolution;
    Out = nm_mandala(globalCoord);
}

#endif // NM_MANDALA_SG_INCLUDED
