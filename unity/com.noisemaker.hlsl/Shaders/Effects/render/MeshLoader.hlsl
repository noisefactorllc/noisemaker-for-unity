#ifndef NM_EFFECT_MESHLOADER_INCLUDED
#define NM_EFFECT_MESHLOADER_INCLUDED

// =============================================================================
// MeshLoader.hlsl — render/meshLoader (func: "meshLoader")
//
// Load OBJ mesh data into GPU textures, then visualize it. Ported
// PIXEL-IDENTICALLY from the canonical WGSL source (top-left origin, no
// per-effect Y flip):
//   wgsl/preview.wgsl   progName "preview"   (frag_preview)
//
// 3D / MESH TIER — surfaces used:
//   global_mesh0_positions, global_mesh0_normals (and _uvs) — the mesh0 SURFACE
//     TRIPLET (each 256x256, rgba32f): positions(xyz worldpos, w=valid flag),
//     normals(xyz, w unused), uvs(uv, zw unused). See reference 04 §8. These are
//     NOT ping-pong; they hold STATIC vertex data uploaded CPU-side by the
//     runtime's uploadMeshData() (the demo UI calls loadOBJFromURL, the effect
//     declares externalMesh="mesh0"). meshLoader itself runs NO geometry pass;
//     it only previews the already-uploaded mesh data textures. Downstream
//     meshRender rasterizes the triplet via DrawProcedural over SV_VertexID.
//
// The single 'preview' pass is a plain FULLSCREEN fragment program: it samples
// global_mesh0_positions / global_mesh0_normals and visualizes them (left half
// of the image = positions remapped -1..1 -> 0..1; right half = normals).
//
// NOTE: this effect ships as a runtime-rendered Texture2D (mesh/3D tier, depends
// on a CPU-side mesh upload). No Shader Graph Custom Function wrapper is provided
// (Shader Graph cannot drive the mesh-data upload or the surface-triplet binding).
//
// PORTING-GUIDE / parity notes:
//  * WebGL2 and WGSL sample packed mesh textures with local pixel coordinates
//    normalized by each texture's dimensions. Only the split uses global UV.
//  * fragCoord = position.xy (@builtin(position), top-left, +0.5 centered) ->
//    NM_FragCoord(i). globalCoord = fragCoord + tileOffset -> NM_GlobalCoord(i).
//  * textureSample(t, s, uv) -> t.Sample(sampler_t, uv) (bilinear, clamp-to-edge,
//    non-sRGB). The mesh textures are rgba32f; sampling is exact at texel centers.
//  * No helpers from NMCore are used (no pcg/prng/random/nm_mod). No nm_mod needed.
//  * vec3<f32> color built then returned as vec4(color, 1.0).
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// ---- Mesh-data input samplers (rgba32f mesh0 surface triplet) ----------------
// The runtime binds these per pass per definition.js inputs{}:
//   positionsTex == global_mesh0_positions  (xyz worldpos, w=valid)
//   normalsTex   == global_mesh0_normals    (xyz normal,   w unused)
Texture2D    positionsTex;   SamplerState sampler_positionsTex;
Texture2D    normalsTex;     SamplerState sampler_normalsTex;

// meshLoader declares NO named scalar uniforms (definition.js globals = {}).
// Only the engine globals (resolution/tileOffset/fullResolution) are used, and
// those come from NMFullscreen.hlsl.

// =============================================================================
// preview — progName "preview" (passes[0])
// =============================================================================
float4 frag_preview(NMVaryings i) : SV_Target
{
    float2 fullRes = fullResolution.x > 0.0 ? fullResolution : resolution;
    float2 globalUV = NM_GlobalCoord(i) / fullRes;
    float2 pixel = NM_FragCoord(i);
    uint positionWidth, positionHeight, normalWidth, normalHeight;
    positionsTex.GetDimensions(positionWidth, positionHeight);
    normalsTex.GetDimensions(normalWidth, normalHeight);
    float4 pos = positionsTex.Sample(sampler_positionsTex, pixel / float2(positionWidth, positionHeight));
    float4 normal = normalsTex.Sample(sampler_normalsTex, pixel / float2(normalWidth, normalHeight));

    float3 color;
    if (globalUV.x < 0.5)
    {
        // Position visualization: map -1..1 to 0..1
        color = pos.xyz * 0.5 + 0.5;
    }
    else
    {
        // Normal visualization: map -1..1 to 0..1
        color = normal.xyz * 0.5 + 0.5;
    }

    return float4(color, 1.0);
}

#endif // NM_EFFECT_MESHLOADER_INCLUDED
