#ifndef NM_EFFECT_CHROME_INCLUDED
#define NM_EFFECT_CHROME_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D blurTex;
SamplerState sampler_inputTex;

float detail;
float smoothness;
float distortion;

float nm_chrome_lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

float4 nm_chrome_blur(NMVaryings i, float2 axis)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 uv = NM_FragCoord(i) / texSize;
    float radius = lerp(1.0, 16.0, smoothness / 100.0);
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

float4 NMFrag_chBlurH(NMVaryings i) : SV_Target { return nm_chrome_blur(i, float2(1.0, 0.0)); }
float4 NMFrag_chBlurV(NMVaryings i) : SV_Target { return nm_chrome_blur(i, float2(0.0, 1.0)); }

float4 NMFrag_chMap(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 uv = NM_FragCoord(i) / texSize;
    float2 texel = 1.0 / texSize;
    float hL = nm_chrome_lum(blurTex.Sample(sampler_inputTex, uv - float2(texel.x, 0.0)).rgb);
    float hR = nm_chrome_lum(blurTex.Sample(sampler_inputTex, uv + float2(texel.x, 0.0)).rgb);
    float hB = nm_chrome_lum(blurTex.Sample(sampler_inputTex, uv - float2(0.0, texel.y)).rgb);
    float hT = nm_chrome_lum(blurTex.Sample(sampler_inputTex, uv + float2(0.0, texel.y)).rgb);
    float2 grad = float2(hR - hL, hT - hB);
    float2 uv2 = uv + grad * (distortion / 100.0) * 0.5;
    float h2 = nm_chrome_lum(blurTex.Sample(sampler_inputTex, uv2).rgb);
    float cycles = lerp(1.0, 7.0, detail / 100.0);
    float v = 0.5 + 0.5 * sin(h2 * cycles * 6.28318530718 + h2 * 3.0);
    v += pow(v, 8.0) * 0.5;
    v = clamp(v, 0.0, 1.0);
    float3 outColor = clamp(v.xxx * float3(0.96, 0.98, 1.02), 0.0, 1.0);
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    return float4(outColor, src.a);
}

#endif
