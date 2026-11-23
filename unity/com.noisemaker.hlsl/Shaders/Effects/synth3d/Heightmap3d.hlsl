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
//    image-row flip (row volumeSize-1-z, so z = 0 is the image's top row) and
//    the (image*2+1)*size / (volumeSize*2) half-texel-centered rescale.
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

// The terrain keeps the frame's proportions inside the square footprint of the
// volume. On a wide frame it spans the volume's width and a part of its depth,
// on a tall frame the depth and a part of the width, and on a square frame all
// of both. Each span is a whole, even count of columns, so the terrain is
// centered. aspectRatio and aspectInv are the frame's width over its height and
// the inverse. They are computed outside the shader and the volume size is a
// power of two, so both backends get the same counts (reference 478f94ea).
// aspectRatio is the NMFullscreen alias for the reference `aspect` global.
int2 hm3d_terrainSpan()
{
    float halfSize = (float)volumeSize * 0.5;
    return int2(
        aspectRatio < 1.0 ? max(2, 2 * (int)floor(halfSize * aspectRatio + 0.5)) : volumeSize,
        aspectInv < 1.0 ? max(2, 2 * (int)floor(halfSize * aspectInv + 0.5)) : volumeSize);
}

// The place of an XZ voxel column in the terrain, counted in columns from the
// terrain's own corner. Volume z = 0 is toward the image's top row, so a view
// from above along -Y, screen right on +X, shows the image as authored rather
// than mirrored (reference 8fa067f6; GLSL and WGSL agree). Texel row 0 is the
// image's bottom row in the shared logical coordinates, so z = 0 samples the
// last texel row.
int2 hm3d_terrainColumn(int2 column)
{
    return int2(column.x, volumeSize - 1 - column.y)
        - (int2(volumeSize, volumeSize) - hm3d_terrainSpan()) / 2;
}

bool hm3d_inTerrain(int2 column)
{
    int2 image = hm3d_terrainColumn(column);
    return all(image >= int2(0, 0)) && all(image < hm3d_terrainSpan());
}

// Native atlases and 2D surfaces use the same logical texel coordinates on
// both backends. Sample each image independently at the center of the XZ voxel
// column (reference 0ed489ec, verbatim).
int2 hm3d_imageTexel(int2 column, int2 size)
{
    return clamp(((hm3d_terrainColumn(column) * 2 + 1) * size) / (hm3d_terrainSpan() * 2),
        int2(0, 0), size - int2(1, 1));
}

float hm3d_columnHeight(int2 column)
{
    if (!hm3d_inTerrain(column)) return 0.0;
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
