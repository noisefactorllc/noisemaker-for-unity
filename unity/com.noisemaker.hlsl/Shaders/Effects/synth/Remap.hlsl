#ifndef NM_REMAP_INCLUDED
#define NM_REMAP_INCLUDED

// =============================================================================
// Remap.hlsl — synth/remap, ported PIXEL-IDENTICALLY from the canonical WGSL:
//   shaders/effects/synth/remap/wgsl/remap.wgsl
//
// Polygon-zone router. Up to 8 zones each defined by a convex-or-concave
// polygon (ray-casting point-in-polygon) and an optional alpha edge-soften.
// Each zone samples from its own wired source surface (zone0_tex..zone7_tex).
//
// Uniforms are exposed as individual named uniforms (not the WGSL vec4 array).
// Per-zone vertex pairs are declared individually matching uniformLayout.
//
// COORDINATE NOTES (follow WGSL exactly):
//   sampleUv = fragCoord / resolution  (tile-local, Y-down, for textureSample)
//   globalYup = (fragCoord + tileOffset) / fullResolution
//   p = float2(globalYup.x, 1.0 - globalYup.y)   // Y-up, [0,1] for poly test
//   edgeWidth = smoothEdge * 0.05  (distance in same p-space)
//
// No helpers from NMCore (no pcg/hash needed). All helpers are inlined.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) ------
float3 bgColor;       // default [0,0,0]
float  bgAlpha;       // default 1.0
int    zoneCount;     // default 0, range [0,8]
float  smoothEdge;    // default 0.04, range [0,1]

// Per-zone meta uniforms
float zone0_count;  float zone0_active;  float zone0_alpha;
float zone1_count;  float zone1_active;  float zone1_alpha;
float zone2_count;  float zone2_active;  float zone2_alpha;
float zone3_count;  float zone3_active;  float zone3_alpha;
float zone4_count;  float zone4_active;  float zone4_alpha;
float zone5_count;  float zone5_active;  float zone5_alpha;
float zone6_count;  float zone6_active;  float zone6_alpha;
float zone7_count;  float zone7_active;  float zone7_alpha;

// Per-zone bounds (reference 0ed489ec, NEW): host-supplied bounding box
// [minX, minY, maxX, maxY], normalized. Default [0,0,1,1] never rejects a
// pixel. Used to skip a zone's polygon walk entirely when the pixel cannot be
// inside it (dilated by the feather width so the reject box never erodes the
// visible, feathered edge).
float4 zone0_bounds; float4 zone1_bounds; float4 zone2_bounds; float4 zone3_bounds;
float4 zone4_bounds; float4 zone5_bounds; float4 zone6_bounds; float4 zone7_bounds;

