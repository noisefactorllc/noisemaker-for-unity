#ifndef NM_DIRECTIONAL_BLUR_INCLUDED
#define NM_DIRECTIONAL_BLUR_INCLUDED

// filter/directionalBlur — canonical WGSL port (single pass, 32 fixed taps).
#include "../../Include/NMFullscreen.hlsl"

float angle;
float blurDistance;

static const int NM_DIRECTIONAL_BLUR_TAPS = 32;

float nm_directional_blur_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.x + p3.y) * p3.z);
}

float4 nm_directional_blur(Texture2D tex, SamplerState ss, float2 pos)
{
    // Recover WGSL @builtin(position)'s exact half-integer center before the
    // high-sensitivity hash and point-sampled fractional tap comb.
    pos = floor(pos) + 0.5;
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float a = radians(angle);
    float2 dir = float2(cos(a), sin(a));

    float tapStep = blurDistance / (float)(NM_DIRECTIONAL_BLUR_TAPS - 1);
    float jitter = (nm_directional_blur_hash12(pos) - 0.5) * tapStep;

    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    for (int tap = 0; tap < NM_DIRECTIONAL_BLUR_TAPS; tap++)
    {
        float t = ((float)tap / (float)(NM_DIRECTIONAL_BLUR_TAPS - 1) - 0.5) * blurDistance + jitter;
        float2 offset = dir * t;
        sum = sum + tex.Sample(ss, (pos + offset) / texSize);
    }
    return sum / (float)NM_DIRECTIONAL_BLUR_TAPS;
}

#endif
