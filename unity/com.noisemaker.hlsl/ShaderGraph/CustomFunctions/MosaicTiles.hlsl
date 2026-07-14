#ifndef NM_MOSAIC_TILES_SG_INCLUDED
#define NM_MOSAIC_TILES_SG_INCLUDED

// Untiled Shader Graph wrapper for filter/mosaicTiles.
#define MODE nmsg_mosaic_tiles_mode
#define tileSize nmsg_mosaic_tiles_tile_size
#define groutWidth nmsg_mosaic_tiles_grout_width
#define relief nmsg_mosaic_tiles_relief
#define maxOffset nmsg_mosaic_tiles_max_offset
#define gapFill nmsg_mosaic_tiles_gap_fill
#define backgroundColor nmsg_mosaic_tiles_background_color
#define seed nmsg_mosaic_tiles_seed
#include "../../Shaders/Effects/filter/MosaicTiles.hlsl"
#undef MODE
#undef tileSize
#undef groutWidth
#undef relief
#undef maxOffset
#undef gapFill
#undef backgroundColor
#undef seed

void NM_MosaicTiles_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2 UV,
    int Mode,
    float TileSize,
    float GroutWidth,
    float Relief,
    float MaxOffset,
    int GapFill,
    float3 BackgroundColor,
    int Seed,
    out float4 Out)
{
    nmsg_mosaic_tiles_mode = Mode;
    nmsg_mosaic_tiles_tile_size = TileSize;
    nmsg_mosaic_tiles_grout_width = GroutWidth;
    nmsg_mosaic_tiles_relief = Relief;
    nmsg_mosaic_tiles_max_offset = MaxOffset;
    nmsg_mosaic_tiles_gap_fill = (float)GapFill;
    nmsg_mosaic_tiles_background_color = BackgroundColor;
    nmsg_mosaic_tiles_seed = (float)Seed;
    _NM_TileOffset = float4(0.0, 0.0, 0.0, 0.0);

    uint tw, th;
    InputTex.tex.GetDimensions(tw, th);
    Out = nm_mosaic_tiles(InputTex.tex, SS.samplerstate, UV * float2(tw, th));
}

#endif
