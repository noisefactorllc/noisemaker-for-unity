#ifndef NM_EFFECT_FLOW_INCLUDED
#define NM_EFFECT_FLOW_INCLUDED

// =============================================================================
// Flow.hlsl — points/flow (func: "flow")
//
// Agent-based luminosity flow field. Ported PIXEL-IDENTICALLY from the
// canonical WGSL sources (top-left origin, no per-effect Y flip):
//   wgsl/agent.wgsl        progName "agent"        (MRT: frag_agent)
//   wgsl/passthrough.wgsl  progName "passthrough"  (frag_passthrough)
//
// MULTI-PASS / AGENT MIDDLEWARE: this effect is COMMON-AGENT-ARCHITECTURE
// middleware in a particle pipeline (pointsEmit -> flow -> pointsRender). It
// does NOT itself create or deposit/scatter agents — there is NO drawMode
// "points" deposit pass in this effect. The deposit (scatter) and trail/diffuse
// passes live in the *pointsRender* effect; agent allocation lives in
// *pointsEmit*. Flow only UPDATES persistent agent state.
//
//   PASS 1 "agent" (fullscreen-over-state, MRT 3 outputs):
//     Renders fullscreen across the agent STATE texture (one fragment per
//     agent texel). Reads previous state from the persistent 'global_'-prefixed
//     state textures, applies one step of flow-field movement, and writes the
//     three updated state textures via MRT (drawBuffers:3). The runtime
//     ping-pongs each global state surface (reference 04 §10.7 isStateSurface:
//     names end with _xyz / _vel / _rgba => persist, NO swap; particle sim
//     continues from last frame's buffers).
//   PASS 2 "passthrough" (fullscreen):
//     Copies inputTex -> outputTex for 2D-chain continuity. Pure blit by uv.
//
// STATE TEXTURES (all rgba32f, full float, persistent, scoped to the particle
// pipeline that created them — keys global_xyz / global_vel / global_rgba):
//   global_xyz : [x, y, z, alive]                 positions normalized [0,1]
//   global_vel : [vx, vy, rotRand, strideRand]    flow uses only rotRand/strideRand
//   global_rgba: [r, g, b, a]                      agent color (passed through)
//
// NOTE: multi-pass / agent-middleware effect -> ships as a runtime-rendered
// Texture2D. NO Shader Graph Custom Function wrapper is provided (the C#
// runtime drives the 2 passes in order, rebinding the global_xyz/vel/rgba
// read/write state targets per frame; it cannot be a single-node generator).
//
// PORTING-GUIDE / parity notes:
//  * WGSL textureLoad(t, coord, 0) -> t.Load(int3(coord, 0)) (integer texel
//    fetch, point, no filtering). The agent pass reads rgba32f state this way.
//  * RESOLUTION SEMANTICS: _NM_Resolution tracks the current render target,
//    while the reference's u.resolution stays at the SCREEN/canvas size. So:
//      - Stride math uses _NM_ScreenResolution, matching WGSL u.resolution.
//      - Agent texel selection follows the bound state texture's dimensions.
//        WGSL vec2i(fragCoord.xy) is over that target; here i.uv * stateSize
//        (xyzTex.GetDimensions) avoids dependence on viewport bookkeeping.
//  * PRNG: this effect ships its OWN hash (PCG-style hash_uint + hash), which
//    differs from NMCore's pcg/prng/random -- per PORTING-GUIDE rule 2 we
//    inline THIS effect's version, not the shared one. hash divisor is
//    4294967295.0 (= float(0xffffffffu)).
//  * select(-1.0, 1.0, value >= 0.0) -> (value >= 0.0) ? 1.0 : -1.0 (WGSL
//    select(false_val, true_val, cond) is reversed vs ternary -- handled).
//  * i32(float) truncation -> (int)float. fract -> frac. mix -> lerp.
//  * round() -> HLSL round() (round-half-to-even; WGSL round is also
//    round-half-to-even, so parity holds). Used only when quantize > 0.5.
//  * No nm_mod used (wrapping is frac()). No fmod.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"
float4 _NM_ScreenResolution; // canvas size; state pass target can be smaller

