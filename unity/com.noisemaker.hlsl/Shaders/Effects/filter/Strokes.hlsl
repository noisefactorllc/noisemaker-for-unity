#ifndef NM_EFFECT_STROKES_INCLUDED
#define NM_EFFECT_STROKES_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D smearTex;
SamplerState sampler_inputTex;

int MODE;
float strokeLength;
float balance;
float intensity;
float sharpness;

static const int NM_STROKES_MAX_TAPS = 24;

float nm_strokes_hash12(float2 p)
{
    precise float3 p3 = frac(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    precise float result = frac((p3.x + p3.y) * p3.z);
    return result;
}

float nm_strokes_valueNoise2(float2 p)
{
    float2 cell = floor(p);
    float2 f = frac(p);
    precise float2 u = f * f * (3.0 - 2.0 * f);
    precise float result = lerp(lerp(nm_strokes_hash12(cell), nm_strokes_hash12(cell + float2(1.0, 0.0)), u.x),
                                lerp(nm_strokes_hash12(cell + float2(0.0, 1.0)), nm_strokes_hash12(cell + 1.0), u.x), u.y);
    return result;
}

float2 nm_strokes_hash22(float2 p)
{
    precise float3 p3 = frac(p.xyx * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    precise float2 result = frac((p3.xx + p3.yz) * p3.zy);
    return result;
}

float nm_strokes_lum(float3 c) { precise float result = dot(c, float3(0.2126, 0.7152, 0.0722)); return result; }

float4 nm_strokes_srcSample(float2 sampleUV)
{
    if (MODE == 3)
    {
        uint w, h;
        inputTex.GetDimensions(w, h);
        float2 px = 1.0 / float2(w, h);
        float4 s = inputTex.SampleLevel(sampler_inputTex, sampleUV, 0.0);
        float3 e = s.rgb;
        e = min(e, inputTex.SampleLevel(sampler_inputTex, sampleUV + float2(px.x, 0.0), 0.0).rgb);
        e = min(e, inputTex.SampleLevel(sampler_inputTex, sampleUV - float2(px.x, 0.0), 0.0).rgb);
        e = min(e, inputTex.SampleLevel(sampler_inputTex, sampleUV + float2(0.0, px.y), 0.0).rgb);
        e = min(e, inputTex.SampleLevel(sampler_inputTex, sampleUV - float2(0.0, px.y), 0.0).rgb);
        return float4(e, s.a);
    }
    return inputTex.SampleLevel(sampler_inputTex, sampleUV, 0.0);
}

float2 nm_strokes_lumGradient(float2 uv)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 px = 1.0 / float2(w, h);
    float tl = nm_strokes_lum(inputTex.SampleLevel(sampler_inputTex, uv + px * float2(-1.0,  1.0), 0.0).rgb);
    float l  = nm_strokes_lum(inputTex.SampleLevel(sampler_inputTex, uv + px * float2(-1.0,  0.0), 0.0).rgb);
    float bl = nm_strokes_lum(inputTex.SampleLevel(sampler_inputTex, uv + px * float2(-1.0, -1.0), 0.0).rgb);
    float tr = nm_strokes_lum(inputTex.SampleLevel(sampler_inputTex, uv + px * float2( 1.0,  1.0), 0.0).rgb);
    float r  = nm_strokes_lum(inputTex.SampleLevel(sampler_inputTex, uv + px * float2( 1.0,  0.0), 0.0).rgb);
    float br = nm_strokes_lum(inputTex.SampleLevel(sampler_inputTex, uv + px * float2( 1.0, -1.0), 0.0).rgb);
    float t  = nm_strokes_lum(inputTex.SampleLevel(sampler_inputTex, uv + px * float2( 0.0,  1.0), 0.0).rgb);
    float b  = nm_strokes_lum(inputTex.SampleLevel(sampler_inputTex, uv + px * float2( 0.0, -1.0), 0.0).rgb);
    precise float2 result = float2(tr + 2.0 * r + br - tl - 2.0 * l - bl,
                                   tl + 2.0 * t + tr - bl - 2.0 * b - br);
    return result;
}

float2 nm_strokes_rotate2D(float2 v, float angleDeg)
{
    float a = radians(angleDeg);
    float co = cos(a);
    float si = sin(a);
    precise float2 result = float2(co * v.x + si * v.y, -si * v.x + co * v.y);
    return result;
}

float nm_strokes_variation(float2 gc, float2 dirUnit, float runBase)
{
    float2 across = float2(-dirUnit.y, dirUnit.x);
    float2 strokeSpace = float2(dot(gc, dirUnit) / max(runBase, 3.0), dot(gc, across) / 3.5);
    precise float result = 0.72 + 0.56 * nm_strokes_valueNoise2(strokeSpace * 0.65);
    return result;
}

float4 nm_strokes_brushField(float2 uv, float2 gc, float2 dirUnit, float runBase)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 across = float2(-dirUnit.y, dirUnit.x);
    float2 oriented = float2(dot(gc, dirUnit), dot(gc, across));
    float2 spacing = float2(max(runBase * 0.70, 4.0), 4.5);
    float2 baseCell = floor(oriented / spacing);
    float field = 0.0;
    precise float3 pigmentSum = 0.0;
    precise float pigmentWeight = 0.0;
    [unroll]
    for (int cy = -1; cy <= 1; cy++)
    {
        [unroll]
        for (int cx = -1; cx <= 1; cx++)
        {
            float2 cell = baseCell + float2(cx, cy);
            float2 jitter = nm_strokes_hash22(cell + 17.3) - 0.5;
            float2 center = (cell + 0.5 + jitter * float2(0.56, 0.40)) * spacing;
            float2 delta = oriented - center;
            float angle = (nm_strokes_hash12(cell + 29.1) - 0.5) * 0.34;
            float co = cos(angle);
            float si = sin(angle);
            float2 local = float2(co * delta.x + si * delta.y, -si * delta.x + co * delta.y);
            float halfLength = runBase * (0.35 + 0.18 * nm_strokes_hash12(cell + 43.7));
            float halfWidth = 1.4 + 1.2 * nm_strokes_hash12(cell + 71.9);
            float capsule = length(float2(max(abs(local.x) - halfLength, 0.0), local.y)) - halfWidth;
            float body = 1.0 - smoothstep(-1.35, 1.35, capsule);
            float bristle = 0.78 + 0.22 * (0.5 + 0.5 * sin(local.y * 5.2 + nm_strokes_hash12(cell + 97.3) * 6.2831853));
            precise float mark = body * bristle;
            float2 centerGlobal = dirUnit * center.x + across * center.y;
            float2 centerUV = uv + (centerGlobal - gc) / float2(w, h);
            pigmentSum += nm_strokes_srcSample(centerUV).rgb * mark;
            pigmentWeight += mark;
            field = max(field, mark);
        }
    }
    float3 pigment = nm_strokes_srcSample(uv).rgb;
    if (pigmentWeight > 0.0001) pigment = pigmentSum / pigmentWeight;
    return float4(pigment, clamp(field, 0.0, 1.0));
}

