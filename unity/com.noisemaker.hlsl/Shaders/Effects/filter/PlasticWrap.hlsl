#ifndef NM_EFFECT_PLASTIC_WRAP_INCLUDED
#define NM_EFFECT_PLASTIC_WRAP_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D blurTex;
SamplerState sampler_inputTex;

float highlight;
float detail;
float smoothness;
float3 lightDirection;

float nm_plastic_lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

float4 nm_plastic_blur(NMVaryings i, float2 axis)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 uv = NM_FragCoord(i) / texSize;
    float radius = lerp(12.0, 2.0, detail / 100.0);
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

float4 NMFrag_pwBlurH(NMVaryings i) : SV_Target { return nm_plastic_blur(i, float2(1.0, 0.0)); }
float4 NMFrag_pwBlurV(NMVaryings i) : SV_Target { return nm_plastic_blur(i, float2(0.0, 1.0)); }

float4 NMFrag_pwSpec(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 uv = NM_FragCoord(i) / texSize;
    float2 texel = 1.0 / texSize;
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float hC = nm_plastic_lum(blurTex.Sample(sampler_inputTex, uv).rgb);
    float hL = nm_plastic_lum(blurTex.Sample(sampler_inputTex, uv - float2(texel.x, 0.0)).rgb);
    float hR = nm_plastic_lum(blurTex.Sample(sampler_inputTex, uv + float2(texel.x, 0.0)).rgb);
    float hB = nm_plastic_lum(blurTex.Sample(sampler_inputTex, uv - float2(0.0, texel.y)).rgb);
    float hT = nm_plastic_lum(blurTex.Sample(sampler_inputTex, uv + float2(0.0, texel.y)).rgb);
    float2 grad = float2(hR - hL, hT - hB);
    float strength = 10.0;
    float3 n = normalize(float3(-grad * strength, 1.0));
    float lightLengthSq = dot(lightDirection, lightDirection);
    float3 operatorLight = lightLengthSq > 0.000001 ? lightDirection : float3(-0.4, 0.6, 0.7);
    float3 controlledLight = float3(-operatorLight.xy, operatorLight.z);
    float3 L = normalize(controlledLight);
    float3 V = float3(0.0, 0.0, 1.0);
    float3 halfVector = L + V;
    float halfLengthSq = dot(halfVector, halfVector);
    float3 defaultL = normalize(float3(0.4, -0.6, 0.7));
    float3 H = normalize(defaultL + V);
    if (halfLengthSq > 0.000001) H = normalize(halfVector);
    float gloss = lerp(24.0, 6.0, smoothness / 100.0);
    float flatSpec = pow(H.z, gloss);
    float rawSpec = pow(clamp(dot(n, H), 0.0, 1.0), gloss);
    float spec = clamp((rawSpec - flatSpec) / max(1.0 - flatSpec, 0.0001), 0.0, 1.0);
    float curv = 4.0 * hC - hL - hR - hB - hT;
    float ridge = clamp(curv * strength * 2.0, 0.0, 1.0);
    spec = clamp(spec * 1.35 + ridge * 0.75, 0.0, 1.0);
    float3 specColor = clamp(spec.xxx * (highlight / 100.0), 0.0, 1.0);
    float3 outc = 1.0 - (1.0 - src.rgb) * (1.0 - specColor);
    return float4(outc, src.a);
}

#endif
