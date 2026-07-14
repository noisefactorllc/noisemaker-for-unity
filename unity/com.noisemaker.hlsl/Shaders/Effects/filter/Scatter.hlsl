#ifndef NM_SCATTER_INCLUDED
#define NM_SCATTER_INCLUDED

// filter/scatter — rgba8 jitter intermediate plus 3x3 tent smoothing.
#include "../../Include/NMFullscreen.hlsl"

int MODE;
float radius;
float smoothness;
float seed;

float2 nm_scatter_hash22(float2 p)
{
    float3 p3 = frac(p.xyx * float3(0.1031, 0.1030, 0.0973));
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.xx + p3.yz) * p3.zy);
}

float nm_scatter_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float2 nm_scatter_lum_gradient(Texture2D tex, SamplerState ss, float2 uv)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 px = 1.0 / float2(tw, th);
    float tl = nm_scatter_lum(tex.Sample(ss, uv + px * float2(-1.0,  1.0)).rgb);
    float l  = nm_scatter_lum(tex.Sample(ss, uv + px * float2(-1.0,  0.0)).rgb);
    float bl = nm_scatter_lum(tex.Sample(ss, uv + px * float2(-1.0, -1.0)).rgb);
    float tr = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 1.0,  1.0)).rgb);
    float r  = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 1.0,  0.0)).rgb);
    float br = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 1.0, -1.0)).rgb);
    float t  = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 0.0,  1.0)).rgb);
    float b  = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 0.0, -1.0)).rgb);
    return float2(tr + 2.0 * r + br - tl - 2.0 * l - bl,
                  tl + 2.0 * t + tr - bl - 2.0 * b - br);
}

float4 nm_scatter_jitter(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    pos = floor(pos) + 0.5;
    float2 texSize = float2(tw, th);
    float2 uv = pos / texSize;
    float2 globalCoord = pos + tileOffset;
    float2 hashCoord = globalCoord;
    if (MODE == 4) hashCoord = floor(globalCoord / 3.0) * 3.0;

    float2 rnd = nm_scatter_hash22(hashCoord + (float)(int)seed * 101.7) - 0.5;
    float2 offset = rnd * 2.0 * radius;

    if (MODE == 3)
    {
        float2 grad = nm_scatter_lum_gradient(tex, ss, uv);
        float gradLen = length(grad);
        if (gradLen > 1e-5)
        {
            float2 perp = float2(-grad.y, grad.x) / gradLen;
            offset = dot(offset, perp) * perp;
        }
    }

    float2 sampleUV = clamp((pos + offset) / texSize, 0.0, 1.0);
    float4 src = tex.Sample(ss, uv);
    float4 samp = tex.Sample(ss, sampleUV);
    float4 result = samp;
    if (MODE == 1) result = min(src, samp);
    else if (MODE == 2) result = max(src, samp);
    return result;
}

float4 nm_scatter_smooth(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 uv = pos / texSize;
    float2 texel = 1.0 / texSize;
    float4 src = tex.Sample(ss, uv);

    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    float wsum = 0.0;
    [unroll]
    for (int y = -1; y <= 1; y++)
    {
        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            float w = (2.0 - abs((float)x)) * (2.0 - abs((float)y));
            sum += tex.Sample(ss, uv + float2((float)x, (float)y) * texel) * w;
            wsum += w;
        }
    }
    float4 blurred = sum / wsum;
    return lerp(src, blurred, clamp(smoothness / 100.0, 0.0, 1.0));
}

#endif
