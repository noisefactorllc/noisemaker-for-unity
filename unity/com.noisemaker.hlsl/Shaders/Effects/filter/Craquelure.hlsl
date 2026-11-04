#ifndef NM_CRAQUELURE_INCLUDED
#define NM_CRAQUELURE_INCLUDED

// filter/craquelure — global-coordinate Voronoi F1/F2 crack grooves and relief.
#include "../../Include/NMFullscreen.hlsl"

float spacing;
float depth;
float brightness;
float seed;

uint3 nm_craquelure_pcg3d(uint3 v_in)
{
    return nm_pcg(v_in);
}

float nm_craquelure_hash12(int2 p)
{
    return (float)(nm_craquelure_pcg3d(uint3((uint2)p, 0u)).x >> 8u) / 16777216.0;
}

float2 nm_craquelure_hash22(int2 p, int seedVal)
{
    uint2 h = nm_craquelure_pcg3d(uint3((uint2)p, (uint)seedVal)).xy >> uint2(8u, 8u);
    return (float2)h / 16777216.0;
}

float nm_craquelure_vnoise(float2 p)
{
    int2 ip = (int2)floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(
        lerp(nm_craquelure_hash12(ip), nm_craquelure_hash12(ip + int2(1, 0)), u.x),
        lerp(nm_craquelure_hash12(ip + int2(0, 1)), nm_craquelure_hash12(ip + int2(1, 1)), u.x),
        u.y);
}

float2 nm_craquelure_voronoi_f1_f2(float2 p, float jitter, int seedVal)
{
    float2 g = floor(p);
    float2 f = p - g;
    int2 gi = (int2)g;
    float best = 1e9;
    float second = 1e9;
    [unroll]
    for (int y = -1; y <= 1; y++)
    {
        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            float2 cell = float2((float)x, (float)y);
            float2 pt = cell + 0.5 +
                (nm_craquelure_hash22(gi + int2(x, y), seedVal) - 0.5) * jitter;
            float d = dot(pt - f, pt - f);
            if (d < best)
            {
                second = best;
                best = d;
            }
            else if (d < second)
            {
                second = d;
            }
        }
    }
    return float2(sqrt(best), sqrt(second));
}

float nm_craquelure_relief_shade(
    float hC, float hR, float hT, float strength, float lightAngleDeg)
{
    float2 grad = float2(hR - hC, hT - hC) * strength;
    float3 n = normalize(float3(-grad, 1.0));
    float a = radians(lightAngleDeg);
    float3 lightDir = normalize(float3(cos(a), sin(a), 0.75));
    return clamp(dot(n, lightDir), 0.0, 1.0);
}

float nm_craquelure_crack_mask(
    float2 globalCoord, float spacingPx, float depthPct, int seedVal)
{
    float2 wob = float2(
        nm_craquelure_vnoise(globalCoord / 6.0),
        nm_craquelure_vnoise(globalCoord / 6.0 + float2(37.7, 91.3))) * 2.0;
    float2 p = (globalCoord + wob) / spacingPx;
    float2 f1f2 = nm_craquelure_voronoi_f1_f2(p, 1.0, seedVal);
    float d = (f1f2.y - f1f2.x) * spacingPx;
    float edge = 1.5 + depthPct / 100.0 * 2.0;
    return 1.0 - smoothstep(0.0, edge, d);
}

float4 nm_craquelure(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 globalCoord = pos + tileOffset;
    float2 uv = pos / float2(tw, th);
    float4 src = tex.Sample(ss, uv);
    int seedI = (int)seed;

    float kC = nm_craquelure_crack_mask(globalCoord, spacing, depth, seedI);
    float kR = nm_craquelure_crack_mask(globalCoord + float2(1.0, 0.0), spacing, depth, seedI);
    float kL = nm_craquelure_crack_mask(globalCoord - float2(1.0, 0.0), spacing, depth, seedI);
    float kT = nm_craquelure_crack_mask(globalCoord + float2(0.0, 1.0), spacing, depth, seedI);
    float kB = nm_craquelure_crack_mask(globalCoord - float2(0.0, 1.0), spacing, depth, seedI);

    float2 gradK = float2((kR - kL) * 0.5, (kT - kB) * 0.5);
    float hC = -kC;
    float hR = hC - gradK.x;
    float hT = hC - gradK.y;
    float shade = nm_craquelure_relief_shade(hC, hR, hT, 6.0, 135.0);

    float gradMagK = length(gradK);
    float wallMask = smoothstep(0.0, 0.02, gradMagK);
    float shadeMul = 1.0 + (shade - 0.6) * 2.0 * (0.25 * depth / 100.0) * wallMask;
    float3 darkened = src.rgb * lerp(1.0, 0.35 + brightness / 100.0 * 0.5, kC);
    float3 result = clamp(darkened * shadeMul, 0.0, 1.0);
    return float4(result, src.a);
}

#endif