// Per-zone vertex pair uniforms (32 pairs per zone = 64 verts, packed xy+zw).
// Upstream ba7e789f raised the per-zone vertex cap 16 -> 64 (uniformLayout
// slots 10..265); we keep the GLSL-style individual named uniforms.
float4 zone0_v0; float4 zone0_v1; float4 zone0_v2; float4 zone0_v3;
float4 zone0_v4; float4 zone0_v5; float4 zone0_v6; float4 zone0_v7;
float4 zone0_v8; float4 zone0_v9; float4 zone0_v10; float4 zone0_v11;
float4 zone0_v12; float4 zone0_v13; float4 zone0_v14; float4 zone0_v15;
float4 zone0_v16; float4 zone0_v17; float4 zone0_v18; float4 zone0_v19;
float4 zone0_v20; float4 zone0_v21; float4 zone0_v22; float4 zone0_v23;
float4 zone0_v24; float4 zone0_v25; float4 zone0_v26; float4 zone0_v27;
float4 zone0_v28; float4 zone0_v29; float4 zone0_v30; float4 zone0_v31;
float4 zone1_v0; float4 zone1_v1; float4 zone1_v2; float4 zone1_v3;
float4 zone1_v4; float4 zone1_v5; float4 zone1_v6; float4 zone1_v7;
float4 zone1_v8; float4 zone1_v9; float4 zone1_v10; float4 zone1_v11;
float4 zone1_v12; float4 zone1_v13; float4 zone1_v14; float4 zone1_v15;
float4 zone1_v16; float4 zone1_v17; float4 zone1_v18; float4 zone1_v19;
float4 zone1_v20; float4 zone1_v21; float4 zone1_v22; float4 zone1_v23;
float4 zone1_v24; float4 zone1_v25; float4 zone1_v26; float4 zone1_v27;
float4 zone1_v28; float4 zone1_v29; float4 zone1_v30; float4 zone1_v31;
float4 zone2_v0; float4 zone2_v1; float4 zone2_v2; float4 zone2_v3;
float4 zone2_v4; float4 zone2_v5; float4 zone2_v6; float4 zone2_v7;
float4 zone2_v8; float4 zone2_v9; float4 zone2_v10; float4 zone2_v11;
float4 zone2_v12; float4 zone2_v13; float4 zone2_v14; float4 zone2_v15;
float4 zone2_v16; float4 zone2_v17; float4 zone2_v18; float4 zone2_v19;
float4 zone2_v20; float4 zone2_v21; float4 zone2_v22; float4 zone2_v23;
float4 zone2_v24; float4 zone2_v25; float4 zone2_v26; float4 zone2_v27;
float4 zone2_v28; float4 zone2_v29; float4 zone2_v30; float4 zone2_v31;
float4 zone3_v0; float4 zone3_v1; float4 zone3_v2; float4 zone3_v3;
float4 zone3_v4; float4 zone3_v5; float4 zone3_v6; float4 zone3_v7;
float4 zone3_v8; float4 zone3_v9; float4 zone3_v10; float4 zone3_v11;
float4 zone3_v12; float4 zone3_v13; float4 zone3_v14; float4 zone3_v15;
float4 zone3_v16; float4 zone3_v17; float4 zone3_v18; float4 zone3_v19;
float4 zone3_v20; float4 zone3_v21; float4 zone3_v22; float4 zone3_v23;
float4 zone3_v24; float4 zone3_v25; float4 zone3_v26; float4 zone3_v27;
float4 zone3_v28; float4 zone3_v29; float4 zone3_v30; float4 zone3_v31;
float4 zone4_v0; float4 zone4_v1; float4 zone4_v2; float4 zone4_v3;
float4 zone4_v4; float4 zone4_v5; float4 zone4_v6; float4 zone4_v7;
float4 zone4_v8; float4 zone4_v9; float4 zone4_v10; float4 zone4_v11;
float4 zone4_v12; float4 zone4_v13; float4 zone4_v14; float4 zone4_v15;
float4 zone4_v16; float4 zone4_v17; float4 zone4_v18; float4 zone4_v19;
float4 zone4_v20; float4 zone4_v21; float4 zone4_v22; float4 zone4_v23;
float4 zone4_v24; float4 zone4_v25; float4 zone4_v26; float4 zone4_v27;
float4 zone4_v28; float4 zone4_v29; float4 zone4_v30; float4 zone4_v31;
float4 zone5_v0; float4 zone5_v1; float4 zone5_v2; float4 zone5_v3;
float4 zone5_v4; float4 zone5_v5; float4 zone5_v6; float4 zone5_v7;
float4 zone5_v8; float4 zone5_v9; float4 zone5_v10; float4 zone5_v11;
float4 zone5_v12; float4 zone5_v13; float4 zone5_v14; float4 zone5_v15;
float4 zone5_v16; float4 zone5_v17; float4 zone5_v18; float4 zone5_v19;
float4 zone5_v20; float4 zone5_v21; float4 zone5_v22; float4 zone5_v23;
float4 zone5_v24; float4 zone5_v25; float4 zone5_v26; float4 zone5_v27;
float4 zone5_v28; float4 zone5_v29; float4 zone5_v30; float4 zone5_v31;
float4 zone6_v0; float4 zone6_v1; float4 zone6_v2; float4 zone6_v3;
float4 zone6_v4; float4 zone6_v5; float4 zone6_v6; float4 zone6_v7;
float4 zone6_v8; float4 zone6_v9; float4 zone6_v10; float4 zone6_v11;
float4 zone6_v12; float4 zone6_v13; float4 zone6_v14; float4 zone6_v15;
float4 zone6_v16; float4 zone6_v17; float4 zone6_v18; float4 zone6_v19;
float4 zone6_v20; float4 zone6_v21; float4 zone6_v22; float4 zone6_v23;
float4 zone6_v24; float4 zone6_v25; float4 zone6_v26; float4 zone6_v27;
float4 zone6_v28; float4 zone6_v29; float4 zone6_v30; float4 zone6_v31;
float4 zone7_v0; float4 zone7_v1; float4 zone7_v2; float4 zone7_v3;
float4 zone7_v4; float4 zone7_v5; float4 zone7_v6; float4 zone7_v7;
float4 zone7_v8; float4 zone7_v9; float4 zone7_v10; float4 zone7_v11;
float4 zone7_v12; float4 zone7_v13; float4 zone7_v14; float4 zone7_v15;
float4 zone7_v16; float4 zone7_v17; float4 zone7_v18; float4 zone7_v19;
float4 zone7_v20; float4 zone7_v21; float4 zone7_v22; float4 zone7_v23;
float4 zone7_v24; float4 zone7_v25; float4 zone7_v26; float4 zone7_v27;
float4 zone7_v28; float4 zone7_v29; float4 zone7_v30; float4 zone7_v31;

