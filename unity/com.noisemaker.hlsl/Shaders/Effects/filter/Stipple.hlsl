#ifndef NM_STIPPLE_INCLUDED
#define NM_STIPPLE_INCLUDED

// filter/stipple — canonical pointillize/mezzotint/reticulation WGSL port.
//
// Every hash, noise, distance and blend runs in unsigned integer fixed point
// (12-bit fractions, 16-bit values) from the integer pixel coordinate, with a
// PCG3D hash of the lattice cell and seed, and reads texels with Texture2D
// loads. The former float hashes and thresholds rounded and fused differently
// per compiler, so backends drifted apart (noisemaker 1faed961); integers give
// all backends the same bytes. The pointillize edge blends over a fixed 2 px
// instead of fwidth.
//
// mezzoStrokes's 45-degree rotation is the integer form of GLSL's
// column-major mat2(c,-s,s,c) multiplication, so the marks keep the same
// presented slope; the rotated y is offset by 2^20 px so the unsigned
// position stays positive.
#include "../../Include/NMFullscreen.hlsl"

int MODE;
float cellSize;
float grainSize;
float density;
float3 paperColor;
float seed;

// hash - PCG3D integer hash (Jarzynski & Olano 2020) — the shared nm_pcg,
// identical mixing to the reference's pcg3d.
uint3 nm_stipple_pcg3d(uint3 v_in)
{
    return nm_pcg(v_in);
}

// 16-bit hash of a lattice cell and seed.
uint nm_stipple_hash16(uint2 cell, uint s)
{
    return nm_stipple_pcg3d(uint3(cell, s)).x >> 16u;
}

// Channel value as 16-bit unorm. Scaling by 65536 is exact, so the floor is too.
uint nm_stipple_unorm16(float x)
{
    return min((uint)(clamp(x, 0.0, 1.0) * 65536.0), 65535u);
}

// luminance - Rec. 709 luminance, 16-bit, weights summing to 65536.
uint nm_stipple_lum16(float3 c)
{
    return (nm_stipple_unorm16(c.r) * 13933u
        + nm_stipple_unorm16(c.g) * 46872u
        + nm_stipple_unorm16(c.b) * 4731u) >> 16u;
}

// Smoothstep weight t * t * (3 - 2t) of a 12-bit fraction.
uint nm_stipple_smooth12(uint t)
{
    return (((t * t) >> 12u) * (12288u - 2u * t)) >> 12u;
}

// value noise - value noise at position n / d in lattice cells, 16-bit.
uint nm_stipple_vnoise(uint2 n, uint2 d, uint s)
{
    uint2 i = n / d;
    uint2 f = ((n - i * d) << uint2(12u, 12u)) / d;
    uint ux = nm_stipple_smooth12(f.x);
    uint uy = nm_stipple_smooth12(f.y);
    uint ab = (nm_stipple_hash16(i, s) * (4096u - ux)
        + nm_stipple_hash16(i + uint2(1u, 0u), s) * ux) >> 12u;
    uint cd = (nm_stipple_hash16(i + uint2(0u, 1u), s) * (4096u - ux)
        + nm_stipple_hash16(i + uint2(1u, 1u), s) * ux) >> 12u;
    return (ab * (4096u - uy) + cd * uy) >> 12u;
}

// fBm - 5 octaves of value noise on a lattice of 4 * grain, each at 2.03x
// the frequency and half the amplitude: octave k's lattice is
// 4 * grain * M[k] / 65536, with M[k] = 65536 / 2.03^k.
uint nm_stipple_fbm(uint2 n, uint grain, uint s)
{
    const uint M[5] = { 65536u, 32284u, 15903u, 7834u, 3859u };
    uint v = 0u;
    [unroll]
    for (int k = 0; k < 5; k++)
    {
        uint dk = max((grain * M[k] + 8192u) >> 14u, 1u);
        v += nm_stipple_vnoise(n, uint2(dk, dk), s) >> (uint)k + 1u;
    }
    return v;
}

// Floor of the integer square root: a float estimate, corrected in integers.
uint nm_stipple_isqrt(uint x)
{
    uint r = (uint)sqrt((float)x);
    if (r * r > x) { r--; }
    if (r * r > x) { r--; }
    if ((r + 1u) * (r + 1u) <= x) { r++; }
    if ((r + 1u) * (r + 1u) <= x) { r++; }
    return r;
}

// Mezzo and reticulation threshold step(edge + (density - 50) / 100, value)
// on 16-bit values, density in 1/256 units, multiplied through by 25.
float nm_stipple_ink_step(uint edge, uint value, int d256)
{
    return 25 * (int)value + 819200 >= 25 * (int)edge + 64 * d256 ? 1.0 : 0.0;
}

