#ifndef NM_LENS_FLARE_INCLUDED
#define NM_LENS_FLARE_INCLUDED

// filter/lensFlare — canonical fixed-table additive flare WGSL port.
#include "../../Include/NMFullscreen.hlsl"

int LENS_TYPE;
float brightness;
float centerX;
float centerY;
float3 tint;

static const float NM_LENS_FLARE_TAU = 6.28318530717958647692;

float2 nm_lens_flare_axis(float2 flarePos, float2 mirrorPos, float t, float aspect)
{
    float2 a = lerp(flarePos, mirrorPos, t);
    a.x = a.x * aspect;
    return a;
}

float nm_lens_flare_core_glow(float d)
{
    return exp(-d * d * 900.0) * 1.2 + exp(-d * 8.0) * 0.4;
}

float nm_lens_flare_anamorphic_streak(float2 delta)
{
    return exp(-(delta.y * delta.y * 4000.0 + delta.x * delta.x * 18.0));
}

float nm_lens_flare_six_point_star(float2 delta, float d)
{
    float phi = atan2(delta.y, delta.x);
    return pow(max(0.0, cos(6.0 * phi)), 40.0) * exp(-d * 5.0) * 0.5;
}

float3 nm_lens_flare_halo_rainbow(float dc)
{
    float3 phase = float3(dc * 10.0, dc * 10.0, dc * 10.0) + float3(0.0, 0.3333333, 0.6666667);
    return float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5) * cos(NM_LENS_FLARE_TAU * phase);
}

float nm_lens_flare_halo_band(float dc)
{
    return exp(-abs(dc - 0.28) * 60.0) * 0.25;
}

float nm_lens_flare_circle_ghost(float dist, float ghostSize)
{
    return 1.0 - smoothstep(ghostSize * 0.6, ghostSize, dist);
}

float nm_lens_flare_soft_circle_ghost(float dist, float ghostSize)
{
    return 1.0 - smoothstep(ghostSize * 0.3, ghostSize, dist);
}

float nm_lens_flare_ring_ghost(float dist, float ghostSize)
{
    float outer = 1.0 - smoothstep(ghostSize * 0.6, ghostSize, dist);
    float inner = 1.0 - smoothstep(ghostSize * 0.3, ghostSize * 0.6, dist);
    return outer - inner;
}

float nm_lens_flare_hex_dist(float2 p)
{
    float2 a0 = float2(1.0, 0.0);
    float2 a1 = float2(0.5, 0.8660254038);
    float2 a2 = float2(-0.5, 0.8660254038);
    float d0 = abs(dot(p, a0));
    float d1 = abs(dot(p, a1));
    float d2 = abs(dot(p, a2));
    return max(d0, max(d1, d2));
}

float nm_lens_flare_hex_ghost(float2 delta, float ghostSize)
{
    return 1.0 - smoothstep(ghostSize * 0.6, ghostSize, nm_lens_flare_hex_dist(delta));
}

float4 nm_lens_flare(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 fullDims = texSize;
    if (fullResolution.x > 0.0) fullDims = fullResolution;
    float aspect = fullDims.x / fullDims.y;
    float2 globalCoord = pos + tileOffset;
    float2 uv = globalCoord / fullDims;
    float2 localUV = pos / texSize;
    float4 src = tex.Sample(ss, localUV);

    float2 flarePos = float2(centerX, centerY);
    float2 mirrorPos = float2(1.0, 1.0) - flarePos;
    float2 p = uv;
    p.x = p.x * aspect;

    float2 aFlare = nm_lens_flare_axis(flarePos, mirrorPos, 0.0, aspect);
    float2 delta0 = p - aFlare;
    float d0 = length(delta0);
    float3 flare = float3(0.0, 0.0, 0.0);
    flare += nm_lens_flare_core_glow(d0);

    float streakVal = nm_lens_flare_anamorphic_streak(delta0);
    if (LENS_TYPE == 3) streakVal *= 2.0;
    flare += streakVal;

    if (LENS_TYPE == 0 || LENS_TYPE == 3)
        flare += nm_lens_flare_six_point_star(delta0, d0);

    float2 aMirror = nm_lens_flare_axis(flarePos, mirrorPos, 1.0, aspect);
    float dc = length(p - aMirror);
    flare += nm_lens_flare_halo_rainbow(dc) * nm_lens_flare_halo_band(dc);

    float2 g = float2(0.0, 0.0);
    [branch]
    if (LENS_TYPE == 0 || LENS_TYPE == 3)
    {
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.25, aspect);
        flare += float3(1.00, 0.85, 0.60) * nm_lens_flare_circle_ghost(length(p - g), 0.06) * 0.35;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.4, aspect);
        flare += float3(0.40, 0.90, 0.85) * nm_lens_flare_circle_ghost(length(p - g), 0.10) * 0.25;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.6, aspect);
        flare += float3(0.65, 0.40, 0.95) * nm_lens_flare_circle_ghost(length(p - g), 0.045) * 0.45;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.85, aspect);
        flare += float3(0.45, 0.90, 0.50) * nm_lens_flare_circle_ghost(length(p - g), 0.14) * 0.18;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 1.2, aspect);
        flare += float3(1.00, 0.55, 0.20) * nm_lens_flare_circle_ghost(length(p - g), 0.08) * 0.30;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 1.55, aspect);
        flare += float3(0.40, 0.55, 1.00) * nm_lens_flare_ring_ghost(length(p - g), 0.20) * 0.12;
    }
    else if (LENS_TYPE == 1)
    {
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.3, aspect);
        flare += float3(1.00, 0.80, 0.55) * nm_lens_flare_hex_ghost(p - g, 0.04) * 0.35;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.55, aspect);
        flare += float3(0.85, 0.85, 0.92) * nm_lens_flare_hex_ghost(p - g, 0.055) * 0.30;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.8, aspect);
        flare += float3(0.95, 0.70, 0.50) * nm_lens_flare_hex_ghost(p - g, 0.065) * 0.25;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 1.3, aspect);
        flare += float3(0.80, 0.85, 0.95) * nm_lens_flare_hex_ghost(p - g, 0.08) * 0.20;
    }
    else
    {
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.45, aspect);
        flare += float3(0.92, 0.85, 0.78) * nm_lens_flare_soft_circle_ghost(length(p - g), 0.12) * 0.25;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 0.9, aspect);
        flare += float3(0.85, 0.88, 0.95) * nm_lens_flare_soft_circle_ghost(length(p - g), 0.16) * 0.20;
        g = nm_lens_flare_axis(flarePos, mirrorPos, 1.5, aspect);
        flare += float3(0.95, 0.88, 0.80) * nm_lens_flare_soft_circle_ghost(length(p - g), 0.20) * 0.15;
    }

    float3 outFlare = flare * tint * (brightness / 100.0);
    if (LENS_TYPE == 3) outFlare *= float3(0.9, 0.95, 1.1);
    return float4(clamp(src.rgb + outFlare, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0)), src.a);
}

#endif
