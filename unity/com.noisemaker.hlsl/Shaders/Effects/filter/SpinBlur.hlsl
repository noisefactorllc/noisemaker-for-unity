#ifndef NM_SPIN_BLUR_INCLUDED
#define NM_SPIN_BLUR_INCLUDED

// filter/spinBlur — canonical global/full-frame rotational blur WGSL port.
#include "../../Include/NMFullscreen.hlsl"

float amount;
float centerX;
float centerY;

static const int NM_SPIN_BLUR_TAPS = 32;

float nm_spin_blur_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.x + p3.y) * p3.z);
}

float2 nm_spin_blur_rotate_around(
    float2 uv, float2 center, float angle, float aspect)
{
    float2 p = uv;
    p.x *= aspect;
    float2 c = center;
    c.x *= aspect;
    p -= c;
    float s = sin(angle);
    float co = cos(angle);
    p = float2(co * p.x - s * p.y, s * p.x + co * p.y);
    p += c;
    p.x /= aspect;
    return p;
}

float4 nm_spin_blur(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    pos = floor(pos) + 0.5;
    float2 texSize = float2(tw, th);
    float2 fullDims = texSize;
    if (fullResolution.x > 0.0) fullDims = fullResolution;
    float aspect = fullDims.x / fullDims.y;
    float2 globalCoord = pos + tileOffset;
    float2 uv = globalCoord / fullDims;
    float2 center = float2(centerX, centerY);

    float arc = radians(amount);
    float angularStep = arc / (float)(NM_SPIN_BLUR_TAPS - 1);
    float2 jitterCoord = float2(
        globalCoord.x, abs(globalCoord.y - fullDims.y * 0.5));
    float jitter = -(nm_spin_blur_hash12(jitterCoord) - 0.5) * angularStep;

    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    [unroll]
    for (int i = 0; i < NM_SPIN_BLUR_TAPS; i++)
    {
        float theta = ((float)i / (float)(NM_SPIN_BLUR_TAPS - 1) - 0.5) * arc + jitter;
        float2 distorted = clamp(
            nm_spin_blur_rotate_around(uv, center, theta, aspect), 0.0, 1.0);
        float2 sampleUV = clamp(
            (distorted * fullDims - tileOffset) / texSize, 0.0, 1.0);
        sum += tex.Sample(ss, sampleUV);
    }
    return sum / (float)NM_SPIN_BLUR_TAPS;
}

#endif