// ---- Zone texture inputs -------------------------------------------------------
Texture2D    zone0_tex; SamplerState sampler_zone0_tex;
Texture2D    zone1_tex; SamplerState sampler_zone1_tex;
Texture2D    zone2_tex; SamplerState sampler_zone2_tex;
Texture2D    zone3_tex; SamplerState sampler_zone3_tex;
Texture2D    zone4_tex; SamplerState sampler_zone4_tex;
Texture2D    zone5_tex; SamplerState sampler_zone5_tex;
Texture2D    zone6_tex; SamplerState sampler_zone6_tex;
Texture2D    zone7_tex; SamplerState sampler_zone7_tex;

// =============================================================================
// Helper: get a single vertex (xy) for a given zone and vertex index.
// Mirrors WGSL getVert(zoneIdx, vertIdx) but via per-zone uniform arrays.
// Odd indices take .zw of the pair, even take .xy.
// =============================================================================
float2 nm_remap_getVert(uint zoneIdx, uint vertIdx)
{
    uint pairIdx = vertIdx >> 1u;
    float4 packed;
    // Select pair slot for given zone. Hard-coded dispatch (no arrays in HLSL
    // constant buffers without explicit stride).
    // TODO(verify): confirm MaterialPropertyBlock correctly sets per-zone uniforms
    if (zoneIdx == 0u) {
        [branch] switch (pairIdx) {
            case 0: packed = zone0_v0; break; case 1: packed = zone0_v1; break;
            case 2: packed = zone0_v2; break; case 3: packed = zone0_v3; break;
            case 4: packed = zone0_v4; break; case 5: packed = zone0_v5; break;
            case 6: packed = zone0_v6; break; case 7: packed = zone0_v7; break;
            case 8: packed = zone0_v8; break; case 9: packed = zone0_v9; break;
            case 10: packed = zone0_v10; break; case 11: packed = zone0_v11; break;
            case 12: packed = zone0_v12; break; case 13: packed = zone0_v13; break;
            case 14: packed = zone0_v14; break; case 15: packed = zone0_v15; break;
            case 16: packed = zone0_v16; break; case 17: packed = zone0_v17; break;
            case 18: packed = zone0_v18; break; case 19: packed = zone0_v19; break;
            case 20: packed = zone0_v20; break; case 21: packed = zone0_v21; break;
            case 22: packed = zone0_v22; break; case 23: packed = zone0_v23; break;
            case 24: packed = zone0_v24; break; case 25: packed = zone0_v25; break;
            case 26: packed = zone0_v26; break; case 27: packed = zone0_v27; break;
            case 28: packed = zone0_v28; break; case 29: packed = zone0_v29; break;
            case 30: packed = zone0_v30; break; default: packed = zone0_v31; break;
        }
    } else if (zoneIdx == 1u) {
        [branch] switch (pairIdx) {
            case 0: packed = zone1_v0; break; case 1: packed = zone1_v1; break;
            case 2: packed = zone1_v2; break; case 3: packed = zone1_v3; break;
            case 4: packed = zone1_v4; break; case 5: packed = zone1_v5; break;
            case 6: packed = zone1_v6; break; case 7: packed = zone1_v7; break;
            case 8: packed = zone1_v8; break; case 9: packed = zone1_v9; break;
            case 10: packed = zone1_v10; break; case 11: packed = zone1_v11; break;
            case 12: packed = zone1_v12; break; case 13: packed = zone1_v13; break;
            case 14: packed = zone1_v14; break; case 15: packed = zone1_v15; break;
            case 16: packed = zone1_v16; break; case 17: packed = zone1_v17; break;
            case 18: packed = zone1_v18; break; case 19: packed = zone1_v19; break;
            case 20: packed = zone1_v20; break; case 21: packed = zone1_v21; break;
            case 22: packed = zone1_v22; break; case 23: packed = zone1_v23; break;
            case 24: packed = zone1_v24; break; case 25: packed = zone1_v25; break;
            case 26: packed = zone1_v26; break; case 27: packed = zone1_v27; break;
            case 28: packed = zone1_v28; break; case 29: packed = zone1_v29; break;
            case 30: packed = zone1_v30; break; default: packed = zone1_v31; break;
        }
    } else if (zoneIdx == 2u) {
        [branch] switch (pairIdx) {
            case 0: packed = zone2_v0; break; case 1: packed = zone2_v1; break;
            case 2: packed = zone2_v2; break; case 3: packed = zone2_v3; break;
            case 4: packed = zone2_v4; break; case 5: packed = zone2_v5; break;
            case 6: packed = zone2_v6; break; case 7: packed = zone2_v7; break;
            case 8: packed = zone2_v8; break; case 9: packed = zone2_v9; break;
            case 10: packed = zone2_v10; break; case 11: packed = zone2_v11; break;
            case 12: packed = zone2_v12; break; case 13: packed = zone2_v13; break;
            case 14: packed = zone2_v14; break; case 15: packed = zone2_v15; break;
            case 16: packed = zone2_v16; break; case 17: packed = zone2_v17; break;
            case 18: packed = zone2_v18; break; case 19: packed = zone2_v19; break;
            case 20: packed = zone2_v20; break; case 21: packed = zone2_v21; break;
            case 22: packed = zone2_v22; break; case 23: packed = zone2_v23; break;
            case 24: packed = zone2_v24; break; case 25: packed = zone2_v25; break;
            case 26: packed = zone2_v26; break; case 27: packed = zone2_v27; break;
            case 28: packed = zone2_v28; break; case 29: packed = zone2_v29; break;
            case 30: packed = zone2_v30; break; default: packed = zone2_v31; break;
        }
    } else if (zoneIdx == 3u) {
        [branch] switch (pairIdx) {
            case 0: packed = zone3_v0; break; case 1: packed = zone3_v1; break;
            case 2: packed = zone3_v2; break; case 3: packed = zone3_v3; break;
            case 4: packed = zone3_v4; break; case 5: packed = zone3_v5; break;
            case 6: packed = zone3_v6; break; case 7: packed = zone3_v7; break;
            case 8: packed = zone3_v8; break; case 9: packed = zone3_v9; break;
            case 10: packed = zone3_v10; break; case 11: packed = zone3_v11; break;
            case 12: packed = zone3_v12; break; case 13: packed = zone3_v13; break;
            case 14: packed = zone3_v14; break; case 15: packed = zone3_v15; break;
            case 16: packed = zone3_v16; break; case 17: packed = zone3_v17; break;
            case 18: packed = zone3_v18; break; case 19: packed = zone3_v19; break;
            case 20: packed = zone3_v20; break; case 21: packed = zone3_v21; break;
            case 22: packed = zone3_v22; break; case 23: packed = zone3_v23; break;
            case 24: packed = zone3_v24; break; case 25: packed = zone3_v25; break;
            case 26: packed = zone3_v26; break; case 27: packed = zone3_v27; break;
            case 28: packed = zone3_v28; break; case 29: packed = zone3_v29; break;
            case 30: packed = zone3_v30; break; default: packed = zone3_v31; break;
        }
    } else if (zoneIdx == 4u) {
        [branch] switch (pairIdx) {
            case 0: packed = zone4_v0; break; case 1: packed = zone4_v1; break;
            case 2: packed = zone4_v2; break; case 3: packed = zone4_v3; break;
            case 4: packed = zone4_v4; break; case 5: packed = zone4_v5; break;
            case 6: packed = zone4_v6; break; case 7: packed = zone4_v7; break;
            case 8: packed = zone4_v8; break; case 9: packed = zone4_v9; break;
            case 10: packed = zone4_v10; break; case 11: packed = zone4_v11; break;
            case 12: packed = zone4_v12; break; case 13: packed = zone4_v13; break;
            case 14: packed = zone4_v14; break; case 15: packed = zone4_v15; break;
            case 16: packed = zone4_v16; break; case 17: packed = zone4_v17; break;
            case 18: packed = zone4_v18; break; case 19: packed = zone4_v19; break;
            case 20: packed = zone4_v20; break; case 21: packed = zone4_v21; break;
            case 22: packed = zone4_v22; break; case 23: packed = zone4_v23; break;
            case 24: packed = zone4_v24; break; case 25: packed = zone4_v25; break;
            case 26: packed = zone4_v26; break; case 27: packed = zone4_v27; break;
            case 28: packed = zone4_v28; break; case 29: packed = zone4_v29; break;
            case 30: packed = zone4_v30; break; default: packed = zone4_v31; break;
        }
    } else if (zoneIdx == 5u) {
        [branch] switch (pairIdx) {
            case 0: packed = zone5_v0; break; case 1: packed = zone5_v1; break;
            case 2: packed = zone5_v2; break; case 3: packed = zone5_v3; break;
            case 4: packed = zone5_v4; break; case 5: packed = zone5_v5; break;
            case 6: packed = zone5_v6; break; case 7: packed = zone5_v7; break;
            case 8: packed = zone5_v8; break; case 9: packed = zone5_v9; break;
            case 10: packed = zone5_v10; break; case 11: packed = zone5_v11; break;
            case 12: packed = zone5_v12; break; case 13: packed = zone5_v13; break;
            case 14: packed = zone5_v14; break; case 15: packed = zone5_v15; break;
            case 16: packed = zone5_v16; break; case 17: packed = zone5_v17; break;
            case 18: packed = zone5_v18; break; case 19: packed = zone5_v19; break;
            case 20: packed = zone5_v20; break; case 21: packed = zone5_v21; break;
            case 22: packed = zone5_v22; break; case 23: packed = zone5_v23; break;
            case 24: packed = zone5_v24; break; case 25: packed = zone5_v25; break;
            case 26: packed = zone5_v26; break; case 27: packed = zone5_v27; break;
            case 28: packed = zone5_v28; break; case 29: packed = zone5_v29; break;
            case 30: packed = zone5_v30; break; default: packed = zone5_v31; break;
        }
    } else if (zoneIdx == 6u) {
        [branch] switch (pairIdx) {
            case 0: packed = zone6_v0; break; case 1: packed = zone6_v1; break;
            case 2: packed = zone6_v2; break; case 3: packed = zone6_v3; break;
            case 4: packed = zone6_v4; break; case 5: packed = zone6_v5; break;
            case 6: packed = zone6_v6; break; case 7: packed = zone6_v7; break;
            case 8: packed = zone6_v8; break; case 9: packed = zone6_v9; break;
            case 10: packed = zone6_v10; break; case 11: packed = zone6_v11; break;
            case 12: packed = zone6_v12; break; case 13: packed = zone6_v13; break;
            case 14: packed = zone6_v14; break; case 15: packed = zone6_v15; break;
            case 16: packed = zone6_v16; break; case 17: packed = zone6_v17; break;
            case 18: packed = zone6_v18; break; case 19: packed = zone6_v19; break;
            case 20: packed = zone6_v20; break; case 21: packed = zone6_v21; break;
            case 22: packed = zone6_v22; break; case 23: packed = zone6_v23; break;
            case 24: packed = zone6_v24; break; case 25: packed = zone6_v25; break;
            case 26: packed = zone6_v26; break; case 27: packed = zone6_v27; break;
            case 28: packed = zone6_v28; break; case 29: packed = zone6_v29; break;
            case 30: packed = zone6_v30; break; default: packed = zone6_v31; break;
        }
    } else {
        [branch] switch (pairIdx) {
            case 0: packed = zone7_v0; break; case 1: packed = zone7_v1; break;
            case 2: packed = zone7_v2; break; case 3: packed = zone7_v3; break;
            case 4: packed = zone7_v4; break; case 5: packed = zone7_v5; break;
            case 6: packed = zone7_v6; break; case 7: packed = zone7_v7; break;
            case 8: packed = zone7_v8; break; case 9: packed = zone7_v9; break;
            case 10: packed = zone7_v10; break; case 11: packed = zone7_v11; break;
            case 12: packed = zone7_v12; break; case 13: packed = zone7_v13; break;
            case 14: packed = zone7_v14; break; case 15: packed = zone7_v15; break;
            case 16: packed = zone7_v16; break; case 17: packed = zone7_v17; break;
            case 18: packed = zone7_v18; break; case 19: packed = zone7_v19; break;
            case 20: packed = zone7_v20; break; case 21: packed = zone7_v21; break;
            case 22: packed = zone7_v22; break; case 23: packed = zone7_v23; break;
            case 24: packed = zone7_v24; break; case 25: packed = zone7_v25; break;
            case 26: packed = zone7_v26; break; case 27: packed = zone7_v27; break;
            case 28: packed = zone7_v28; break; case 29: packed = zone7_v29; break;
            case 30: packed = zone7_v30; break; default: packed = zone7_v31; break;
        }
    }
    return ((vertIdx & 1u) == 0u) ? packed.xy : packed.zw;
}

