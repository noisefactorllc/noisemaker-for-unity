#ifndef NM_EFFECT_PHOTOCOPY_INCLUDED
#define NM_EFFECT_PHOTOCOPY_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D blurTex;
SamplerState sampler_inputTex;

float detail;
float darkness;
float3 inkColor;
float3 paperColor;

float nm_photocopy_lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

float4 nm_photocopy_blur(NMVaryings i, float2 axis)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 uv = NM_FragCoord(i) / texSize;
    float radius = lerp(1.0, 24.0, (detail - 1.0) / 99.0);
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

float4 NMFrag_pcBlurH(NMVaryings i) : SV_Target { return nm_photocopy_blur(i, float2(1.0, 0.0)); }
float4 NMFrag_pcBlurV(NMVaryings i) : SV_Target { return nm_photocopy_blur(i, float2(0.0, 1.0)); }

float4 NMFrag_pcCombine(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 uv = NM_FragCoord(i) / float2(w, h);
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float4 blurred = blurTex.Sample(sampler_inputTex, uv);
    float lumSrc = nm_photocopy_lum(src.rgb);
    float band = lumSrc - nm_photocopy_lum(blurred.rgb);
    float edgeGain = lerp(4.0, 18.0, darkness / 100.0);
    float edgeInk = clamp(abs(band) * edgeGain, 0.0, 1.0);
    float toneHi = lerp(0.35, 0.68, darkness / 100.0);
    float toneLo = toneHi - 0.26;
    float toneInk = 1.0 - smoothstep(toneLo, toneHi, lumSrc);
    float ink = clamp(max(edgeInk, toneInk), 0.0, 1.0);
    float3 outColor = lerp(inkColor, paperColor, clamp(1.0 - ink, 0.0, 1.0));
    return float4(outColor, src.a);
}

#endif