float2 nm_strokes_sprayJitter(float2 gc, float tap)
{
    float2 p = gc / 7.0;
    return float2(nm_strokes_valueNoise2(p + float2(tap * 0.73, 7.0)),
                  nm_strokes_valueNoise2(p + float2(11.0, tap * 0.79) + 37.1)) - 0.5;
}

float4 nm_strokes_smear(float2 uv, float2 gc, float2 dirUnit, float L, float jitterPx)
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 px = 1.0 / float2(w, h);
    precise float4 sum = nm_strokes_srcSample(uv);
    precise float wsum = 1.0;
    [loop]
    for (int tap = 1; tap <= NM_STROKES_MAX_TAPS; tap++)
    {
        float fi = (float)tap;
        if (fi > L) break;
        precise float weight = exp(-2.0 * fi / L);
        float2 jp = 0.0;
        float2 jn = 0.0;
        if (jitterPx > 0.0)
        {
            jp = nm_strokes_sprayJitter(gc, fi) * jitterPx;
            jn = nm_strokes_sprayJitter(gc + 31.7, -fi) * jitterPx;
        }
        precise float2 sampP = uv + (dirUnit * fi) * px + jp * px;
        precise float2 sampN = uv - (dirUnit * fi) * px + jn * px;
        sum += (nm_strokes_srcSample(sampP) + nm_strokes_srcSample(sampN)) * weight;
        wsum += 2.0 * weight;
    }
    return sum / wsum;
}