// =============================================================================
// nm_remap_getZoneMeta: returns (vertexCount, active, _, alpha) for zone z.
// Mirrors WGSL getZoneMeta(z) -> uniforms.data[2+z].
// =============================================================================
float4 nm_remap_getZoneMeta(uint z)
{
    [branch] switch (z) {
        case 0u: return float4(zone0_count, zone0_active, 0.0, zone0_alpha);
        case 1u: return float4(zone1_count, zone1_active, 0.0, zone1_alpha);
        case 2u: return float4(zone2_count, zone2_active, 0.0, zone2_alpha);
        case 3u: return float4(zone3_count, zone3_active, 0.0, zone3_alpha);
        case 4u: return float4(zone4_count, zone4_active, 0.0, zone4_alpha);
        case 5u: return float4(zone5_count, zone5_active, 0.0, zone5_alpha);
        case 6u: return float4(zone6_count, zone6_active, 0.0, zone6_alpha);
        default: return float4(zone7_count, zone7_active, 0.0, zone7_alpha);
    }
}

// =============================================================================
// nm_remap_getZoneBounds: returns [minX,minY,maxX,maxY] for zone z (NEW,
// reference 0ed489ec). Mirrors WGSL uniforms.data[ZONE_BOUNDS_SLOT + z].
// =============================================================================
float4 nm_remap_getZoneBounds(uint z)
{
    [branch] switch (z) {
        case 0u: return zone0_bounds;
        case 1u: return zone1_bounds;
        case 2u: return zone2_bounds;
        case 3u: return zone3_bounds;
        case 4u: return zone4_bounds;
        case 5u: return zone5_bounds;
        case 6u: return zone6_bounds;
        default: return zone7_bounds;
    }
}

