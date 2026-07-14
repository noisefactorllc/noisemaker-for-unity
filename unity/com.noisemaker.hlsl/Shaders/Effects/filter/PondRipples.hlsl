#ifndef NM_POND_RIPPLES_INCLUDED
#define NM_POND_RIPPLES_INCLUDED

// filter/pondRipples — canonical tile-aware concentric-distortion WGSL port.
#include "../../Include/NMFullscreen.hlsl"

int STYLE;
int WRAP;
float amount;
float ridges;
float antialias;

static const float NM_POND_RIPPLES_PI = 3.14159265359;

float4 nm_pond_ripples(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 fullDims = texSize;
    if (fullResolution.x > 0.0) fullDims = fullResolution;
    bool isTile = length(tileOffset) > 0.0;
    float aspect = fullDims.x / fullDims.y;
    float2 globalCoord = pos + tileOffset;
    float2 uv = globalCoord / fullDims;

    uv = uv - 0.5;
    uv.x = uv.x * aspect;
    float r = length(uv);
    float phase = r * (float)(int)ridges * 2.0 * NM_POND_RIPPLES_PI;
    float damping = max(0.0, 1.0 - r);
    float w;
    if (amount <= 30.0)
    {
        w = sin(phase) * (amount / 100.0) * 0.05 * damping;
    }
    else
    {
        float x = (amount - 30.0) / 70.0;
        float amountGain = 0.3 + 0.7 * x + x * x;
        w = sin(phase) * amountGain * 0.05 * damping;
    }

    float rotDelta = 0.0;
    float rDelta = 0.0;
    if (STYLE == 0) rotDelta = w;
    else if (STYLE == 1) rDelta = w;
    else { rotDelta = w * 0.5; rDelta = w * 0.5; }

    float2 dir = float2(0.0, 0.0);
    if (r > 0.0) dir = uv / r;
    float rot = rotDelta * 2.0 * NM_POND_RIPPLES_PI * 0.25;
    float s = sin(rot);
    float co = cos(rot);
    float2 rotatedDir = float2(co * dir.x + s * dir.y, -s * dir.x + co * dir.y);
    uv = rotatedDir * (r + rDelta);
    uv.x = uv.x / aspect;
    uv = uv + 0.5;

    if (WRAP == 0)
    {
        uv = abs(nm_mod(nm_mod(uv + 1.0, float2(2.0, 2.0)) + 2.0, float2(2.0, 2.0)) - 1.0);
    }
    else if (WRAP == 1)
    {
        uv = nm_mod(nm_mod(uv, float2(1.0, 1.0)) + 1.0, float2(1.0, 1.0));
    }
    else
    {
        uv = clamp(uv, float2(0.0, 0.0), float2(1.0, 1.0));
    }

    float2 sampleUV = uv;
    if (isTile)
        sampleUV = clamp((uv * fullDims - tileOffset) / texSize, float2(0.0, 0.0), float2(1.0, 1.0));

    if (antialias != 0.0)
    {
        float2 dx = ddx(sampleUV);
        float2 dy = ddy(sampleUV);
        float4 col = float4(0.0, 0.0, 0.0, 0.0);
        col += tex.Sample(ss, sampleUV + dx * -0.375 + dy * -0.125);
        col += tex.Sample(ss, sampleUV + dx *  0.125 + dy * -0.375);
        col += tex.Sample(ss, sampleUV + dx *  0.375 + dy *  0.125);
        col += tex.Sample(ss, sampleUV + dx * -0.125 + dy *  0.375);
        return col * 0.25;
    }
    return tex.Sample(ss, sampleUV);
}

#endif