float4 nm_strokes_smearColor(float2 uv, float2 gc, float4 src, float runBase)
{
    if (MODE == 0)
    {
        float2 dir45 = nm_strokes_rotate2D(float2(1.0, 0.0), 45.0);
        float2 dir135 = nm_strokes_rotate2D(float2(1.0, 0.0), 135.0);
        float l45 = runBase * nm_strokes_variation(gc, dir45, runBase);
        float l135 = runBase * nm_strokes_variation(gc, dir135, runBase);
        float4 layer45 = nm_strokes_brushField(uv, gc, dir45, runBase);
        float4 layer135 = nm_strokes_brushField(uv, gc, dir135, runBase);
        float4 pigment45 = lerp(nm_strokes_smear(uv, gc, dir45, l45, 0.0), float4(layer45.rgb, src.a), 0.72);
        float4 pigment135 = lerp(nm_strokes_smear(uv, gc, dir135, l135, 0.0), float4(layer135.rgb, src.a), 0.72);
        float4 field45 = lerp(src, pigment45, layer45.a);
        float4 field135 = lerp(src, pigment135, layer135.a);
        float b = balance / 100.0;
        float side = smoothstep(b - 0.1, b + 0.1, nm_strokes_lum(src.rgb));
        return lerp(field135, field45, side);
    }
    if (MODE == 1)
    {
        float2 dir45 = nm_strokes_rotate2D(float2(1.0, 0.0), 45.0);
        float L = runBase * nm_strokes_variation(gc, dir45, runBase);
        float jitterPx = intensity / 100.0 * 6.0;
        float4 layer = nm_strokes_brushField(uv, gc, dir45, runBase);
        float4 pigment = lerp(nm_strokes_smear(uv, gc, dir45, L, jitterPx), float4(layer.rgb, src.a), 0.68);
        return lerp(src, pigment, layer.a);
    }
    if (MODE == 2)
    {
        float2 dir45 = nm_strokes_rotate2D(float2(1.0, 0.0), 45.0);
        float L = runBase * nm_strokes_variation(gc, dir45, runBase);
        float4 layer = nm_strokes_brushField(uv, gc, dir45, runBase);
        float4 pigment = lerp(nm_strokes_smear(uv, gc, dir45, L, 0.0), float4(layer.rgb, src.a), 0.72);
        float4 c = lerp(src, pigment, layer.a);
        float exponent = nm_strokes_lum(c.rgb) < balance / 100.0 ? 1.0 + intensity / 50.0 : 1.0 / (1.0 + intensity / 100.0);
        return float4(pow(max(c.rgb, 0.0), exponent.xxx), c.a);
    }
    if (MODE == 3)
    {
        float2 dir135 = nm_strokes_rotate2D(float2(1.0, 0.0), 135.0);
        float L = runBase * nm_strokes_variation(gc, dir135, runBase);
        float4 layer = nm_strokes_brushField(uv, gc, dir135, runBase);
        float4 pigment = lerp(nm_strokes_smear(uv, gc, dir135, L, 0.0), float4(layer.rgb, src.a), 0.74);
        float4 c = lerp(src, pigment, layer.a);
        float exponent = 1.0 + intensity / 50.0;
        return float4(pow(max(c.rgb, 0.0), exponent.xxx), c.a);
    }
    float2 grad = nm_strokes_lumGradient(uv);
    float gradMag = length(grad);
    float edgeAngle = gradMag > 1e-5 ? degrees(atan2(grad.y, grad.x)) + 90.0 : 45.0;
    float2 dir = nm_strokes_rotate2D(float2(1.0, 0.0), edgeAngle);
    float L = runBase * nm_strokes_variation(gc, dir, runBase);
    float4 layer = nm_strokes_brushField(uv, gc, dir, runBase);
    float4 pigment = lerp(nm_strokes_smear(uv, gc, dir, L, 0.0), float4(layer.rgb, src.a), 0.64);
    float4 smeared = lerp(src, pigment, layer.a);
    float shadowMask = 1.0 - smoothstep(0.55, 0.65, nm_strokes_lum(src.rgb));
    return lerp(src, smeared, shadowMask);
}

float3 nm_strokes_tent3x3(float2 uv)
{
    uint w, h;
    smearTex.GetDimensions(w, h);
    float2 px = 1.0 / float2(w, h);
    float3 sum = 0.0;
    float wsum = 0.0;
    [unroll]
    for (int dy = -1; dy <= 1; dy++)
    {
        [unroll]
        for (int dx = -1; dx <= 1; dx++)
        {
            float weight = (dx == 0 ? 2.0 : 1.0) * (dy == 0 ? 2.0 : 1.0);
            sum += smearTex.Sample(sampler_inputTex, uv + float2(dx, dy) * px).rgb * weight;
            wsum += weight;
        }
    }
    return sum / wsum;
}

float4 NMFrag_stkSmear(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    // Match WGSL @builtin(position)'s exact half-pixel center for both the
    // procedural global coordinate and point-sampled source UV.
    float2 pos = floor(NM_FragCoord(i)) + 0.5;
    float2 uv = pos / float2(w, h);
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float2 gc = pos + tileOffset;
    float runBase = lerp(3.0, 50.0, strokeLength / 100.0);
    float4 outc = nm_strokes_smearColor(uv, gc, src, runBase);
    return float4(clamp(outc.rgb, 0.0, 1.0), src.a);
}

float4 NMFrag_stkPost(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 pos = floor(NM_FragCoord(i)) + 0.5;
    float2 uv = pos / float2(w, h);
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float3 c = smearTex.Sample(sampler_inputTex, uv).rgb;
    float3 tent = nm_strokes_tent3x3(uv);
    float3 sharpened = c + (c - tent) * (sharpness / 33.0);
    return float4(clamp(sharpened, 0.0, 1.0), src.a);
}

#endif