// =============================================================================
// nm_remap_sampleZone: sample zone z at tile-local UV with explicit LOD 0.
// Mirrors WGSL sampleZone(z, uv) using textureSampleLevel(…, 0.0).
// SampleLevel avoids implicit-derivative requirement in non-uniform control flow.
// =============================================================================
float4 nm_remap_sampleZone(uint z, float2 uv)
{
    [branch] if (z == 0u) return zone0_tex.SampleLevel(sampler_zone0_tex, uv, 0.0);
    [branch] if (z == 1u) return zone1_tex.SampleLevel(sampler_zone1_tex, uv, 0.0);
    [branch] if (z == 2u) return zone2_tex.SampleLevel(sampler_zone2_tex, uv, 0.0);
    [branch] if (z == 3u) return zone3_tex.SampleLevel(sampler_zone3_tex, uv, 0.0);
    [branch] if (z == 4u) return zone4_tex.SampleLevel(sampler_zone4_tex, uv, 0.0);
    [branch] if (z == 5u) return zone5_tex.SampleLevel(sampler_zone5_tex, uv, 0.0);
    [branch] if (z == 6u) return zone6_tex.SampleLevel(sampler_zone6_tex, uv, 0.0);
    return zone7_tex.SampleLevel(sampler_zone7_tex, uv, 0.0);
}

