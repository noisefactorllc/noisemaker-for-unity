#ifndef NM_MOSAIC_TILES_INCLUDED
#define NM_MOSAIC_TILES_INCLUDED

// filter/mosaicTiles — canonical wavy mosaic / shifted tile WGSL port.
#include "../../Include/NMFullscreen.hlsl"

int MODE;
float tileSize;
float groutWidth;
float relief;
float maxOffset;
float gapFill;
float3 backgroundColor;
float seed;

float nm_mosaic_tiles_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.x + p3.y) * p3.z);
}

float2 nm_mosaic_tiles_hash22(float2 p)
{
    float3 p3 = frac(p.xyx * float3(0.1031, 0.1030, 0.0973));
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.xx + p3.yz) * p3.zy);
}

float nm_mosaic_tiles_vnoise(float2 p)
{
    float2 ip = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(
        lerp(nm_mosaic_tiles_hash12(ip), nm_mosaic_tiles_hash12(ip + float2(1.0, 0.0)), u.x),
        lerp(nm_mosaic_tiles_hash12(ip + float2(0.0, 1.0)), nm_mosaic_tiles_hash12(ip + float2(1.0, 1.0)), u.x),
        u.y);
}

float nm_mosaic_tiles_relief_shade(float hC, float hR, float hT, float strength, float lightAngleDeg)
{
    float2 grad = float2(hR - hC, hT - hC) * strength;
    float3 n = normalize(float3(-grad, 1.0));
    float a = radians(lightAngleDeg);
    float3 L = normalize(float3(cos(a), sin(a), 0.75));
    return clamp(dot(n, L), 0.0, 1.0);
}

float nm_mosaic_tiles_warp(float2 gc, float tileSizePx, float seedVal)
{
    return nm_mosaic_tiles_vnoise(gc / tileSizePx + seedVal * 101.7) * 0.25 * tileSizePx;
}

float nm_mosaic_tiles_grout_mask(float2 gc, float tileSizePx, float groutWidthPct, float seedVal)
{
    float warp = nm_mosaic_tiles_warp(gc, tileSizePx, seedVal);
    float2 cellFrac = frac((gc + float2(warp, warp)) / tileSizePx);
    float edgeDistPx = min(min(cellFrac.x, 1.0 - cellFrac.x), min(cellFrac.y, 1.0 - cellFrac.y)) * tileSizePx;
    float groutHalfWidthPx = groutWidthPct / 100.0 * (tileSizePx * 0.5);
    float groutAA = 1.25;
    return 1.0 - smoothstep(groutHalfWidthPx - groutAA, groutHalfWidthPx + groutAA, edgeDistPx);
}

float4 nm_mosaic_tiles(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 globalCoord = pos + tileOffset;
    float2 uv = pos / texSize;
    float4 srcHome = tex.Sample(ss, uv);
    float seedF = seed;
    float3 result;

    [branch]
    if (MODE == 0)
    {
        float warp = nm_mosaic_tiles_warp(globalCoord, tileSize, seedF);
        float2 warpedCoord = globalCoord + float2(warp, warp);
        float2 cellSpace = warpedCoord / tileSize;
        float2 cellId = floor(cellSpace);
        float2 warpedCenter = (cellId + float2(0.5, 0.5)) * tileSize;
        float centerWarp = nm_mosaic_tiles_warp(warpedCenter, tileSize, seedF);
        float2 sampleGc = warpedCenter - float2(centerWarp, centerWarp);
        float2 sampleUV = clamp((sampleGc - tileOffset) / texSize, float2(0.0, 0.0), float2(1.0, 1.0));
        float3 tileColor = tex.Sample(ss, sampleUV).rgb;

        float kC = nm_mosaic_tiles_grout_mask(globalCoord, tileSize, groutWidth, seedF);
        float kR = nm_mosaic_tiles_grout_mask(globalCoord + float2(1.0, 0.0), tileSize, groutWidth, seedF);
        float kL = nm_mosaic_tiles_grout_mask(globalCoord - float2(1.0, 0.0), tileSize, groutWidth, seedF);
        float kT = nm_mosaic_tiles_grout_mask(globalCoord + float2(0.0, 1.0), tileSize, groutWidth, seedF);
        float kB = nm_mosaic_tiles_grout_mask(globalCoord - float2(0.0, 1.0), tileSize, groutWidth, seedF);
        float2 gradK = float2((kR - kL) * 0.5, (kT - kB) * 0.5);

        float hC = -kC;
        float hR = hC - gradK.x;
        float hT = hC - gradK.y;
        float shadeStrength = 6.0;
        float shade = nm_mosaic_tiles_relief_shade(hC, hR, hT, shadeStrength, 135.0);
        float flatShade = 0.6;
        float3 darkened = tileColor * lerp(1.0, 0.35, kC);
        float shadeMul = 1.0 + (shade - flatShade) * 2.0 * (relief / 100.0);
        result = clamp(darkened * shadeMul, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
    }
    else
    {
        float2 cellSpace = globalCoord / tileSize;
        float2 cellId = floor(cellSpace);
        float2 cellFrac = frac(cellSpace);
        float edgeDistPx = min(min(cellFrac.x, 1.0 - cellFrac.x), min(cellFrac.y, 1.0 - cellFrac.y)) * tileSize;

        float gapWidthPx = groutWidth / 100.0 * tileSize;
        float gapAA = 1.25;
        float gapMask = 1.0 - smoothstep(gapWidthPx * 0.5 - gapAA, gapWidthPx * 0.5 + gapAA, edgeDistPx);
        float2 offsetPx = (nm_mosaic_tiles_hash22(cellId + seedF * 101.7) - 0.5) * 2.0 * (maxOffset / 100.0) * tileSize;
        float2 cellCenterGc = (cellId + float2(0.5, 0.5)) * tileSize;
        float2 shiftedGc = cellCenterGc + offsetPx;
        float2 shiftedUV = clamp((shiftedGc - tileOffset) / texSize, float2(0.0, 0.0), float2(1.0, 1.0));
        float3 tileColor = tex.Sample(ss, shiftedUV).rgb;

        int gapFillInt = (int)gapFill;
        float3 gapColor;
        if (gapFillInt == 0) gapColor = backgroundColor;
        else if (gapFillInt == 1) gapColor = 1.0 - srcHome.rgb;
        else gapColor = srcHome.rgb;
        result = lerp(tileColor, gapColor, gapMask);
    }

    return float4(result, srcHome.a);
}

#endif
