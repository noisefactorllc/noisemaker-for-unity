#ifndef NM_EFFECT_RELIEF_INCLUDED
#define NM_EFFECT_RELIEF_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D blurTex;
SamplerState sampler_inputTex;

int MODE;
float smoothness;
float detail;
float lightAngle;
float balance;
float graininess;
float3 inkColor;
float3 paperColor;

float nm_relief_lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

float nm_relief_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float4 nm_relief_blur(NMVaryings i, float2 axis)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 uv = NM_FragCoord(i) / texSize;
    float radius = lerp(0.5, 15.0, smoothness / 100.0);
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

float nm_relief_shade(float hC, float hR, float hT, float strength, float angleDeg)
{
    float2 grad = float2(hR - hC, hT - hC) * strength;
    float3 n = normalize(float3(-grad, 1.0));
    float a = radians(angleDeg);
    float3 L = normalize(float3(cos(a), sin(a), 0.75));
    return clamp(dot(n, L), 0.0, 1.0);
}

float4 NMFrag_rlBlurH(NMVaryings i) : SV_Target { return nm_relief_blur(i, float2(1.0, 0.0)); }
float4 NMFrag_rlBlurV(NMVaryings i) : SV_Target { return nm_relief_blur(i, float2(0.0, 1.0)); }

float4 NMFrag_rlShade(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 pos = NM_FragCoord(i);
    float2 uv = pos / texSize;
    float2 texel = 1.0 / texSize;
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float hC = nm_relief_lum(blurTex.Sample(sampler_inputTex, uv).rgb);
    float hR = nm_relief_lum(blurTex.Sample(sampler_inputTex, uv + float2(texel.x, 0.0)).rgb);
    float hT = nm_relief_lum(blurTex.Sample(sampler_inputTex, uv + float2(0.0, texel.y)).rgb);
    float strength = detail * 0.2;
    float3 outColor;
    if (MODE == 1)
    {
        float hhC = 1.0 - smoothstep(0.35, 0.65, hC);
        float hhR = 1.0 - smoothstep(0.35, 0.65, hR);
        float hhT = 1.0 - smoothstep(0.35, 0.65, hT);
        float shade = nm_relief_shade(hhC, hhR, hhT, strength, lightAngle);
        float glossy = pow(shade, 2.0);
        outColor = lerp(inkColor, paperColor, clamp(lerp(hhC, glossy, 0.75), 0.0, 1.0));
    }
    else if (MODE == 2)
    {
        float threshold = balance / 100.0;
        float m = step(threshold, hC);
        float3 sheet = lerp(inkColor * 0.9 + 0.1, paperColor, m);
        float shade = nm_relief_shade(hC, hR, hT, strength, lightAngle);
        float gradMag = length(float2(hR - hC, hT - hC));
        float bandHeight = max(gradMag * 2.0, 1e-5);
        float edge = 1.0 - smoothstep(0.0, bandHeight, abs(hC - threshold));
        float3 beveled = clamp(sheet * lerp(0.6, 1.4, shade), 0.0, 1.0);
        float3 sheetOut = lerp(sheet, beveled, edge);
        float2 globalCoord = pos + tileOffset;
        float grain = (nm_relief_hash12(floor(globalCoord)) - 0.5) * (graininess / 100.0) * 0.15;
        outColor = clamp(sheetOut + grain.xxx, 0.0, 1.0);
    }
    else
    {
        float shade = nm_relief_shade(hC, hR, hT, strength, lightAngle);
        outColor = lerp(inkColor, paperColor, clamp(lerp(hC, shade, 0.75), 0.0, 1.0));
    }
    return float4(outColor, src.a);
}

#endif
