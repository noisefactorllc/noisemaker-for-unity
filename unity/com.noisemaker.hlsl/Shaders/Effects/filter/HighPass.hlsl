#ifndef NM_EFFECT_HIGH_PASS_INCLUDED
#define NM_EFFECT_HIGH_PASS_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D blurTex;
SamplerState sampler_inputTex;

float radius;
float mono;

float nm_highpass_lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

float4 nm_highpass_blur(NMVaryings i, float2 axis)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    // @builtin(position) is exactly half-pixel centered.  Reconstruct that
    // center before the radius>32 path places odd taps on point-sampling
    // boundaries; an interpolated coordinate can otherwise land one ULP to
    // either side and select the adjacent texel.
    float2 pos = floor(NM_FragCoord(i)) + 0.5;
    float2 uv = pos / texSize;
    float sigma = max(radius * 0.5, 0.001);
    float fTaps = min(radius, 32.0);
    float stride = radius > 32.0 ? radius / 32.0 : 1.0;
    float4 sum = inputTex.Sample(sampler_inputTex, uv);
    float wsum = 1.0;
    [loop]
    for (int tap = 1; tap <= 32; tap++)
    {
        if ((float)tap > fTaps) break;
        float weight = exp(-(float)(tap * tap) / (2.0 * sigma * sigma));
        float2 o = axis * (float)tap * stride / texSize;
        sum += (inputTex.Sample(sampler_inputTex, uv + o) + inputTex.Sample(sampler_inputTex, uv - o)) * weight;
        wsum += 2.0 * weight;
    }
    return sum / wsum;
}

float4 NMFrag_hpBlurH(NMVaryings i) : SV_Target { return nm_highpass_blur(i, float2(1.0, 0.0)); }
float4 NMFrag_hpBlurV(NMVaryings i) : SV_Target { return nm_highpass_blur(i, float2(0.0, 1.0)); }

float4 NMFrag_hpCombine(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 uv = NM_FragCoord(i) / float2(w, h);
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float3 diff = src.rgb - blurTex.Sample(sampler_inputTex, uv).rgb;
    float3 hp = mono != 0.0 ? (nm_highpass_lum(diff) + 0.5).xxx : diff + 0.5;
    return float4(clamp(hp, 0.0, 1.0), src.a);
}

#endif
