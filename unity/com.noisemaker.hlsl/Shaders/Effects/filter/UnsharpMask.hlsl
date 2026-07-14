#ifndef NM_EFFECT_UNSHARP_MASK_INCLUDED
#define NM_EFFECT_UNSHARP_MASK_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D blurTex;
SamplerState sampler_inputTex;

float amount;
float radius;
float threshold;

float4 nm_unsharp_blur(NMVaryings i, float2 axis)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 uv = NM_FragCoord(i) / texSize;
    float sigma = max(radius * 0.5, 0.001);
    float fTaps = min(radius, 32.0);
    float4 sum = inputTex.Sample(sampler_inputTex, uv);
    float wsum = 1.0;
    [loop]
    for (int tap = 1; tap <= 32; tap++)
    {
        if ((float)tap > fTaps) break;
        float weight = exp(-(float)(tap * tap) / (2.0 * sigma * sigma));
        float2 o = axis * (float)tap / texSize;
        sum += (inputTex.Sample(sampler_inputTex, uv + o) + inputTex.Sample(sampler_inputTex, uv - o)) * weight;
        wsum += 2.0 * weight;
    }
    return sum / wsum;
}

float4 NMFrag_usmBlurH(NMVaryings i) : SV_Target { return nm_unsharp_blur(i, float2(1.0, 0.0)); }
float4 NMFrag_usmBlurV(NMVaryings i) : SV_Target { return nm_unsharp_blur(i, float2(0.0, 1.0)); }

float4 NMFrag_usmCombine(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 uv = NM_FragCoord(i) / float2(w, h);
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float3 diff = src.rgb - blurTex.Sample(sampler_inputTex, uv).rgb;
    float t = threshold / 100.0;
    float mag = max(max(abs(diff.r), abs(diff.g)), abs(diff.b));
    float gate = smoothstep(t, t + 0.02, mag);
    float3 outc = src.rgb + diff * (amount / 100.0) * gate;
    return float4(clamp(outc, 0.0, 1.0), src.a);
}

#endif
