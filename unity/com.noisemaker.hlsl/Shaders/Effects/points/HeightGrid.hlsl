#ifndef NM_EFFECT_HEIGHTGRID_INCLUDED
#define NM_EFFECT_HEIGHTGRID_INCLUDED

// =============================================================================
// HeightGrid.hlsl — points/heightGrid (func: "heightGrid") — NEW this round
// (reference 0ed489ec). Arranges every pointsEmit-allocated slot into a square
// XZ grid with height-mapped Y, sourced from separate height/diffuse 2D
// surfaces. Ported PIXEL-IDENTICALLY from the canonical GLSL source (this
// effect ships GLSL upstream, top-left/D3D-oriented already — no per-effect Y
// flip needed, same as RenderLandscape3d.hlsl):
//   glsl/agent.glsl         progName "agent"         (frag_agent)   MRT
//   glsl/passthrough.glsl   progName "passthrough"   (frag_passthrough)
//
// Common Agent Architecture (matches Flow.hlsl/Physarum.hlsl conventions):
//   agent pass: MRT (drawBuffers:3), viewport == stateSize x stateSize (NOT
//   screen resolution) — derive the agent texel from i.uv * stateSize, NOT
//   NM_FragCoord (which multiplies by the runtime's SCREEN-sized
//   _NM_Resolution; see Flow.hlsl's frag_agent for the full rationale).
//   Inputs (definition.js): xyzTex=global_xyz, velTex=global_vel,
//   heightTex, diffuseTex. Outputs: outXYZ/outVel/outRGBA -> global_xyz/
//   global_vel/global_rgba.
//
// PORTING-GUIDE / parity notes:
//  * texelFetch(t, ivec2, 0) -> t.Load(int3(coord, 0)); texture(t, uv) (BILINEAR)
//    -> t.Sample(sampler_t, uv) — heightTex/diffuseTex are sampled (not Loaded)
//    in the reference, matching a regular filtered surface read.
//  * uv = (vec2(coord)+0.5)/vec2(stateSize) — pixel-center UV over the state
//    texture, reproduced literally (equivalent to i.uv here since NMVaryings.uv
//    is already the pixel-center UV over the same viewport).
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

Texture2D xyzTex;      SamplerState sampler_xyzTex;
Texture2D velTex;      SamplerState sampler_velTex;
Texture2D heightTex;   SamplerState sampler_heightTex;
Texture2D diffuseTex;  SamplerState sampler_diffuseTex;
Texture2D inputTex;    SamplerState sampler_inputTex;

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) -----
float gridScale;    // globals.gridScale    default 80
float heightScale;  // globals.heightScale  default 20
float heightOffset; // globals.heightOffset default 0

// MRT output struct: location 0 = xyz, 1 = vel, 2 = rgba (matches drawBuffers:3
// and definition.js outputs{ outXYZ, outVel, outRGBA }).
struct HeightGridAgentOutputs
{
    float4 outXYZ  : SV_Target0;
    float4 outVel  : SV_Target1;
    float4 outRGBA : SV_Target2;
};

// =============================================================================
// PASS: agent — arrange every slot into a height-mapped XZ grid (MRT).
// =============================================================================
HeightGridAgentOutputs frag_agent(NMVaryings i)
{
    HeightGridAgentOutputs o;

    // pointsEmit allocates a square state texture: one grid vertex per slot.
    // Derive the agent texel from the UV varying, not NM_FragCoord (the agent
    // pass's viewport is stateSize x stateSize, not the screen) — same
    // rationale as Flow.hlsl/frag_agent.
    uint sw, sh;
    xyzTex.GetDimensions(sw, sh);
    int2 stateSize = int2((int)sw, (int)sh);
    int2 coord = int2(i.uv * float2(stateSize));
    float2 uv = (float2(coord) + 0.5) / float2(stateSize);

    float3 heightColor = heightTex.Sample(sampler_heightTex, uv).rgb;
    float elevation = dot(heightColor, float3(0.2126, 0.7152, 0.0722));

    // XZ ground plane, Y elevation. These are world coordinates, not UVs.
    o.outXYZ = float4((uv.x - 0.5) * gridScale,
        elevation * heightScale + heightOffset,
        (uv.y - 0.5) * gridScale, 1.0);
    o.outVel = float4(0.0, 0.0, 0.0, velTex.Load(int3(coord, 0)).w);
    o.outRGBA = diffuseTex.Sample(sampler_diffuseTex, uv);
    return o;
}

// =============================================================================
// PASS: passthrough — trivial blit (frag_passthrough, fullscreen).
// =============================================================================
float4 frag_passthrough(NMVaryings i) : SV_Target
{
    float2 uv = NM_FragCoord(i) / resolution;
    return inputTex.Sample(sampler_inputTex, uv);
}

#endif // NM_EFFECT_HEIGHTGRID_INCLUDED