float4 nm_stipple(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    int2 texSizeI = int2(tw, th);
    pos = floor(pos) + 0.5;
    int2 texel = (int2)floor(pos);
    // Global (tile-aware) pixel. Positions are pixel centers in 1/256 px,
    // (2 * px + 1) * 128, over sizes in 1/256 px.
    uint2 px = (uint2)(texel + (int2)tileOffset);
    uint2 center = (2u * px + 1u) * 128u;
    float4 src = tex.Load(int3(texel, 0));
    uint s = (uint)(int)seed;
    int d256 = (int)floor(density * 256.0);
    uint g256 = clamp((uint)(max(grainSize, 0.0) * 256.0), 1u, 32768u);
    float3 result;

    [branch]
    if (MODE == 0)
    {
        // Pointillize: one dot per jittered Voronoi cell (cellSize px),
        // colored and sized from the image at that cell's own seed
        // point; darker seed colors get bigger dots. Background is
        // paperColor. The dot edge blends over 2 px on each side.
        uint c256 = clamp((uint)(max(cellSize, 0.0) * 256.0), 1u, 65535u);
        uint2 g = center / c256;
        int2 f = (int2)(((center - g * c256) << uint2(12u, 12u)) / c256);
        // Jittered-grid Voronoi in 12-bit cell units: seed point = cell +
        // 0.5 + (hash - 0.5) * 0.9. Search radius is one ring of neighbor
        // cells, so the jitter stays within [0, 1] for the nearest seed to
        // be in the window.
        int best = 2147483647;
        int2 bestPt = int2(0, 0);
        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                int2 cell = int2(x, y);
                uint2 h = nm_stipple_pcg3d(uint3((uint2)((int2)g + cell), s)).xy >> uint2(16u, 16u);
                int2 pt = cell * 4096 + int2(205, 205)
                    + (int2)(((h * 9u) / 10u) >> uint2(4u, 4u));
                int2 dv = pt - f;
                int dd = dv.x * dv.x + dv.y * dv.y;
                if (dd < best)
                {
                    best = dd;
                    bestPt = pt;
                }
            }
        }
        // Seed point in 1/256 px, measured from the cell to the lower left
        // so the offset stays positive; the dot's color is the texel under it.
        int2 seed256 = ((int2)g - 1) * (int)c256
            + (int2)(((uint2)(bestPt + 4096) * c256) >> uint2(12u, 12u));
        int2 seedTexel = clamp(
            ((max(seed256, int2(0, 0))) >> 8) - (int2)tileOffset,
            int2(0, 0), texSizeI - 1);
        float3 seedColor = tex.Load(int3(seedTexel, 0)).rgb;
        int radius = 1434 + (int)((1638u * (65535u - nm_stipple_lum16(seedColor))) >> 16u);
        int d = (int)nm_stipple_isqrt((uint)best);
        int aa = (int)(2097152u / c256);
        uint t = 0u;
        if (d >= radius + aa)
        {
            t = 4096u;
        }
        else if (d > radius - aa)
        {
            t = ((uint)(d - radius + aa) << 12u) / (uint)(2 * aa);
        }
        uint inside = 4096u - nm_stipple_smooth12(t);
        uint3 paper = uint3(
            nm_stipple_unorm16(paperColor.r),
            nm_stipple_unorm16(paperColor.g),
            nm_stipple_unorm16(paperColor.b));
        uint3 ink = uint3(
            nm_stipple_unorm16(seedColor.r),
            nm_stipple_unorm16(seedColor.g),
            nm_stipple_unorm16(seedColor.b));
        result = ((paper * (4096u - inside) + ink * inside) >> uint3(12u, 12u, 12u)) / 65536.0;
    }
    else if (MODE == 1 || MODE == 2 || MODE == 3)
    {
        // Mezzotint dots/lines/strokes: per-channel hard threshold
        // against shaped value noise. density biases the threshold (n)
        // directly, so higher density raises n and lowers the fraction
        // of channel values that clear it - i.e. more ink.
        uint2 p = center;
        uint grain = g256;
        if (MODE == 3)
        {
            // Rotate 45 degrees: x' = (x + y) / sqrt2, y' = (y - x) / sqrt2,
            // with the 1 / sqrt2 in the grain size; see stipple.glsl.
            p = uint2((px.x + px.y + 1u) * 256u, (px.y + 1048576u - px.x) * 256u);
            grain = (g256 * 92682u + 32768u) >> 16u;
        }
        uint2 lattice = uint2(grain, grain);
        if (MODE != 1)
        {
            // Anisotropic (line) noise: the Y component keeps the coarse
            // (grainSize*8) scale and X keeps the fine (grainSize) scale,
            // so streaks run vertically.
            lattice = uint2(grain, grain * 8u);
        }
        uint n = nm_stipple_vnoise(p, lattice, s);
        result = float3(
            nm_stipple_ink_step(n, nm_stipple_unorm16(src.r), d256),
            nm_stipple_ink_step(n, nm_stipple_unorm16(src.g), d256),
            nm_stipple_ink_step(n, nm_stipple_unorm16(src.b), d256));
    }
    else
    {
        // Reticulation: two-tone ink/paper tonemap against clumped fBm
        // noise; the noise amplitude is luminance-modulated so shadows
        // get more contrast, with the same density bias as mezzo.
        // Amplitude mix(1.2, 0.6, l) in 1/65536 units.
        uint l = nm_stipple_lum16(src.rgb);
        uint amp = 78643u - ((39322u * l) >> 16u);
        uint clumpNoise = (nm_stipple_fbm(center, g256, s) * (amp >> 2u)) >> 14u;
        result = nm_stipple_ink_step(clumpNoise, l, d256) > 0.5
            ? float3(0.97, 0.97, 0.97) : float3(0.05, 0.05, 0.05);
    }

    return float4(result, src.a);
}

#endif
