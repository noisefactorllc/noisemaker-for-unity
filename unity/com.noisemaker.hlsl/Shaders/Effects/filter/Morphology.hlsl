#ifndef NM_MORPHOLOGY_INCLUDED
#define NM_MORPHOLOGY_INCLUDED

// filter/morphology — separable square and bounded nonseparable disc paths.
#include "../../Include/NMFullscreen.hlsl"

int SHAPE;
float mode;
float radius;

float4 nm_morphology_select(float4 hi, float4 lo)
{
    return mode != 0.0 ? lo : hi;
}

float4 nm_morphology_a(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 uv = pos / texSize;
    float2 texel = 1.0 / texSize;
    float4 acc = tex.Sample(ss, uv);

    [branch]
    if (SHAPE == 1)
    {
        float r = min(radius, 12.0);
        float r2 = r * r;
        [loop]
        for (int y = -12; y <= 12; y++)
        {
            [loop]
            for (int x = -12; x <= 12; x++)
            {
                if (x == 0 && y == 0) continue;
                float2 d = float2((float)x, (float)y);
                if (dot(d, d) > r2) continue;
                float4 s = tex.Sample(ss, uv + d * texel);
                acc = nm_morphology_select(max(acc, s), min(acc, s));
            }
        }
    }
    else
    {
        float r = min(radius, 32.0);
        [loop]
        for (int i = 1; i <= 32; i++)
        {
            if ((float)i > r) break;
            float2 o = float2((float)i, 0.0) * texel;
            float4 sL = tex.Sample(ss, uv - o);
            float4 sR = tex.Sample(ss, uv + o);
            acc = nm_morphology_select(max(acc, max(sL, sR)), min(acc, min(sL, sR)));
        }
    }
    return acc;
}

float4 nm_morphology_b(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 uv = pos / texSize;
    float4 acc = tex.Sample(ss, uv);

    if (SHAPE == 0)
    {
        float2 texel = 1.0 / texSize;
        float r = min(radius, 32.0);
        [loop]
        for (int i = 1; i <= 32; i++)
        {
            if ((float)i > r) break;
            float2 o = float2(0.0, (float)i) * texel;
            float4 sD = tex.Sample(ss, uv - o);
            float4 sU = tex.Sample(ss, uv + o);
            acc = nm_morphology_select(max(acc, max(sD, sU)), min(acc, min(sD, sU)));
        }
    }
    return acc;
}

#endif