// ---- Input textures across both passes --------------------------------------
// agent:       xyzTex, velTex, rgbaTex (Load); inputTex (Load by texel)
//               heightTex, diffuseTex, baseColorTex (Load)
// passthrough: inputTex (Sample)
// The runtime rebinds these per pass per definition.js inputs{}.
Texture2D    inputTex;   SamplerState sampler_inputTex;
Texture2D    xyzTex;     SamplerState sampler_xyzTex;
Texture2D    velTex;     SamplerState sampler_velTex;
Texture2D    rgbaTex;    SamplerState sampler_rgbaTex;
Texture2D    heightTex;  SamplerState sampler_heightTex;
Texture2D    diffuseTex; SamplerState sampler_diffuseTex;
Texture2D    baseColorTex; SamplerState sampler_baseColorTex;

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) ------
// agent uses: behavior, stride, strideDeviation, kink, quantize, inputWeight,
//             plus engine globals resolution (screen) and time.
// (stateSize is a sizing-only global with ui.control:false; the shader derives
//  state dimensions from the bound state texture, NOT from a uniform -- exactly
//  like the WGSL textureDimensions(xyzTex). So no stateSize uniform is read.)
int   behavior;          // globals.behavior         default 1 (obedient)
float stride;            // globals.stride           default 10
float strideDeviation;   // globals.strideDeviation  default 0.05
float kink;              // globals.kink             default 1
float quantize;          // globals.quantize         boolean (1.0/0.0), tested > 0.5
float inputWeight;       // globals.inputWeight      default 100
float fieldActive;       // globals.heightTex colorModeUniform (1 when heightTex is wired)
float diffuseActive;     // globals.diffuseTex colorModeUniform (1 when diffuseTex is wired)

// WGSL selectedDiffuse: clamp uv, convert to texel coords, textureLoad.
float4 flow_selectedDiffuse(float2 uv)
{
    uint dw, dh;
    diffuseTex.GetDimensions(dw, dh);
    float2 clamped = clamp(uv, float2(0.0, 0.0), float2(0.999999, 0.999999));
    int2 pixel = clamp((int2)(clamped * float2((float)dw, (float)dh)), int2(0, 0), int2((int)dw - 1, (int)dh - 1));
    return diffuseTex.Load(int3(pixel, 0));
}

// WGSL spawnColor: the color render/pointsEmit gives an agent spawned at pos.
float4 flow_spawnColor(float2 pos)
{
    uint dw, dh;
    inputTex.GetDimensions(dw, dh);
    int2 coord = (int2)(pos * float2((float)dw, (float)dh));
    float4 sampled = inputTex.Load(int3(coord, 0));
    return sampled.a > 0.0 ? sampled : float4(1.0, 1.0, 1.0, 1.0);
}

// WGSL baseColor: the agent's color without a diffuse map. baseColorTex keeps
// it (alpha > 0) while a diffuse map is active and is cleared otherwise, so
// this is rgba unless the agent still carries a diffuse color and has not
// respawned.
float4 flow_baseColor(int2 coord, float4 rgba, float2 pos)
{
    float4 kept = baseColorTex.Load(int3(coord, 0));
    if (kept.a == 0.0) return rgba;
    float4 spawn = flow_spawnColor(pos);
    float4 spawnDelta = abs(round(rgba * 255.0) - round(clamp(spawn, 0.0, 1.0) * 255.0));
    return all(spawnDelta <= float4(1.0, 1.0, 1.0, 1.0)) ? rgba : kept;
}

float4 flow_keptBaseColor(float4 base)
{
    return diffuseActive > 0.5 ? float4(base.rgb, max(base.a, 1.0 / 255.0)) : float4(0.0, 0.0, 0.0, 0.0);
}

// =============================================================================
// PASS: agent — flow-field agent update (MRT: outXYZ/outVel/outRGBA)
// =============================================================================
static const float FLOW_TAU         = 6.283185307179586;
static const float FLOW_RIGHT_ANGLE = 1.5707963267948966;

