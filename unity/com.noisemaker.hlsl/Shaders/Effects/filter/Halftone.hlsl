#ifndef NM_HALFTONE_INCLUDED
#define NM_HALFTONE_INCLUDED

// filter/halftone — canonical rotated-screen color/mono WGSL port.
#include "../../Include/NMFullscreen.hlsl"

int MODE;
int PATTERN;
float frequency;
float cyanAngle;
float magentaAngle;
float yellowAngle;
float blackAngle;
float monoAngle;
float sharpness;
float3 inkColor;
float3 paperColor;

static const float NM_HALFTONE_DOT_AREA_CAP = 0.50;
static const float NM_HALFTONE_PI = 3.141592653589793;
static const float NM_HALFTONE_MID_DOT_RADIUS = 0.39894228;
static const float NM_HALFTONE_MAX_DOT_RADIUS = 0.48;

float nm_halftone_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float3 nm_halftone_tonemap2(float t, float3 ink, float3 paper)
{
    return lerp(ink, paper, clamp(t, 0.0, 1.0));
}

float4 nm_halftone_rgb_to_cmyk(float3 rgb)
{
    float k = 1.0 - max(max(rgb.r, rgb.g), rgb.b);
    float scale = max(1.0 - k, 0.00001);
    float3 cmy = clamp((1.0 - rgb - float3(k, k, k)) / scale, 0.0, 1.0);
    return float4(cmy, k);
}

float2 nm_halftone_rotate2d(float2 v, float angleDeg)
{
    float a = radians(angleDeg);
    float co = cos(a);
    float si = sin(a);
    return float2(co * v.x + si * v.y, -si * v.x + co * v.y);
}

float3 nm_halftone_box_blur3(
    Texture2D tex, SamplerState ss, float2 uv, float2 texel)
{
    float3 sum = float3(0.0, 0.0, 0.0);
    [unroll]
    for (int y = -1; y <= 1; y++)
    {
        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            float2 o = float2((float)x, (float)y) * texel;
            sum += tex.Sample(ss, clamp(uv + o, 0.0, 1.0)).rgb;
        }
    }
    return sum / 9.0;
}

float3 nm_halftone_cell_sample(
    Texture2D tex, SamplerState ss, float2 ruv, float angleDeg,
    float2 texel, float2 texSize)
{
    float2 cellId = floor(ruv) + 0.5;
    float2 cellCenterGc = nm_halftone_rotate2d(cellId * frequency, -angleDeg);
    float2 cellUV = clamp((cellCenterGc - tileOffset) / texSize, 0.0, 1.0);
    return nm_halftone_box_blur3(tex, ss, cellUV, texel);
}

float nm_halftone_coverage(float d, float value, float sharpnessPct)
{
    float spot = sqrt(clamp(value, 0.0, 1.0)) * 0.7071;
    float softness = 1.0 - clamp(sharpnessPct / 100.0, 0.0, 1.0);
    float aa = max(lerp(fwidth(d) * 1.5, 0.35, softness), 0.00001);
    return 1.0 - smoothstep(spot - aa, spot + aa, d);
}

float nm_halftone_round_dot_coverage(float2 offset, float value, float sharpnessPct)
{
    float inkAmount = clamp(value, 0.0, 1.0);
    float centerDistance = length(offset);
    float inkRadius = sqrt(min(inkAmount, NM_HALFTONE_DOT_AREA_CAP) / NM_HALFTONE_PI);
    if (inkAmount > NM_HALFTONE_DOT_AREA_CAP)
    {
        inkRadius = lerp(NM_HALFTONE_MID_DOT_RADIUS, NM_HALFTONE_MAX_DOT_RADIUS,
            (inkAmount - NM_HALFTONE_DOT_AREA_CAP) / (1.0 - NM_HALFTONE_DOT_AREA_CAP));
    }
    float softness = 1.0 - clamp(sharpnessPct / 100.0, 0.0, 1.0);
    float centerAA = max(lerp(fwidth(centerDistance) * 1.5, 0.35, softness), 0.00001);
    float resolvedInk = smoothstep(0.0, 1.0 / 255.0, value);
    return (1.0 - smoothstep(-centerAA, centerAA, centerDistance - inkRadius)) * resolvedInk;
}

float4 nm_halftone(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 fullSize = texSize;
    if (fullResolution.x > 0.0) fullSize = fullResolution;
    float2 globalCoord = pos + tileOffset;
    float2 uv = pos / texSize;
    float2 texel = 1.0 / texSize;
    float alpha = tex.Sample(ss, uv).a;
    float4 result = float4(0.0, 0.0, 0.0, alpha);

    [branch]
    if (MODE == 0)
    {
        float2 ruvC = nm_halftone_rotate2d(globalCoord, cyanAngle) / frequency;
        float2 ruvM = nm_halftone_rotate2d(globalCoord, magentaAngle) / frequency;
        float2 ruvY = nm_halftone_rotate2d(globalCoord, yellowAngle) / frequency;
        float2 ruvK = nm_halftone_rotate2d(globalCoord, blackAngle) / frequency;
        float valC = nm_halftone_rgb_to_cmyk(nm_halftone_cell_sample(tex, ss, ruvC, cyanAngle, texel, texSize)).r;
        float valM = nm_halftone_rgb_to_cmyk(nm_halftone_cell_sample(tex, ss, ruvM, magentaAngle, texel, texSize)).g;
        float valY = nm_halftone_rgb_to_cmyk(nm_halftone_cell_sample(tex, ss, ruvY, yellowAngle, texel, texSize)).b;
        float valK = nm_halftone_rgb_to_cmyk(nm_halftone_cell_sample(tex, ss, ruvK, blackAngle, texel, texSize)).a;
        float inkC = nm_halftone_round_dot_coverage(frac(ruvC) - 0.5, valC, sharpness);
        float inkM = nm_halftone_round_dot_coverage(frac(ruvM) - 0.5, valM, sharpness);
        float inkY = nm_halftone_round_dot_coverage(frac(ruvY) - 0.5, valY, sharpness);
        float inkK = nm_halftone_round_dot_coverage(frac(ruvK) - 0.5, valK, sharpness);
        float3 screened = (1.0 - float3(inkC, inkM, inkY)) * (1.0 - inkK);
        result = float4(screened, alpha);
    }
    else
    {
        float value = 0.0;
        float d = 0.0;
        float2 dotOffset = float2(0.0, 0.0);
        if (PATTERN == 2)
        {
            float2 center = fullSize * 0.5;
            value = 1.0 - nm_halftone_lum(nm_halftone_box_blur3(tex, ss, uv, texel));
            float rd = length(globalCoord - center) / frequency;
            d = abs(frac(rd) - 0.5);
        }
        else
        {
            float2 ruv = nm_halftone_rotate2d(globalCoord, monoAngle) / frequency;
            value = 1.0 - nm_halftone_lum(
                nm_halftone_cell_sample(tex, ss, ruv, monoAngle, texel, texSize));
            float2 off = frac(ruv) - 0.5;
            dotOffset = off;
            d = PATTERN == 1 ? abs(off.y) : length(off);
        }

        float ink = PATTERN == 0
            ? nm_halftone_round_dot_coverage(dotOffset, value, sharpness)
            : nm_halftone_coverage(d, value, sharpness);
        result = float4(nm_halftone_tonemap2(1.0 - ink, inkColor, paperColor), alpha);
    }
    return result;
}

#endif