// =============================================================================
// Reference 0ed489ec: full rewrite of the compositing algorithm. Per zone, ONE
// walk over the polygon vertices evaluates the even-odd inside test AND the
// squared pixel distance to the boundary together (testEdge/walkZone), instead
// of two separate passes (the old nm_remap_pointInZone/distToZoneEdge, removed).
// Ported verbatim from wgsl/remap.wgsl's ZoneTest/testEdge/walkZone.
// =============================================================================
struct NM_RemapZoneTest
{
    bool  inside; // even-odd crossing parity
    float d2;     // squared pixel distance to the nearest boundary point
};

// Folds the edge between vertex `a` and its predecessor `b` into `t`. All
// positions are GLOBAL PIXEL coordinates (top-left origin).
NM_RemapZoneTest nm_remap_testEdge(NM_RemapZoneTest t, float2 a, float2 b, float2 q, bool needDist)
{
    float2 e = b - a;
    float2 w = q - a;
    // Even-odd crossing count along the +x ray from q, branch-free. The
    // half-open scanline rule keeps an edge shared by two zones unambiguous.
    bool3 c = bool3((q.y >= a.y), (q.y < b.y), (e.x * w.y > e.y * w.x));
    if (all(c) || !any(c)) { t.inside = !t.inside; }
    if (needDist)
    {
        float s = clamp(dot(w, e) / max(dot(e, e), 1e-6), 0.0, 1.0);
        float2 r = w - e * s;
        t.d2 = min(t.d2, dot(r, r));
    }
    return t;
}

