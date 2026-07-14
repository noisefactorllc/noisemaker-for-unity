#ifndef NM_HATCH_INCLUDED
#define NM_HATCH_INCLUDED

// filter/hatch — canonical six-mode WGSL port. Geometry/noise uses global
// top-left pixel coordinates; the source image remains tile-local.
#include "../../Include/NMFullscreen.hlsl"

int MODE;
float strokeLength;
float direction;
float balance;
float pressure;
float3 inkColor;
float3 paperColor;

float nm_hatch_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.x + p3.y) * p3.z);
}

float nm_hatch_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float nm_hatch_vnoise(float2 p)
{
    float2 ip = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(
        lerp(nm_hatch_hash12(ip), nm_hatch_hash12(ip + float2(1.0, 0.0)), u.x),
        lerp(nm_hatch_hash12(ip + float2(0.0, 1.0)), nm_hatch_hash12(ip + float2(1.0, 1.0)), u.x),
        u.y);
}

float nm_hatch_fbm(float2 p)
{
    float v = 0.0;
    float a = 0.5;
    [unroll]
    for (int octave = 0; octave < 5; octave++)
    {
        v += a * nm_hatch_vnoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

float2 nm_hatch_lum_gradient(Texture2D tex, SamplerState ss, float2 uv)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 px = 1.0 / float2(tw, th);
    float tl = nm_hatch_lum(tex.Sample(ss, uv + px * float2(-1.0,  1.0)).rgb);
    float l  = nm_hatch_lum(tex.Sample(ss, uv + px * float2(-1.0,  0.0)).rgb);
    float bl = nm_hatch_lum(tex.Sample(ss, uv + px * float2(-1.0, -1.0)).rgb);
    float tr = nm_hatch_lum(tex.Sample(ss, uv + px * float2( 1.0,  1.0)).rgb);
    float r  = nm_hatch_lum(tex.Sample(ss, uv + px * float2( 1.0,  0.0)).rgb);
    float br = nm_hatch_lum(tex.Sample(ss, uv + px * float2( 1.0, -1.0)).rgb);
    float t  = nm_hatch_lum(tex.Sample(ss, uv + px * float2( 0.0,  1.0)).rgb);
    float b  = nm_hatch_lum(tex.Sample(ss, uv + px * float2( 0.0, -1.0)).rgb);
    return float2(tr + 2.0 * r + br - tl - 2.0 * l - bl,
                  tl + 2.0 * t + tr - bl - 2.0 * b - br);
}

float3 nm_hatch_tonemap2(float t, float3 ink, float3 paper)
{
    return lerp(ink, paper, clamp(t, 0.0, 1.0));
}

float2 nm_hatch_rotate2d(float2 v, float angleDeg)
{
    float a = radians(angleDeg);
    float co = cos(a);
    float si = sin(a);
    return float2(co * v.x + si * v.y, -si * v.x + co * v.y);
}

float nm_hatch_dir_angle(int d)
{
    if (d == 1) return 0.0;
    if (d == 2) return 135.0;
    if (d == 3) return 90.0;
    return 45.0;
}

float nm_hatch_stroke_field(float2 gc, float angleDeg, float stretchAmt)
{
    float2 p = nm_hatch_rotate2d(gc, angleDeg) * float2(1.0 / stretchAmt, 0.9);
    return nm_hatch_vnoise(p);
}

float3 nm_hatch_color(
    Texture2D tex, SamplerState ss, float2 gc, float2 uv, float3 src,
    float theta, float stretchAmt, float tone, float pb, float stroke)
{
    [branch]
    if (MODE == 0)
    {
        float inkMask = step(stroke, clamp(1.0 - tone + pb * 0.3, 0.0, 1.0));
        return nm_hatch_tonemap2(1.0 - inkMask, inkColor, paperColor);
    }
    [branch]
    if (MODE == 1)
    {
        float s2 = nm_hatch_stroke_field(gc * 2.0 + 91.7, theta, stretchAmt * 0.5);
        float rough = stroke * 0.6 + s2 * 0.4;
        float shadow = 1.0 - smoothstep(0.15, 0.55, tone);
        float coverage = clamp(shadow + pb * 0.5, 0.0, 1.0);
        float inkMask = step(1.0 - coverage, rough);
        float darkness = lerp(0.55, 1.0, pressure / 100.0);
        float3 inkC = lerp(paperColor, inkColor, darkness);
        return lerp(paperColor, inkC, inkMask);
    }
    [branch]
    if (MODE == 2)
    {
        float3 midGray = lerp(inkColor, paperColor, 0.5);
        float sBg = nm_hatch_stroke_field(gc, theta + 90.0, stretchAmt);
        float aa = lerp(0.4, 0.04, pressure / 100.0);
        float fgGate = 1.0 - smoothstep(0.4 - aa, 0.4 + aa, tone);
        float fgMask = step(1.0 - fgGate, stroke);
        float bgGate = smoothstep(0.6 - aa, 0.6 + aa, tone);
        float bgMask = step(1.0 - bgGate, sBg);
        float3 outc = midGray;
        outc = lerp(outc, inkColor, fgMask);
        outc = lerp(outc, paperColor, bgMask);
        return outc;
    }
    [branch]
    if (MODE == 3)
    {
        float toneGate = smoothstep(0.3, 0.7, tone);
        float texture2 = lerp(stroke, nm_hatch_fbm(gc / (stretchAmt * 0.6) + 41.0), 0.5);
        float level = lerp(texture2, toneGate, abs(toneGate * 2.0 - 1.0));
        level = clamp(level + pb * 0.15, 0.0, 1.0);
        return nm_hatch_tonemap2(level, inkColor, paperColor);
    }
    [branch]
    if (MODE == 4)
    {
        float s45a = nm_hatch_stroke_field(gc, theta + 45.0, stretchAmt);
        float s45b = nm_hatch_stroke_field(gc, theta - 45.0, stretchAmt);
        float band1 = 1.0 - smoothstep(0.65, 0.85, tone);
        float band2 = 1.0 - smoothstep(0.35, 0.55, tone);
        float band3 = 1.0 - smoothstep(0.05, 0.25, tone);
        float darkGain = lerp(0.25, 1.0, pressure / 100.0);
        float f0 = 1.0 - band1 * darkGain * (1.0 - stroke);
        float f1 = 1.0 - band2 * darkGain * (1.0 - s45a);
        float f2 = 1.0 - band3 * darkGain * (1.0 - s45b);
        return clamp(src * f0 * f1 * f2, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
    }

    float2 grad = nm_hatch_lum_gradient(tex, ss, uv);
    float gradMag = length(grad);
    float edgeAngle = degrees(atan2(grad.y, grad.x)) + 90.0;
    float sEdge = nm_hatch_stroke_field(gc, edgeAngle, stretchAmt);
    float edgeBoost = clamp(gradMag * 3.0, 0.0, 1.0);
    float sCombined = lerp(stroke, sEdge, edgeBoost);
    float coverage = clamp((1.0 - tone) + pb * 0.4, 0.0, 1.0);
    float strokeMask = step(1.0 - coverage, sCombined);
    return lerp(paperColor, src, strokeMask);
}

float4 nm_hatch(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 uv = pos / texSize;
    float4 src = tex.Sample(ss, uv);
    float2 gc = floor(pos) + tileOffset;

    float theta = nm_hatch_dir_angle((int)direction);
    float stretchAmt = lerp(4.0, 40.0, strokeLength / 100.0);
    float tone = nm_hatch_lum(src.rgb) + (balance - 50.0) / 100.0;
    float pb = (pressure - 50.0) / 100.0;
    float stroke = nm_hatch_stroke_field(gc, theta, stretchAmt);
    float3 outColor = nm_hatch_color(tex, ss, gc, uv, src.rgb, theta, stretchAmt, tone, pb, stroke);
    return float4(clamp(outColor, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0)), src.a);
}

#endif
