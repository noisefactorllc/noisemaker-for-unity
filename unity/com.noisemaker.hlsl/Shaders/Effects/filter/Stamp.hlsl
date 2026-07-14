#ifndef NM_EFFECT_STAMP_INCLUDED
#define NM_EFFECT_STAMP_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D blurTex;
SamplerState sampler_inputTex;

float smoothness;
float balance;
float roughness;
float3 inkColor;
float3 paperColor;

float nm_stamp_lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

float nm_stamp_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float nm_stamp_vnoise(float2 p)
{
    float2 cell = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(nm_stamp_hash12(cell), nm_stamp_hash12(cell + float2(1.0, 0.0)), u.x),
                lerp(nm_stamp_hash12(cell + float2(0.0, 1.0)), nm_stamp_hash12(cell + float2(1.0, 1.0)), u.x), u.y);
}

float nm_stamp_fbm(float2 p)
{
    float v = 0.0;
    float a = 0.5;
    [unroll]
    for (int octave = 0; octave < 5; octave++)
    {
        v += a * nm_stamp_vnoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

float4 nm_stamp_blur(NMVaryings i, float2 axis)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 uv = NM_FragCoord(i) / texSize;
    float radius = lerp(0.5, 20.0, smoothness / 100.0);
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

float4 NMFrag_stBlurH(NMVaryings i) : SV_Target { return nm_stamp_blur(i, float2(1.0, 0.0)); }
float4 NMFrag_stBlurV(NMVaryings i) : SV_Target { return nm_stamp_blur(i, float2(0.0, 1.0)); }

float4 NMFrag_stThreshold(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 texSize = float2(w, h);
    float2 pos = NM_FragCoord(i);
    float2 uv = pos / texSize;
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float4 blurred = blurTex.Sample(sampler_inputTex, uv);
    float2 globalCoord = floor(pos) + tileOffset;
    float grain = (nm_stamp_fbm(globalCoord / 3.0) - 0.5) * (roughness / 100.0) * 0.35;
    float t = nm_stamp_lum(blurred.rgb) + grain;
    float b = balance / 100.0;
    float aa = max(fwidth(t), 0.01) + (roughness / 100.0) * 0.05;
    float m = smoothstep(b - aa, b + aa, t);
    float3 outColor = lerp(inkColor, paperColor, clamp(m, 0.0, 1.0));
    return float4(outColor, src.a);
}

#endif
