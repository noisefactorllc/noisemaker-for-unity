#ifndef NM_EFFECT_HEIGHTMAP3D_INCLUDED
#define NM_EFFECT_HEIGHTMAP3D_INCLUDED

// =============================================================================
// Heightmap3d.hlsl — synth3d/heightmap3d (func: "heightmap3d") — NEW this round
// (reference 0ed489ec). Voxel heightfield: bakes separate height and diffuse-
// color 2D surfaces into the volume atlas. Single fullscreen MRT pass (matches
// the synth3d/noise3d convention exactly), ported PIXEL-IDENTICALLY from:
//   wgsl/precompute.wgsl   progName "precompute"   (frag_precompute)
//
// Same VOLUME-WRITE atlas model as Noise3d.hlsl/CellularAutomata3d.hlsl: the
// render target is a 2D atlas volumeSize x volumeSize^2, rgba16f; atlas pixel
// (x,y) -> voxel (x, y%volSize, y/volSize). MRT: location 0 = volumeCache
// (color), location 1 = geoBuffer (geoOut: xyz=normal*0.5+0.5, w=density).
//
// PORTING-GUIDE / parity notes:
//  * WGSL textureDimensions(t) -> HLSL t.GetDimensions(w,h) (uint out-params).
//  * WGSL textureLoad(t, coord, 0) -> t.Load(int3(coord, 0)) — integer texel
//    fetch, point, no filtering.
//  * imageTexel: native atlases and 2D surfaces use the SAME logical texel
//    coordinates on both backends — reproduced verbatim, including the
//    (column*2+1)*size / (volumeSize*2) half-texel-centered rescale.
//  * int % and / on non-negative values match WGSL i32 trunc semantics.
//  * any(lessThan(...))/any(greaterThanEqual(...)) -> HLSL any(a < b) / any(a >= b)
//    (HLSL relational/any operate component-wise on vectors already).
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

Texture2D heightTex; SamplerState sampler_heightTex;
Texture2D tex;       SamplerState sampler_tex;

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) -----
int   volumeSize;   // globals.volumeSize  default 64 (atlas slice edge)
float heightScale;  // globals.heightScale default 0.35
float baseHeight;   // globals.baseHeight  default 0

struct Heightmap3dFragmentOutput
{
    float4 fragColor : SV_Target0;   // -> volumeCache (color)
    float4 geoOut    : SV_Target1;   // -> geoBuffer  (geoOut)
};

// Native atlases and 2D surfaces use the same logical texel coordinates on
// both backends (reference 0ed489ec, verbatim).
int2 hm3d_imageTexel(int2 column, int2 size)
{
    return clamp(((column * 2 + 1) * size) / (volumeSize * 2), int2(0, 0), size - int2(1, 1));
}

float hm3d_columnHeight(int2 column)
{
    uint hw, hh;
    heightTex.GetDimensions(hw, hh);
    float3 rgb = heightTex.Load(int3(hm3d_imageTexel(column, int2((int)hw, (int)hh)), 0)).rgb;
    float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    return floor(clamp(luminance * heightScale + baseHeight, 0.0, 1.0) * (float)volumeSize + 0.5);
}

float hm3d_density(int3 p)
{
    if (any(p < int3(0, 0, 0)) || any(p >= (int3)volumeSize)) return 0.0;
    return ((float)p.y < hm3d_columnHeight(p.xz)) ? 1.0 : 0.0;
}

// =============================================================================
// PASS: precompute — volume-write (MRT) — (frag_precompute)
// =============================================================================
Heightmap3dFragmentOutput frag_precompute(NMVaryings i)
{
    Heightmap3dFragmentOutput o;

    int2 atlas = (int2)NM_FragCoord(i);
    int3 p = int3(atlas.x, atlas.y % volumeSize, atlas.y / volumeSize);
    float occupied = hm3d_density(p);
    o.fragColor = float4(0.0, 0.0, 0.0, 0.0);
    o.geoOut    = float4(0.5, 1.0, 0.5, 0.0);
    if (occupied == 0.0) return o;

    uint tw, th;
    tex.GetDimensions(tw, th);
    float3 color = tex.Load(int3(hm3d_imageTexel(p.xz, int2((int)tw, (int)th)), 0)).rgb;
    o.fragColor = float4(color, occupied);

    float3 normal = float3(
        hm3d_density(p - int3(1, 0, 0)) - hm3d_density(p + int3(1, 0, 0)),
        hm3d_density(p - int3(0, 1, 0)) - hm3d_density(p + int3(0, 1, 0)),
        hm3d_density(p - int3(0, 0, 1)) - hm3d_density(p + int3(0, 0, 1))
    );
    if (dot(normal, normal) > 0.0) normal = normalize(normal);
    else normal = float3(0.0, 1.0, 0.0);
    o.geoOut = float4(normal * 0.5 + 0.5, occupied);
    return o;
}

#endif // NM_EFFECT_HEIGHTMAP3D_INCLUDED
