#ifndef NM_SCATTER_INCLUDED
#define NM_SCATTER_INCLUDED

// filter/scatter — rgba8 jitter intermediate plus 3x3 tent smoothing.
//
// The jitter pass hashes the pixel's global (tile-aware) integer coordinate and
// `seed` with the shared PCG3D (nm_pcg; identical mixing to the reference's
// pcg3d). Unsigned arithmetic wraps the same way on every compiler, so all
// backends draw identical offsets; the former float hash22 rounded and fused
// differently per compiler and drifted apart (noisemaker 7aa54b54).
//
// The offset is quantized to integer 1/256 px steps in [-radius, radius) on
// each axis (the top 16 hash bits scale the span 2 * radius * 256 in integers;
// the 128 px radius cap keeps the product within 32 bits), and both reads are
// texel loads of the texel nearest the offset sample position, matching the
// reference's texelFetch / textureLoad. Outside anisotropic mode the offset is
// a multiple of 1/256, so floor(offset + 0.5) is exact on every backend.
#include "../../Include/NMFullscreen.hlsl"

int MODE;
float radius;
float smoothness;
float seed;

float nm_scatter_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float2 nm_scatter_lum_gradient(Texture2D tex, SamplerState ss, float2 uv)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 px = 1.0 / float2(tw, th);
    float tl = nm_scatter_lum(tex.Sample(ss, uv + px * float2(-1.0,  1.0)).rgb);
    float l  = nm_scatter_lum(tex.Sample(ss, uv + px * float2(-1.0,  0.0)).rgb);
    float bl = nm_scatter_lum(tex.Sample(ss, uv + px * float2(-1.0, -1.0)).rgb);
    float tr = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 1.0,  1.0)).rgb);
    float r  = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 1.0,  0.0)).rgb);
    float br = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 1.0, -1.0)).rgb);
    float t  = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 0.0,  1.0)).rgb);
    float b  = nm_scatter_lum(tex.Sample(ss, uv + px * float2( 0.0, -1.0)).rgb);
    return float2(tr + 2.0 * r + br - tl - 2.0 * l - bl,
                  tl + 2.0 * t + tr - bl - 2.0 * b - br);
}

float4 nm_scatter_jitter(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    int2 texSizeI = int2(tw, th);
    pos = floor(pos) + 0.5;
    int2 texel = (int2)floor(pos);
    float2 texSize = float2(tw, th);
    float2 uv = pos / texSize;
    float2 globalCoord = pos + tileOffset;
    float2 hashCoord = globalCoord;
    if (MODE == 4) hashCoord = floor(globalCoord / 3.0) * 3.0;

    // uint3 h = pcg3d(uvec3(uvec2(ivec2(floor(hashCoord))), uint(seed)))
    uint3 h = nm_pcg(uint3((uint2)(int2)floor(hashCoord), (uint)(int)seed));

    // Offset in 1/256 px steps, in [-radius, radius) on each axis: the top 16
    // hash bits scale the span 2 * radius * 256 in integers. radius * 256 is
    // exact; the 128 px cap (far above the 25 px slider maximum) keeps the
    // product within 32 bits.
    uint r256 = (uint)(min(abs(radius), 128.0) * 256.0);
    uint2 steps = ((h.xy >> uint2(16u, 16u)) * (2u * r256)) >> uint2(16u, 16u);
    float2 offset = (float2)((int2)steps - (int)r256) / 256.0;

    if (MODE == 3)
    {
        float2 grad = nm_scatter_lum_gradient(tex, ss, uv);
        float gradLen = length(grad);
        if (gradLen > 1e-5)
        {
            float2 perp = float2(-grad.y, grad.x) / gradLen;
            offset = dot(offset, perp) * perp;
        }
    }

    // Read the texel nearest the offset sample position, clamped to the edge.
    // Outside anisotropic mode the offset is a multiple of 1/256, so
    // offset + 0.5 and its floor are exact on both backends.
    int2 sampleTexel = clamp(texel + (int2)floor(offset + 0.5), int2(0, 0), texSizeI - 1);

    float4 src = tex.Load(int3(texel, 0));
    float4 samp = tex.Load(int3(sampleTexel, 0));
    float4 result = samp;
    if (MODE == 1) result = min(src, samp);
    else if (MODE == 2) result = max(src, samp);
    return result;
}

float4 nm_scatter_smooth(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 uv = pos / texSize;
    float2 texel = 1.0 / texSize;
    float4 src = tex.Sample(ss, uv);

    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    float wsum = 0.0;
    [unroll]
    for (int y = -1; y <= 1; y++)
    {
        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            float w = (2.0 - abs((float)x)) * (2.0 - abs((float)y));
            sum += tex.Sample(ss, uv + float2((float)x, (float)y) * texel) * w;
            wsum += w;
        }
    }
    float4 blurred = sum / wsum;
    return lerp(src, blurred, clamp(smoothness / 100.0, 0.0, 1.0));
}

#endif
