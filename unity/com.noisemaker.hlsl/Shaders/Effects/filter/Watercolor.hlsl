#ifndef NM_WATERCOLOR_INCLUDED
#define NM_WATERCOLOR_INCLUDED

// filter/watercolor — seed, repeated 3x3 componentwise median simplify, and
// pigment/paper composite passes ported from the authoritative WGSL programs.
#include "../../Include/NMFullscreen.hlsl"

float detail;
float shadowIntensity;
float paperTexture;

void nm_watercolor_sort2(inout float3 a, inout float3 b)
{
    float3 lo = min(a, b);
    float3 hi = max(a, b);
    a = lo;
    b = hi;
}

float4 nm_watercolor_seed(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    return tex.Sample(ss, pos / float2(tw, th));
}

float4 nm_watercolor_simplify(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float stride = lerp(3.0, 1.0, clamp(detail, 0.0, 100.0) / 100.0);
    float2 texel = stride / texSize;
    float2 uv = pos / texSize;

    float4 s0 = tex.Sample(ss, uv + float2(-texel.x, -texel.y));
    float4 s1 = tex.Sample(ss, uv + float2(0.0, -texel.y));
    float4 s2 = tex.Sample(ss, uv + float2(texel.x, -texel.y));
    float4 s3 = tex.Sample(ss, uv + float2(-texel.x, 0.0));
    float4 s4 = tex.Sample(ss, uv);
    float4 s5 = tex.Sample(ss, uv + float2(texel.x, 0.0));
    float4 s6 = tex.Sample(ss, uv + float2(-texel.x, texel.y));
    float4 s7 = tex.Sample(ss, uv + float2(0.0, texel.y));
    float4 s8 = tex.Sample(ss, uv + float2(texel.x, texel.y));

    float3 p0 = s0.rgb; float3 p1 = s1.rgb; float3 p2 = s2.rgb;
    float3 p3 = s3.rgb; float3 p4 = s4.rgb; float3 p5 = s5.rgb;
    float3 p6 = s6.rgb; float3 p7 = s7.rgb; float3 p8 = s8.rgb;

    nm_watercolor_sort2(p1, p2); nm_watercolor_sort2(p4, p5); nm_watercolor_sort2(p7, p8);
    nm_watercolor_sort2(p0, p1); nm_watercolor_sort2(p3, p4); nm_watercolor_sort2(p6, p7);
    nm_watercolor_sort2(p1, p2); nm_watercolor_sort2(p4, p5); nm_watercolor_sort2(p7, p8);
    nm_watercolor_sort2(p0, p3); nm_watercolor_sort2(p5, p8); nm_watercolor_sort2(p4, p7);
    nm_watercolor_sort2(p3, p6); nm_watercolor_sort2(p1, p4); nm_watercolor_sort2(p2, p5);
    nm_watercolor_sort2(p4, p7); nm_watercolor_sort2(p4, p2); nm_watercolor_sort2(p6, p4);
    nm_watercolor_sort2(p4, p2);

    return float4(p4, s4.a);
}

float nm_watercolor_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.x + p3.y) * p3.z);
}

float nm_watercolor_vnoise(float2 p)
{
    float2 ip = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(
        lerp(nm_watercolor_hash12(ip), nm_watercolor_hash12(ip + float2(1.0, 0.0)), u.x),
        lerp(nm_watercolor_hash12(ip + float2(0.0, 1.0)), nm_watercolor_hash12(ip + float2(1.0, 1.0)), u.x),
        u.y);
}

float nm_watercolor_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float2 nm_watercolor_simplified_gradient(Texture2D tex, SamplerState ss, float2 uv)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 px = 1.0 / float2(tw, th);
    float tl = nm_watercolor_lum(tex.Sample(ss, uv + px * float2(-1.0,  1.0)).rgb);
    float l  = nm_watercolor_lum(tex.Sample(ss, uv + px * float2(-1.0,  0.0)).rgb);
    float bl = nm_watercolor_lum(tex.Sample(ss, uv + px * float2(-1.0, -1.0)).rgb);
    float tr = nm_watercolor_lum(tex.Sample(ss, uv + px * float2( 1.0,  1.0)).rgb);
    float r  = nm_watercolor_lum(tex.Sample(ss, uv + px * float2( 1.0,  0.0)).rgb);
    float br = nm_watercolor_lum(tex.Sample(ss, uv + px * float2( 1.0, -1.0)).rgb);
    float t  = nm_watercolor_lum(tex.Sample(ss, uv + px * float2( 0.0,  1.0)).rgb);
    float b  = nm_watercolor_lum(tex.Sample(ss, uv + px * float2( 0.0, -1.0)).rgb);
    return float2(tr + 2.0 * r + br - tl - 2.0 * l - bl,
                  tl + 2.0 * t + tr - bl - 2.0 * b - br);
}

float4 nm_watercolor_composite(
    Texture2D sourceTex, Texture2D simplifiedTex, SamplerState ss, float2 pos)
{
    uint tw, th;
    sourceTex.GetDimensions(tw, th);
    float2 uv = pos / float2(tw, th);
    float4 src = sourceTex.Sample(ss, uv);
    float3 simplified = simplifiedTex.Sample(ss, uv).rgb;

    float edge = length(nm_watercolor_simplified_gradient(simplifiedTex, ss, uv));
    float pool = shadowIntensity / 100.0 * 0.7 * smoothstep(0.05, 0.4, edge);
    float3 c = simplified * (1.0 - pool);

    float2 gc = floor(pos) + tileOffset;
    c *= lerp(1.0, 0.92 + 0.08 * nm_watercolor_vnoise(gc / 3.5),
        clamp(paperTexture, 0.0, 100.0) / 100.0);
    c = lerp(c, c * float3(1.02, 1.0, 0.95), paperTexture / 100.0);

    float flatness = 1.0 - smoothstep(0.0, 0.15, edge);
    c = lerp(c, float3(nm_watercolor_lum(c), nm_watercolor_lum(c), nm_watercolor_lum(c)), flatness * 0.12);
    c *= 1.0 + flatness * 0.05;

    return float4(clamp(c, 0.0, 1.0), src.a);
}

#endif