// Walks one zone's vertices (global pixel space, un-normalized here from the
// per-effect [0,1]-packed uniforms) and returns the inside parity plus the
// squared pixel distance to the boundary. `needDist` is a per-frame constant
// (derived from smoothEdge), so the smoothEdge-0 walk carries no distance math.
NM_RemapZoneTest nm_remap_walkZone(uint zoneIdx, int n, float2 q, bool needDist)
{
    NM_RemapZoneTest t;
    t.inside = false;
    t.d2 = 1e30;
    float2 prev = nm_remap_getVert(zoneIdx, (uint)(n - 1)) * fullResolution;
    [loop]
    for (uint i = 0u; i < 64u; i = i + 1u)
    {
        if ((int)i >= n) { break; }
        float2 cur = nm_remap_getVert(zoneIdx, i) * fullResolution;
        t = nm_remap_testEdge(t, cur, prev, q, needDist);
        prev = cur;
    }
    return t;
}

// =============================================================================
// nm_remap — main per-pixel function.
// fragCoord: NM_FragCoord(i) = pixel-centered tile-local coord (top-left, +0.5)
// Mirrors WGSL fragmentMain() exactly (reference 0ed489ec full rewrite):
// zones are composited TOP-DOWN (last active/highest index wins), zone
// coverage is 1 everywhere inside its polygon and feathers OUTWARD (never
// erodes the interior), a host-supplied bounding box skips zones the pixel
// cannot touch, and sources are premultiplied and stacked with the
// premultiplied "under" operator.
// =============================================================================
float4 nm_remap(float2 fragCoord)
{
    // Polygon tests use the GLOBAL pixel position so zones land in the same
    // image position regardless of which tile is rendering. This Y flip is
    // NOT a WGSL/HLSL top-left-origin reconciliation (golden rule #1 does not
    // apply here) — it is baked into the reference algorithm itself, required
    // on every backend to match the pinned byte-identical golden. Reproduced
    // verbatim: globalPx = fragCoord + tileOffset; q = (globalPx.x,
    // fullResolution.y - globalPx.y); p = q / fullResolution.
    float2 globalPx = fragCoord + tileOffset;
    float2 q = float2(globalPx.x, fullResolution.y - globalPx.y);
    float2 p = q / fullResolution;
    // Texture sampling stays TILE-LOCAL: each zoneN_tex is the current tile's
    // slice of its source surface, so sample at the tile-local pixel position.
    float2 sampleUv = fragCoord / resolution;

    float4 header = float4(bgColor, bgAlpha);
    int activeCount = min(zoneCount, 8);
    // Feather width in pixels, proportional to the shorter canvas side, so it
    // is the same width on both axes whatever the aspect ratio. smoothEdge is
    // clamped at 0: an automated negative value would otherwise make the
    // bounds dilation negative and SHRINK every zone's reject box.
    float featherPx = max(smoothEdge, 0.0) * 0.05 * min(fullResolution.x, fullResolution.y);
    bool needDist = featherPx > 0.0;
    float2 dilate = (float2)featherPx / fullResolution; // feather in normalized units per axis

    float4 result = float4(0.0, 0.0, 0.0, 0.0);
    [loop]
    for (int k = 0; k < 8; k = k + 1)
    {
        int z = activeCount - 1 - k; // top-down: highest index first
        if (z < 0) { break; }
        float4 zoneMeta = nm_remap_getZoneMeta((uint)z);
        // Clamped: a host-supplied count above the per-zone capacity would
        // otherwise walk past this zone's slots into the next zone's.
        int n = min((int)zoneMeta.x, 64);
        if (n < 3 || zoneMeta.y < 0.5) { continue; } // degenerate, or source not wired
        // Host-supplied bounding box, dilated by the feather. Default
        // [0,0,1,1] never rejects a canvas pixel.
        float4 bounds = nm_remap_getZoneBounds((uint)z);
        if (any(p < bounds.xy - dilate) || any(p > bounds.zw + dilate)) { continue; }

        NM_RemapZoneTest t = nm_remap_walkZone((uint)z, n, q, needDist);

        float coverage = 1.0;
        if (!t.inside)
        {
            if (!needDist) { continue; }
            coverage = 1.0 - smoothstep(0.0, featherPx, sqrt(t.d2));
            if (coverage <= 0.0) { continue; }
        }
        // Premultiplied "under": this zone is above everything still to come.
        float4 src = nm_remap_sampleZone((uint)z, sampleUv) * (coverage * zoneMeta.w);
        result = result + src * (1.0 - result.a);
        if (result.a >= 0.999) { break; }
    }
    // Background goes under whatever the zones left uncovered.
    result = result + float4(header.rgb * header.a, header.a) * (1.0 - result.a);

    return result;
}

#endif // NM_REMAP_INCLUDED
