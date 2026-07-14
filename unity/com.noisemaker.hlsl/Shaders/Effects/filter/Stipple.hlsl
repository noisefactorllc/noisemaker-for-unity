#ifndef NM_STIPPLE_INCLUDED
#define NM_STIPPLE_INCLUDED

// filter/stipple — canonical pointillize/mezzotint/reticulation WGSL port.
#include "../../Include/NMFullscreen.hlsl"

int MODE;
float cellSize;
float grainSize;
float density;
float3 paperColor;
float seed;

float nm_stipple_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.x + p3.y) * p3.z);
}

float2 nm_stipple_hash22(float2 p)
{
    float3 p3 = frac(p.xyx * float3(0.1031, 0.1030, 0.0973));
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.xx + p3.yz) * p3.zy);
}

float nm_stipple_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float nm_stipple_vnoise(float2 p)
{
    float2 ip = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(
        lerp(nm_stipple_hash12(ip), nm_stipple_hash12(ip + float2(1.0, 0.0)), u.x),
        lerp(nm_stipple_hash12(ip + float2(0.0, 1.0)), nm_stipple_hash12(ip + float2(1.0, 1.0)), u.x),
        u.y);
}

float nm_stipple_fbm(float2 p)
{
    float v = 0.0;
    float a = 0.5;
    [unroll]
    for (int octave = 0; octave < 5; octave++)
    {
        v += a * nm_stipple_vnoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

float4 nm_stipple_voronoi_cell(float2 p, float jitter, float seedVal)
{
    float2 g = floor(p);
    float2 f = p - g;
    float best = 1e9;
    float4 res = float4(0.0, 0.0, 0.0, 0.0);
    [unroll]
    for (int y = -1; y <= 1; y++)
    {
        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            float2 cell = float2((float)x, (float)y);
            float2 pt = cell + 0.5 + (nm_stipple_hash22(g + cell + seedVal * 101.7) - 0.5) * jitter;
            float d = dot(pt - f, pt - f);
            if (d < best)
            {
                best = d;
                res = float4(g + pt, g + cell);
            }
        }
    }
    return res;
}

float3 nm_stipple_tonemap2(float t, float3 ink, float3 paper)
{
    return lerp(ink, paper, clamp(t, 0.0, 1.0));
}

float2 nm_stipple_rotate2d(float2 v, float angleDeg)
{
    float a = radians(angleDeg);
    float co = cos(a);
    float si = sin(a);
    return float2(co * v.x + si * v.y, -si * v.x + co * v.y);
}

float4 nm_stipple(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 globalCoord = pos + tileOffset;
    float2 uv = pos / texSize;
    float alpha = tex.Sample(ss, uv).a;
    float3 result;

    [branch]
    if (MODE == 0)
    {
        float2 p = globalCoord / cellSize;
        float4 cell = nm_stipple_voronoi_cell(p, 0.9, seed);
        float2 seedGc = cell.xy * cellSize;
        float2 seedUV = clamp((seedGc - tileOffset) / texSize, float2(0.0, 0.0), float2(1.0, 1.0));
        float3 seedColor = tex.Sample(ss, seedUV).rgb;
        float radius = 0.35 + 0.4 * (1.0 - nm_stipple_lum(seedColor));
        float d = length(p - cell.xy);
        float aa = max(fwidth(d) * 1.5, 0.00001);
        float inside = 1.0 - smoothstep(radius - aa, radius + aa, d);
        result = lerp(paperColor, seedColor, inside);
    }
    else if (MODE == 1 || MODE == 2 || MODE == 3)
    {
        float2 gc = globalCoord;
        if (MODE == 3) gc = nm_stipple_rotate2d(gc, 45.0);
        float2 noiseP;
        if (MODE == 1) noiseP = gc / grainSize;
        else noiseP = gc * float2(1.0 / grainSize, 1.0 / (grainSize * 8.0));
        float n = nm_stipple_vnoise(noiseP + seed * 101.7);
        n = n + (density - 50.0) / 100.0;
        float3 src = tex.Sample(ss, uv).rgb;
        result = float3(step(n, src.r), step(n, src.g), step(n, src.b));
    }
    else
    {
        float3 src = tex.Sample(ss, uv).rgb;
        float l = nm_stipple_lum(src);
        float clumpNoise = nm_stipple_fbm(globalCoord / (grainSize * 4.0) + seed * 101.7) * lerp(1.2, 0.6, l);
        clumpNoise = clumpNoise + (density - 50.0) / 100.0;
        result = nm_stipple_tonemap2(step(clumpNoise, l), float3(0.05, 0.05, 0.05), float3(0.97, 0.97, 0.97));
    }

    return float4(result, alpha);
}

#endif