// MRT output struct: location 0 = xyz, 1 = vel, 2 = rgba, 3 = baseColor
// (matches drawBuffers:4 and definition.js outputs{
//  outXYZ:color, outVel:color1, outRGBA:color2, outBaseColor:color3 }).
struct FlowAgentOutputs
{
    float4 xyz        : SV_Target0;
    float4 vel        : SV_Target1;
    float4 rgba       : SV_Target2;
    float4 baseColor  : SV_Target3;
};

// Effect-local PRNG (verbatim from agent.wgsl -- do NOT substitute NMCore pcg).
uint flow_hash_uint(uint seed)
{
    uint state = seed * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float flow_hash(uint seed)
{
    return (float)flow_hash_uint(seed) / 4294967295.0;
}

float flow_srgb_to_linear(float value)
{
    if (value <= 0.04045) { return value / 12.92; }
    return pow((value + 0.055) / 1.055, 2.4);
}

float flow_cube_root(float value)
{
    if (value == 0.0) { return 0.0; }
    float sign_value = (value >= 0.0) ? 1.0 : -1.0;   // select(-1.0,1.0,value>=0.0)
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

float flow_oklab_l(float3 rgb)
{
    float r_lin = flow_srgb_to_linear(clamp(rgb.x, 0.0, 1.0));
    float g_lin = flow_srgb_to_linear(clamp(rgb.y, 0.0, 1.0));
    float b_lin = flow_srgb_to_linear(clamp(rgb.z, 0.0, 1.0));
    float l = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;
    return 0.2104542553 * flow_cube_root(l) + 0.7936177850 * flow_cube_root(m) - 0.0040720468 * flow_cube_root(s);
}

float flow_normalized_sine(float value)
{
    return (sin(value) + 1.0) * 0.5;
}

float flow_computeRotationBias(int behaviorMode, float baseHeading, float rotRand, float t, int agentIndex, int totalAgents)
{
    if (behaviorMode <= 0) {
        return 0.0;
    } else if (behaviorMode == 1) {
        return baseHeading;
    } else if (behaviorMode == 2) {
        return baseHeading + floor(rotRand * 4.0) * FLOW_RIGHT_ANGLE;
    } else if (behaviorMode == 3) {
        return baseHeading + (rotRand - 0.5) * 0.25;
    } else if (behaviorMode == 4) {
        return rotRand * FLOW_TAU;
    } else if (behaviorMode == 5) {
        int quarterSize = max(1, totalAgents / 4);
        int band = agentIndex / quarterSize;
        if (band <= 0) {
            return baseHeading;
        } else if (band == 1) {
            return baseHeading + floor(rotRand * 4.0) * FLOW_RIGHT_ANGLE;
        } else if (band == 2) {
            return baseHeading + (rotRand - 0.5) * 0.25;
        } else {
            return rotRand * FLOW_TAU;
        }
    } else if (behaviorMode == 10) {
        return flow_normalized_sine((t - rotRand) * FLOW_TAU);
    } else {
        return rotRand * FLOW_TAU;
    }
}

FlowAgentOutputs frag_agent(NMVaryings i)
{
    // Agent texel = vec2i(fragCoord.xy) where fragCoord is over the STATE
    // texture (the agent pass viewport == stateSize x stateSize). Derive the
    // texel from i.uv * stateSize so it stays tied to the bound state texture.
    uint sw, sh;
    xyzTex.GetDimensions(sw, sh);
    int2 stateSize = int2((int)sw, (int)sh);
    // State texture dimensions (== stateSize x stateSize) for agentIndex/total.
    // NOTE: the reference does NOT clamp the state-read coord (only the inputTex
    // coord is clamped below); we match that -- coord is always in-bounds for a
    // rasterized agent texel.
    int2 coord = int2(i.uv * float2(stateSize));

    // Read input state from the pipeline (rgba32f, point fetch).
    float4 xyz  = xyzTex.Load(int3(coord, 0));
    float4 vel  = velTex.Load(int3(coord, 0));
    float4 rgba = rgbaTex.Load(int3(coord, 0));
    float4 base = flow_baseColor(coord, rgba, xyz.xy);

    // Extract components (positions in normalized coords [0,1]).
    float px = xyz.x;
    float py = xyz.y;
    float pz = xyz.z;
    float alive = xyz.w;

    // Flow-specific per-agent randoms stored in vel.zw (set by pointsEmit).
    float rotRand    = vel.z;   // [0,1]
    float strideRand = vel.w;   // [-0.5, 0.5]

    // If not alive, pass through unchanged.
    if (alive < 0.5)
    {
        FlowAgentOutputs deadOut;
        deadOut.xyz  = xyz;
        deadOut.vel  = vel;
        deadOut.rgba = rgba;
        deadOut.baseColor = flow_keptBaseColor(base);
        return deadOut;
    }

    // Sample input texture at current position for flow direction (texel fetch).
    // fieldActive > 0.5: the independent heightTex surface drives direction
    // (reference flow/glsl/agent.glsl).
    uint tw, th;
    if (fieldActive > 0.5) { heightTex.GetDimensions(tw, th); }
    else { inputTex.GetDimensions(tw, th); }
    int2 texSize = int2((int)tw, (int)th);
    int2 texCoord = int2((int)(px * (float)texSize.x), (int)(py * (float)texSize.y));
    texCoord = clamp(texCoord, int2(0, 0), texSize - int2(1, 1));
    float4 texel = fieldActive > 0.5 ? heightTex.Load(int3(texCoord, 0)) : inputTex.Load(int3(texCoord, 0));
    float inputLuma = flow_oklab_l(texel.rgb);

    // inputWeight controls how much the input texture biases the flow direction.
    float weightBlend = clamp(inputWeight * 0.01, 0.0, 1.0);
    float indexValue = lerp(0.5, inputLuma, weightBlend);

    // Rotation bias based on behavior.
    float baseHeading = flow_hash(0u) * FLOW_TAU;
    int behaviorMode = behavior;                 // i32(u.behavior); int uniform == exact
    int totalAgents = stateSize.x * stateSize.y;
    int agentIndex = coord.x + coord.y * stateSize.x;
    float rotationBias = flow_computeRotationBias(behaviorMode, baseHeading, rotRand, time, agentIndex, totalAgents);

    // Final heading from input texture * kink, plus rotation bias.
    float finalAngle = indexValue * FLOW_TAU * kink + rotationBias;

    if (quantize > 0.5)
    {
        finalAngle = round(finalAngle);
    }

    // WGSL u.resolution is the canvas size even while this pass draws into the
    // smaller state texture. The backend's _NM_Resolution is target-sized.
    float2 screenSize = _NM_ScreenResolution.xy;
    float scale = max(max(screenSize.x, screenSize.y) / 1024.0, 1.0);
    float devFactor = 1.0 + strideRand * 2.0 * strideDeviation;
    float actualStride = max(0.0001, (stride * 0.1) * scale * devFactor / max(screenSize.x, screenSize.y));

    // Move agent.
    float newX = px + sin(finalAngle) * actualStride;
    float newY = py + cos(finalAngle) * actualStride;

    // Wrap position to [0,1].
    newX = frac(newX);
    newY = frac(newY);

    // Output updated state (attrition is handled by pointsEmit).
    FlowAgentOutputs o;
    o.xyz  = float4(newX, newY, pz, 1.0);
    o.vel  = float4(0.0, 0.0, rotRand, strideRand);
    o.rgba = diffuseActive > 0.5 ? flow_selectedDiffuse(o.xyz.xy) : base;
    o.baseColor = flow_keptBaseColor(base);
    return o;
}

// =============================================================================
// PASS: passthrough — copy input -> output for 2D-chain continuity (frag_passthrough)
// =============================================================================
float4 frag_passthrough(NMVaryings i) : SV_Target
{
    // WGSL: uv = fragCoord.xy / u.resolution; here NM_FragCoord(i)/resolution.
    // Both equal i.uv (NM_FragCoord = uv*resolution), but we reproduce the
    // reference's divide-by-resolution form for clarity/parity.
    float2 uv = NM_FragCoord(i) / resolution;
    return inputTex.SampleLevel(sampler_inputTex, uv, 0.0);
}

#endif // NM_EFFECT_FLOW_INCLUDED
