#ifndef NM_WIND_INCLUDED
#define NM_WIND_INCLUDED

// filter/wind — canonical coherent scanline-integration WGSL port.
#include "../../Include/NMFullscreen.hlsl"

int METHOD;
float direction;
float strength;
float threshold;

static const int NM_WIND_MAX_STEPS = 128;
static const float NM_WIND_STEP_PX = 1.0;
static const float NM_WIND_MAX_REACH = 128.0;

float nm_wind_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float4 nm_wind(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 uv = pos / texSize;
    float2 globalCoord = pos + tileOffset;
    float4 src = tex.Sample(ss, uv);

    float windAmount = clamp(strength / 100.0, 0.0, 1.0);
    if (windAmount <= 0.0) return src;

    float reach = NM_WIND_MAX_REACH * windAmount;
    float marchDir = direction == 0.0 ? -1.0 : 1.0;
    float staggerPhase = 0.0;
    if (METHOD == 2)
        staggerPhase = (0.5 + 0.5 * sin(globalCoord.y * 0.22)) * min(12.0, reach * 0.18);

    float3 accumColor = float3(0.0, 0.0, 0.0);
    float accumWeight = 0.0;
    float baseLum = nm_wind_lum(src.rgb);
    float edge = threshold / 100.0;

    [loop]
    for (int stepIndex = 1; stepIndex <= NM_WIND_MAX_STEPS; stepIndex++)
    {
        float distancePx = (float)stepIndex * NM_WIND_STEP_PX;
        if (distancePx > reach) break;
        float sampleDistance = distancePx + staggerPhase;
        float2 sampleUV = clamp((pos + float2(marchDir * sampleDistance, 0.0)) / texSize,
            float2(0.0, 0.0), float2(1.0, 1.0));
        float3 candidate = tex.Sample(ss, sampleUV).rgb;

        float contrast = nm_wind_lum(candidate) - baseLum - edge;
        float activation = smoothstep(0.0, 0.08, contrast);
        float alongRun = distancePx / max(reach, 1.0);
        float decayRate = 3.4;
        if (METHOD == 1) decayRate = 0.8;
        else if (METHOD == 2) decayRate = 2.0;
        float taperStart = 0.72;
        if (METHOD == 1) taperStart = 0.82;
        float endTaper = 1.0 - smoothstep(taperStart, 1.0, alongRun);
        float weight = activation * exp(-decayRate * alongRun) * endTaper;
        accumColor += candidate * weight;
        accumWeight += weight;
    }

    float3 integrated = accumColor / max(accumWeight, 0.00001);
    float densityRate = 0.16;
    if (METHOD == 1) densityRate = 0.12;
    float streakDensity = 1.0 - exp(-accumWeight * densityRate);
    float methodGain = 0.88;
    if (METHOD == 1) methodGain = 1.0;
    float blendAmount = clamp(streakDensity * windAmount * methodGain, 0.0, 1.0);
    float3 streak = lerp(src.rgb, integrated, blendAmount);
    return float4(max(src.rgb, streak), src.a);
}

#endif
