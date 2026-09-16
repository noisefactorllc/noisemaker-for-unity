#ifndef NM_EFFECT_POINTSBILLBOARDRENDER_INCLUDED
#define NM_EFFECT_POINTSBILLBOARDRENDER_INCLUDED

// =============================================================================
// PointsBillboardRender.hlsl — render/pointsBillboardRender
//   (func: "pointsBillboardRender") — draw particle agents as camera-facing
//   billboard sprite quads (SDF shapes or a sprite texture).
//
// AGENT VISUALIZER / multi-pass FEEDBACK effect (3D/RENDER tier). Ported
// PIXEL-IDENTICALLY from the canonical WGSL sources (top-left origin, no
// per-effect Y flip; golden rule #1):
//   wgsl/diffuse.wgsl   progName "diffuse"   (frag_diffuse)          fullscreen
//   wgsl/copy.wgsl      progName "copy"      (frag_copy)             fullscreen
//   wgsl/deposit.wgsl   progName "deposit"   (vert/frag_deposit)     BILLBOARD scatter
//   wgsl/blend.wgsl     progName "blend"     (frag_blend)            fullscreen
//
// PASS ORDER per frame (4) — from definition.js passes[]:
//   1. diffuse  (program "diffuse",  fullscreen)            decay the trail
//                                                           (persistence = intensity)
//   2. copy     (program "copy",     fullscreen)            blit decayed trail to the
//                                                           write buffer before deposit
//   3. deposit  (program "deposit",  BILLBOARDS scatter)    Blend One One — additive
//                                                           scatter of agent billboards
//   4. blend    (program "blend",    fullscreen)            alpha-composite trail over
//                                                           the scaled pipeline input
//
// SURFACES:
//   global_xyz  (rgba32f) — [x, y, z, alive] agent positions. Produced upstream
//       by pointsEmit (sized stateSize x stateSize); consumed (Load) by the deposit
//       VERTEX stage. NOT written here (read-only). isStateSurface (suffix '_xyz').
//   global_rgba (rgba32f) — [r, g, b, a] agent color (from pointsEmit). Read (Load)
//       by the deposit VERTEX stage. isStateSurface (suffix '_rgba'). read-only.
//   global_billboard_trail (rgba16f, 100%) — PERSISTENT private accumulation trail:
//       decayed by diffuse, copied by copy, additively deposited into by deposit
//       (Blend One One), composited with input by blend. Reads its own prior
//       'global_' output so it persists frame-to-frame (runtime double-buffers /
//       ping-pongs; reference 04 §10.2/§10.7). NOT an isStateSurface (no
//       _xyz/_vel/_rgba suffix, no 'state').
//
// NOTE: multi-pass / agent-visualizer effect → ships as a runtime-rendered
// Texture2D. NO Shader Graph Custom Function wrapper (3D / multi-pass / geometry
// per PORTING-GUIDE). The C# runtime drives the 4 passes in order, rebinding
// read/write targets per pass and issuing DrawProcedural(Triangles, count*6) for
// the deposit billboard scatter (count = stateSize*stateSize from xyzTex dims;
// 6 verts = 2 triangles per quad).
//
// PORTING-GUIDE / parity notes:
//  * WGSL textureLoad(t, coord, 0) → t.Load(int3(coord, 0)) — integer texel fetch,
//    point, no filtering. Agent state (xyz/rgba) is read this way in the VERTEX
//    stage (SM4.5 permits VS texture Load). rgba32f.
//  * WGSL textureSample(t, s, uv) → t.Sample(sampler_t, uv) — linear, clamp,
//    non-sRGB. Used by diffuse/copy/blend (UV blit) and the deposit sprite sample.
//  * fragCoord = @builtin(position).xy (top-left, +0.5 centered) → NM_FragCoord(i).
//    diffuse/copy/blend derive uv = fragCoord / u.resolution (the resolution
//    UNIFORM == render-target size). Reproduced literally.
//  * fract→frac, mix→lerp, clamp/cos/sin/length/dot/smoothstep/exp/sign map 1:1.
//    nm_mod / fmod NOT used. Integer particle id math uses HLSL int '%' and '/'
//    (truncation toward 0), matching WGSL i32 %  / on non-negative ids exactly.
//  * pbr_hash() is this effect's OWN PCG integer hash (NOT NMCore) — reference
//    v1.0.79 replaced the old fract(sin) hash. GLSL floatBitsToUint -> HLSL asuint;
//    seed is a float uniform (runtime injects the int value as a float; identical).
//  * Quad clip transform & per-particle size/rotation reproduced exactly from
//    deposit.wgsl (top-left clip, no Y flip; off-screen cull writes (2,2,0,1)).
//  * The 2D/3D viewMode branch (rotateX/Y/Z, is2DSystem detection, ortho scale)
//    is reproduced literally from deposit.wgsl.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// ---- Textures (runtime rebinds per pass per definition.js inputs{}) ---------
// diffuse: trailTex (Sample)
// copy:    sourceTex (Sample)  -- bound to global_billboard_trail
// deposit: xyzTex,rgbaTex (Load, in VERTEX stage); spriteTex (Sample, in FRAGMENT)
// blend:   inputTex,trailTex (Sample)
Texture2D xyzTex;     SamplerState sampler_xyzTex;
Texture2D rgbaTex;    SamplerState sampler_rgbaTex;
Texture2D spriteTex;  SamplerState sampler_spriteTex;
Texture2D trailTex;   SamplerState sampler_trailTex;
Texture2D sourceTex;  SamplerState sampler_sourceTex;
Texture2D inputTex;   SamplerState sampler_inputTex;
// NEW this round (reference 0ed489ec): orderTex feeds the alpha-blend depth-sort
// reindex (deposit VS); spriteMeanTex/tilesTex/defocusTex feed the aperture
// defocus precompute chain (depthKeys/depthMerge -> spriteMeanTiles/spriteMean ->
// deposit FS -> diffuse composite).
Texture2D orderTex;      SamplerState sampler_orderTex;
Texture2D spriteMeanTex; SamplerState sampler_spriteMeanTex;
Texture2D tilesTex;      SamplerState sampler_tilesTex;
Texture2D defocusTex;    SamplerState sampler_defocusTex;

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) -----
int   shapeMode;        // globals.shapeMode      default 1 (circle)
float depositOpacity;   // globals.depositOpacity default 20
float density;          // globals.density        default 50
float pointSize;        // globals.pointSize      default 8
float sizeVariation;    // globals.sizeVariation  default 0
float rotationVar;      // globals.rotationVar    default 0 (alias rotationVariation)
float seed;             // globals.seed           default 42 (typed int; injected as float)
float rotateX;          // globals.rotateX        default 0.3
float rotateY;          // globals.rotateY        default 0
float rotateZ;          // globals.rotateZ        default 0
float viewScale;        // globals.viewScale      default 0.8
float posX;             // globals.posX           default 0
float posY;             // globals.posY           default 0
float intensity;        // globals.intensity      default 75
float inputIntensity;   // globals.inputIntensity default 10.15
// VIEW_MODE/BLEND_MODE/BLUR_LAYER (reference 0ed489ec): the deposit/depthKeys
// pass CLONES (the round's `.flatMap()` per-viewMode/blendMode/blurLayer-clone
// pattern) carry these as compile-time-selector defines, bound as SetInt via
// pass.Defines. The single, non-cloned diffuse/blend passes instead read the
// ordinary lowercase runtime uniforms below (viewMode/blendMode) — same names
// as before this round, still real per-frame values, NOT defines.
int   VIEW_MODE;
int   BLEND_MODE;
int   BLUR_LAYER;
int   viewMode;          // diffuse pass only — see comment above
int   blendMode;         // diffuse + blend passes only — see comment above
// NEW this round: perspective camera + distance fade + aperture defocus params.
float posZ;               // globals.posZ               default 0
float fieldOfView;        // globals.fieldOfView        default 60
float sizeDistance;       // globals.sizeDistance       default 0
float brightnessDistance; // globals.brightnessDistance default 0
float aperture;           // globals.aperture           default 0
float focalDistance;      // globals.focalDistance      default 80
// depthMerge (new program, per-clone literal pass uniform, one of 22 clones with
// runLength = 1,2,4,...,4194304): int carried via SetFloat, matches the ordinary
// numeric-uniform binding model (not a SetInt define).
float runLength;
// clearDefocus (new program): literal 0 per its single pass instance.
float clearValue;

// nm_sampleDefocus — bilinear upsample of the quarter-resolution defocus
// accumulation target (reference 0ed489ec). Internal targets use nearest
// sampling, so interpolate all four channels explicitly.
float4 nm_sampleDefocus(float2 uv)
{
    uint dw, dh;
    defocusTex.GetDimensions(dw, dh);
    int2 dims = int2((int)dw, (int)dh);
    float2 p = uv * float2(dims) - 0.5;
    int2 lo = int2(floor(p));
    float2 f = frac(p);
    int2 a = clamp(lo, int2(0, 0), dims - 1);
    int2 b = clamp(lo + int2(1, 1), int2(0, 0), dims - 1);
    return lerp(
        lerp(defocusTex.Load(int3(a, 0)), defocusTex.Load(int3(b.x, a.y, 0)), f.x),
        lerp(defocusTex.Load(int3(a.x, b.y, 0)), defocusTex.Load(int3(b, 0)), f.x), f.y);
}

// =============================================================================
// PASS 1: diffuse — decay the existing trail (frag_diffuse, fullscreen).
//   WGSL: decay = clamp(intensity/100, 0, 1); return trailColor * decay.
//   Reference 0ed489ec adds: in additive mode (blendMode==0) with a
//   perspective/ortho view and nonzero aperture, add in the defocus
//   accumulation target built by the additive-mode deposit passes.
// =============================================================================
float4 frag_diffuse(NMVaryings i) : SV_Target
{
    float2 uv = NM_FragCoord(i) / resolution;

    // Sample the trail texture directly (no blur).
    float4 trailColor = trailTex.Sample(sampler_trailTex, uv);

    // Apply intensity decay (persistence). intensity=100 → no decay, 0 → instant fade.
    // Clamp to [0,1] each frame to bound unbounded HDR accumulation via additive
    // deposit blending; also keeps the alpha-composite math stable when trail alpha
    // would exceed 1.0 (reference a0d8ea14).
    float decay = clamp(intensity / 100.0, 0.0, 1.0);
    float4 outColor = clamp(trailColor * decay, 0.0, 1.0);
    // Real per-frame uniforms here (not the deposit/depthKeys clones' defines) —
    // this is the single, non-cloned diffuse pass.
    if (blendMode == 0 && aperture > 0.0 && viewMode != 0)
    {
        outColor += nm_sampleDefocus(uv);
    }
    return outColor;
}

// =============================================================================
// PASS 2: copy — blit source to destination (frag_copy, fullscreen).
//   WGSL: uv = position.xy / resolution; return textureSample(sourceTex, s, uv).
// =============================================================================
float4 frag_copy(NMVaryings i) : SV_Target
{
    float2 uv = NM_FragCoord(i) / resolution;
    return sourceTex.Sample(sampler_sourceTex, uv);
}

// =============================================================================
// PASS 3: deposit — BILLBOARD scatter (Blend One One additive).
//
// Custom vertex stage: 6 vertices (two triangles) per agent. count =
// stateSize*stateSize so the runtime issues DrawProcedural(Triangles, count*6).
// Reads agent state in the VERTEX stage via Texture2D.Load (SM4.5). Emits a
// camera-facing quad with per-particle size/rotation variation and a sprite UV
// varying consumed by the fragment SDF/texture stage.
//
// Ported verbatim from deposit.wgsl (vertexMain/fragmentMain).
// =============================================================================
struct PBRDepositVaryings
{
    float4 positionCS : SV_POSITION;
    float4 color      : TEXCOORD0;
    float2 spriteUV   : TEXCOORD1;
    float  blurRadius : TEXCOORD2; // NEW (reference 0ed489ec): aperture defocus radius
};

// Deterministic per-particle PCG hash (this effect's OWN). Reference a27bf823 /
// v1.0.79 replaced the old fract(sin(n+seed)*43758) transcendental hash — which
// diverges across GPUs (fast-math sin) — with a portable integer PCG hash.
// GLSL floatBitsToUint -> HLSL asuint; the uint ops map 1:1. `seed` is a float
// uniform (typed int, injected as float), matching GLSL `uniform float seed`.
uint pbr_hash_uint(uint s)
{
    uint state = s * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}
float pbr_hash(float n)
{
    return (float)pbr_hash_uint(asuint(n + seed)) / 4294967295.0;
}

PBRDepositVaryings vert_deposit(uint vertexID : SV_VertexID)
{
    PBRDepositVaryings o;
    o.blurRadius = 0.0;

    // NEW this round: the low-blur-radius defocus layer draws nothing at all when
    // aperture is off (matches the reference's `#if BLUR_LAYER == 1` guard — this
    // port has no compile-time shader variants, so it's a plain runtime branch).
    if (BLUR_LAYER == 1 && aperture <= 0.0)
    {
        o.positionCS = float4(2.0, 2.0, 0.0, 1.0);
        o.color      = float4(0.0, 0.0, 0.0, 0.0);
        o.spriteUV   = float2(0.0, 0.0);
        return o;
    }

    // Each quad uses 6 vertices (2 triangles).
    int particleID    = (int)vertexID / 6;
    int vertexInQuad  = (int)vertexID % 6;

    // State size from xyz texture dimensions (inherited from pointsEmit).
    uint tw, th;
    xyzTex.GetDimensions(tw, th);
    int stateSize   = (int)tw;
    int totalAgents = stateSize * stateSize;

    // Cull particles beyond texture size.
    if (particleID >= totalAgents)
    {
        o.positionCS = float4(2.0, 2.0, 0.0, 1.0);
        o.color      = float4(0.0, 0.0, 0.0, 0.0);
        o.spriteUV   = float2(0.0, 0.0);
        return o;
    }

    // NEW this round: alpha-blend depth sort reindex. depthKeys+depthMerge (a
    // 22-stage bitonic-style merge sort) leave orderTex.g holding, per output
    // slot, the ORIGINAL particle index in back-to-front draw order — redirect
    // this vertex's particleID through it so the alpha-blend deposit draws in
    // sorted order instead of texel order.
    if (BLEND_MODE == 1 && VIEW_MODE != 0)
    {
        int ox = particleID % stateSize;
        int oy = particleID / stateSize;
        particleID = (int)orderTex.Load(int3(int2(ox, oy), 0)).g;
    }

    // Density-based culling.
    // PARITY (large-stateSize precision): the reference is frac(particleID*GR), GR=golden
    // ratio. At big clouds (stateSize 1024 -> 1M agents) the raw product particleID*GR
    // exceeds float32's fractional precision (step ~0.06 near 6.5e5), so frac() quantizes
    // into ~16 buckets and Metal passes ~8x too many agents vs GLSL/ANGLE — over-depositing
    // the billboard trail ~7x, which feeds garbage (HDR/out-of-[0,1]) into the write
    // surface; a downstream consumer (e.g. navierStokes reading it as a force/dye input)
    // then blows out. Compute frac(particleID*GR) precisely via a hi/lo split so the
    // product magnitudes stay small and frac is exact for IDs up to millions.
    float cullThreshold  = density / 100.0;
    float pidf   = (float)particleID;
    float pidHi  = floor(pidf / 4096.0);
    float pidLo  = pidf - pidHi * 4096.0;
    float particleRandom = frac(pidHi * frac(4096.0 * 0.618033988749895) + pidLo * 0.618033988749895);
    if (particleRandom > cullThreshold)
    {
        o.positionCS = float4(2.0, 2.0, 0.0, 1.0);
        o.color      = float4(0.0, 0.0, 0.0, 0.0);
        o.spriteUV   = float2(0.0, 0.0);
        return o;
    }

    // Texel for this particle.  WGSL: x = id % stateSize, y = id / stateSize.
    int x = particleID % stateSize;
    int y = particleID / stateSize;

    // Read particle position and color (VS Load, SM4.5, rgba32f).
    float4 pos = xyzTex.Load(int3(int2(x, y), 0));
    float4 col = rgbaTex.Load(int3(int2(x, y), 0));

    // Cull dead agents (pos.w >= 0.5 means alive).
    if (pos.w < 0.5)
    {
        o.positionCS = float4(2.0, 2.0, 0.0, 1.0);
        o.color      = float4(0.0, 0.0, 0.0, 0.0);
        o.spriteUV   = float2(0.0, 0.0);
        return o;
    }

    float2 clipPos;
    // NEW this round: camera-distance state feeds sizeFade/brightnessFade/blur.
    float cameraDepth = 80.0;
    float cameraDistance = 0.0;
    float projectedScale = 1.0;

    if (VIEW_MODE == 0)
    {
        // 2D mode: positions are normalized 0..1. No Y flip (golden rule #1).
        clipPos = pos.xy * 2.0 - 1.0;
    }
    else
    {
        // 3D mode: rotate world coordinates before camera projection.
        float3 p = pos.xyz;

        // Detect a 2D system (coords in 0-1) vs a 3D attractor (coords ±40).
        // VIEW_MODE == 1 gated (reference 0ed489ec): perspective (2) always uses
        // the raw world position, never the recentered-2D-system heuristic.
        bool is2DSystem = VIEW_MODE == 1 && abs(p.z) < 1.0 && p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0;

        if (is2DSystem)
        {
            p = float3(p.x - 0.5, p.y - 0.5, 0.0);
        }

        // Rotation around X axis.
        float cosX = cos(rotateX);
        float sinX = sin(rotateX);
        p = float3(p.x, p.y * cosX - p.z * sinX, p.y * sinX + p.z * cosX);

        // Rotation around Y axis.
        float cosY = cos(rotateY);
        float sinY = sin(rotateY);
        p = float3(p.x * cosY + p.z * sinY, p.y, -p.x * sinY + p.z * cosY);

        // Rotation around Z axis.
        float cosZ = cos(rotateZ);
        float sinZ = sin(rotateZ);
        p = float3(p.x * cosZ - p.y * sinZ, p.x * sinZ + p.y * cosZ, p.z);

        // Apply X/Y/Z offset after rotation.
        p.x = p.x + posX;
        p.y = p.y + posY;
        p.z = p.z + posZ;
        cameraDepth = 80.0 - p.z;
        cameraDistance = length(float3(p.xy, cameraDepth));

        // Perspective (VIEW_MODE == 2, NEW reference 0ed489ec). Camera at Z=80
        // looking down -Z. Reject the near plane before division.
        if (VIEW_MODE == 2)
        {
            if (cameraDepth <= 0.1)
            {
                o.positionCS = float4(2.0, 2.0, 0.0, 1.0);
                o.color      = float4(0.0, 0.0, 0.0, 0.0);
                o.spriteUV   = float2(0.0, 0.0);
                return o;
            }
            float focalLength = 1.0 / tan(clamp(fieldOfView, 10.0, 150.0) * 0.00872664626);
            clipPos = p.xy * focalLength * viewScale / cameraDepth;
            clipPos.x = clipPos.x * resolution.y / resolution.x;
            projectedScale = 80.0 * focalLength * viewScale / (1.732050808 * cameraDepth);
        }
        else if (is2DSystem)
        {
            clipPos = p.xy * 3.5 * viewScale;
        }
        else
        {
            clipPos = p.xy / 40.0 * viewScale;
        }
    }

    // Per-particle size variation (seeded deterministic).
    float sizeNoise      = pbr_hash((float)particleID);
    float sizeMultiplier = 1.0 - (sizeVariation / 100.0) * (sizeNoise - 0.5);

    // NEW this round: distance-based size/brightness fade and aperture defocus
    // blur radius, active only in a 3D view mode.
    float sizeFade = 1.0;
    float brightnessFade = 1.0;
    float blurPixels = 0.0;
    if (VIEW_MODE != 0)
    {
        if (sizeDistance > 0.0) sizeFade = 1.0 - smoothstep(0.0, sizeDistance, cameraDistance);
        if (brightnessDistance > 0.0) brightnessFade = 1.0 - smoothstep(0.0, brightnessDistance, cameraDistance);
        blurPixels = min(32.0, aperture * abs(cameraDepth - focalDistance) / max(abs(cameraDepth), 0.1));
    }
    float baseSize = pointSize * sizeMultiplier * projectedScale;
    // Textured blur integrates nodes across the whole source square. A
    // procedural footprint needs only its center's displacement as padding.
    float blurRadius = blurPixels / max(baseSize, 0.001);
    // Match the normalized fragment kernel's minimum support. Keep the
    // requested radius for interpolation and resolution-layer selection.
    float supportRadius = blurPixels > 0.0 ? max(blurRadius, 0.62582015) : 0.0;
    float supportPixels = blurPixels > 0.0 ? max(blurPixels, baseSize * 0.62582015) : 0.0;
    // Only broad, fully softened additive footprints can use the smaller
    // target. Complementary weights prevent a focus transition from popping.
    float lowWeight = BLEND_MODE == 0 ? smoothstep(4.0, 8.0, blurPixels * sizeFade) * smoothstep(0.5, 1.0, blurRadius) : 0.0;
    float layerWeight = BLUR_LAYER == 1 ? lowWeight : 1.0 - lowWeight;
    float blurPadding = blurPixels > 0.0 ? (shapeMode == 0 ? 0.5 : (shapeMode == 5 ? 0.04 : 0.0)) : 0.0;
    float finalSize = (baseSize * (1.0 + 2.0 * blurPadding) + 2.0 * supportPixels) * sizeFade;
    if (finalSize <= 0.0 || brightnessFade <= 0.0 || layerWeight <= 0.0)
    {
        o.positionCS = float4(2.0, 2.0, 0.0, 1.0);
        o.color      = float4(0.0, 0.0, 0.0, 0.0);
        o.spriteUV   = float2(0.0, 0.0);
        return o;
    }
    o.blurRadius = blurRadius;

    // Per-particle rotation (seeded deterministic).
    float rotationNoise = pbr_hash((float)particleID + 1234.5);
    float rotation      = (rotationVar / 100.0) * rotationNoise * 6.283185; // 0..2pi

    // Convert pixel size to clip-space units. resolution == render-target size.
    float2 pixelToClip = 2.0 / resolution;
    float  halfSize    = finalSize * 0.5;
    float2 sizeClip    = halfSize * pixelToClip;

    // Quad vertex offsets (two triangles: 0-1-2, 2-1-3).
    float2 offsets[6];
    offsets[0] = float2(-1.0, -1.0); // bottom-left
    offsets[1] = float2( 1.0, -1.0); // bottom-right
    offsets[2] = float2(-1.0,  1.0); // top-left
    offsets[3] = float2(-1.0,  1.0); // top-left
    offsets[4] = float2( 1.0, -1.0); // bottom-right
    offsets[5] = float2( 1.0,  1.0); // top-right

    float2 offset = offsets[vertexInQuad];

    // Apply rotation to offset.
    float cosR = cos(rotation);
    float sinR = sin(rotation);
    float2 rotatedOffset = float2(
        offset.x * cosR - offset.y * sinR,
        offset.x * sinR + offset.y * cosR
    );

    // Scale offset and add to center position.
    float2 finalPos = clipPos + rotatedOffset * sizeClip;

    // Y-orientation parity (CRITICAL): like PointsRender.vert_deposit, this custom
    // billboard vertex stage MUST counter-flip clip.y by _ProjectionParams.x so the
    // scattered quads store in the SAME orientation as the fullscreen diffuse/copy/
    // blend passes (NMVertFullscreen). Without it the deposited billboards land
    // vertically MIRRORED vs the GLSL golden, so the composited trail/output renders
    // upside-down. The sprite SDF shapes (circle/ring/square/diamond) and the radial
    // "soft" falloff are Y-symmetric, so counter-flipping the quad position alone
    // reproduces the golden. See NMFullscreen.hlsl + PointsRender.hlsl.
    o.positionCS = float4(finalPos.x, finalPos.y * _ProjectionParams.x, 0.0, 1.0);
    o.color      = col * brightnessFade * layerWeight;

    // Sprite UV coordinates (0..1 range), padded for the blur kernel's support.
    o.spriteUV = offset * (0.5 + blurPadding + supportRadius) + 0.5;

    return o;
}

// nm_shadeSprite — the pre-round SDF/texture shading, parameterized by uv+color
// so both the sharp sample (uv = i.spriteUV) and the blur kernel's off-center
// samples (uv = a source-grid node) share identical math.
float4 nm_shadeSprite(float2 uv, float4 color)
{
    float opacity = depositOpacity / 100.0;

    if (shapeMode == 0)
    {
        // Texture mode: sample sprite texture.
        float4 spriteColor = spriteTex.Sample(sampler_spriteTex, uv);
        return float4(spriteColor.rgb * color.rgb, spriteColor.a * color.a) * opacity;
    }

    // Procedural SDF shapes.
    float2 p = uv - 0.5;
    float sdf;
    float alpha;

    if (shapeMode == 1)
    {
        // Circle.
        sdf = length(p) - 0.45;
    }
    else if (shapeMode == 2)
    {
        // Ring.
        sdf = abs(length(p) - 0.35) - 0.08;
    }
    else if (shapeMode == 3)
    {
        // Square.
        sdf = max(abs(p.x), abs(p.y)) - 0.4;
    }
    else if (shapeMode == 4)
    {
        // Diamond.
        sdf = abs(p.x) + abs(p.y) - 0.45;
    }
    else if (shapeMode == 5)
    {
        // Equilateral triangle (Inigo Quilez SDF).
        float r = 0.25;
        float k = 1.732050808; // sqrt(3)
        float2 t = float2(abs(p.x) - r, p.y - 0.04 + r / k);
        if (t.x + k * t.y > 0.0) { t = float2(t.x - k * t.y, -k * t.x - t.y) / 2.0; }
        t.x -= clamp(t.x, -2.0 * r, 0.0);
        sdf = -length(t) * sign(t.y);
    }
    else if (shapeMode == 6)
    {
        // 5-point star (Inigo Quilez SDF — straight edges).
        float r = 0.35;
        float rf = 0.4;
        float2 k1 = float2(0.809016994375, -0.587785252292);
        float2 k2 = float2(-k1.x, k1.y);
        float2 s = float2(abs(p.x), p.y);
        s -= 2.0 * max(dot(k1, s), 0.0) * k1;
        s -= 2.0 * max(dot(k2, s), 0.0) * k2;
        s.x = abs(s.x);
        s.y -= r;
        float2 ba = rf * float2(-k1.y, k1.x) - float2(0.0, 1.0);
        float h = clamp(dot(s, ba) / dot(ba, ba), 0.0, r);
        sdf = length(s - ba * h) * sign(s.y * ba.x - s.x * ba.y);
    }
    else
    {
        // Soft (7) — gaussian falloff.
        alpha = exp(-dot(p, p) * 8.0);
        return float4(color.rgb * alpha, alpha * color.a) * opacity;
    }

    alpha = 1.0 - smoothstep(-0.02, 0.02, sdf);
    return float4(color.rgb * alpha, alpha * color.a) * opacity;
}

// nm_blurSample — the sharp shade, zeroed outside [0,1] (reference 0ed489ec).
float4 nm_blurSample(float2 uv, float4 color)
{
    if (any(uv < 0.0) || any(uv > 1.0)) return float4(0.0, 0.0, 0.0, 0.0);
    return nm_shadeSprite(uv, color);
}

// nm_blurWeight — each source-grid contribution has continuous, symmetric
// support; keeping their locations preserves both color and coverage centers
// during defocus (reference 0ed489ec).
float nm_blurWeight(float2 uv, float2 center, float expansion)
{
    float2 p = (uv - center) / expansion;
    float gaussian = exp(-dot(p, p) / 0.0648) * (1.0 - smoothstep(0.45, 0.5, length(p)));
    // Integral of the tapered radial kernel is 0.19724318. Its minimum
    // expansion keeps the normalized peak <= 1 without discarding mass.
    float normalization = 1.0 / (0.19724318 * expansion * expansion);
    return gaussian * normalization;
}

// nm_shadeParticle — NEW this round: blends the sharp shade with a defocused
// sample built from the spriteMean precompute once the vertex stage computed a
// nonzero blur radius.
float4 nm_shadeParticle(PBRDepositVaryings i)
{
    if (VIEW_MODE == 0) return nm_shadeSprite(i.spriteUV, i.color);

    if (i.blurRadius <= 0.0) return nm_shadeSprite(i.spriteUV, i.color);
    float expansion = max(1.0 + 2.0 * i.blurRadius, 2.2516403);
    float4 blurred = float4(0.0, 0.0, 0.0, 0.0);
    if (shapeMode == 0)
    {
        for (int y = 0; y < 5; y++)
        {
            for (int x = 0; x < 5; x++)
            {
                float4 source = spriteMeanTex.Load(int3(int2(x, y), 0));
                blurred += source * nm_blurWeight(i.spriteUV, float2((float)x, (float)y) / 4.0, expansion);
            }
        }
        blurred *= i.color * (depositOpacity / 100.0);
    }
    else
    {
        float4 meanColor = spriteMeanTex.Load(int3(0, 0, 0)) * i.color * (depositOpacity / 100.0);
        float2 center = shapeMode == 5 ? float2(0.5, 0.54) : float2(0.5, 0.5);
        blurred = meanColor * nm_blurWeight(i.spriteUV, center, expansion);
    }
    if (i.blurRadius >= 0.5) return blurred;
    return lerp(nm_blurSample(i.spriteUV, i.color), blurred, smoothstep(0.0, 0.5, i.blurRadius));
}

float4 frag_deposit(PBRDepositVaryings i) : SV_Target
{
    return nm_shadeParticle(i);
}

// =============================================================================
// PASS 4: blend — composite trail over scaled input (frag_blend, fullscreen).
//   WGSL: t = inputIntensity/100; scaledInput = inputColor * t. The composite
//   depends on blendMode (reference 678154a2):
//     blendMode==1 (alpha)    : trail stores PREMULTIPLIED values (rgb=color*alpha,
//                               deposited with ONE/ONE_MINUS_SRC_ALPHA). Use the
//                               premultiplied OVER operator, then un-premultiply.
//     blendMode==0 (additive) : trail stores additive sums (deposited ONE/ONE).
//                               Clamp to [0,1] then screen-blend over the input
//                               (reference v1.0.79 a27bf823).
//   size = max(resolution, vec2(1.0)).
// =============================================================================
float4 frag_blend(NMVaryings i) : SV_Target
{
    float2 size = max(resolution, float2(1.0, 1.0));
    float2 uv = NM_FragCoord(i) / size;

    float4 inputColor = inputTex.Sample(sampler_inputTex, uv);
    float4 trailColor = trailTex.Sample(sampler_trailTex, uv);

    // inputIntensity 0 = trail only, 100 = trail over full input.
    float t = inputIntensity / 100.0;
    float4 scaledInput = inputColor * t;

    float3 outRGB;
    float  outAlpha;

    if (blendMode == 1)
    {
        // Alpha mode: trail stores premultiplied values (rgb = actual_color * alpha).
        // Use premultiplied OVER then convert to straight for output.
        outAlpha = trailColor.a + scaledInput.a * (1.0 - trailColor.a);
        float3 outRGB_pre = trailColor.rgb + scaledInput.rgb * scaledInput.a * (1.0 - trailColor.a);
        outRGB = outAlpha > 0.0 ? outRGB_pre / outAlpha : float3(0.0, 0.0, 0.0);
    }
    else
    {
        // Additive mode (reference a27bf823 / v1.0.79 "fix additive mode billboard
        // renderer"): clamp the trail to [0,1] then screen-blend with the input
        // (trail OVER input via screen = trail + input*(1-trail)) to avoid the
        // overflow/dimming of the old pseudo-non-premultiplied composite.
        float3 trail = clamp(trailColor.rgb, 0.0, 1.0);
        float trailPresence = max(max(trail.r, trail.g), trail.b);
        outRGB = trail + scaledInput.rgb * (1.0 - trail);
        outAlpha = max(trailPresence, scaledInput.a);
    }

    // Clamp to [0,1] (reference 77e45a5e): deposit can push alpha > 1 within a frame.
    return clamp(float4(outRGB, outAlpha), 0.0, 1.0);
}

// =============================================================================
// PASS 5/6: depthKeys — NEW this round (reference 0ed489ec). Emits one
// [depth, originalIndex] key per agent slot, back-to-front, feeding the
// depthMerge sort. Two clones (VIEW_MODE 1 ortho / 2 perspective) select the
// world position differently. Ported verbatim from glsl/depthKeys.glsl. Only
// runs when blendMode==1 (alpha) and viewMode!=0 (conditions-gated, see JSON).
// =============================================================================
float4 frag_depthKeys(NMVaryings i) : SV_Target
{
    int2 coord = (int2)NM_FragCoord(i);
    uint dw, dh;
    xyzTex.GetDimensions(dw, dh);
    int2 dims = int2((int)dw, (int)dh);
    float4 pos = xyzTex.Load(int3(coord, 0));
    float3 p = pos.xyz;
    if (VIEW_MODE == 1 && abs(p.z) < 1.0 && p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0)
    {
        p = float3(p.xy - 0.5, 0.0);
    }
    p = float3(p.x, p.y * cos(rotateX) - p.z * sin(rotateX), p.y * sin(rotateX) + p.z * cos(rotateX));
    p = float3(p.x * cos(rotateY) + p.z * sin(rotateY), p.y, -p.x * sin(rotateY) + p.z * cos(rotateY));
    // Ascending negative camera depth gives back-to-front draw order.
    // Original slot breaks ties and retains per-particle identity.
    float depth = p.z + posZ - 80.0;
    // A non-finite key breaks the merge ordering and can duplicate valid IDs.
    float key = (pos.w >= 0.5 && abs(depth) <= 3.402823466e38) ? depth : 3.402823466e38;
    return float4(key, (float)(coord.y * dims.x + coord.x), 0.0, 1.0);
}

// =============================================================================
// PASS 7-28: depthMerge — NEW this round. One stage of a 22-stage bottom-up
// merge sort over the depthKeys output (runLength = 1,2,4,...,4194304), one
// clone per stage. Each output texel finds its rank via a Merge Path binary
// search across the two sorted runs it falls between. Ported verbatim from
// glsl/depthMerge.glsl. Only runs when blendMode==1 (alpha) and viewMode!=0.
// =============================================================================
float2 pbr_keyAt(int index, int width)
{
    return orderTex.Load(int3(index % width, index / width, 0)).rg;
}
bool pbr_before(float2 a, float2 b)
{
    return a.x < b.x || (a.x == b.x && a.y <= b.y);
}
float4 frag_depthMerge(NMVaryings i) : SV_Target
{
    int rl = (int)runLength;
    uint dw, dh;
    orderTex.GetDimensions(dw, dh);
    int2 dims = int2((int)dw, (int)dh);
    int2 coord = (int2)NM_FragCoord(i);
    int index = coord.y * dims.x + coord.x;
    int count = dims.x * dims.y;
    if (rl >= count)
    {
        return orderTex.Load(int3(coord, 0));
    }
    int start = (index / (2 * rl)) * (2 * rl);
    int lengthA = min(rl, count - start);
    int lengthB = min(rl, count - start - lengthA);
    int diagonal = index - start;
    int lo = max(0, diagonal - lengthB);
    int hi = min(diagonal, lengthA);
    // Find the partition for this output position in the two sorted runs.
    [loop]
    for (int step = 0; step < 22 && lo < hi; step++)
    {
        int mid = (lo + hi) / 2;
        int other = diagonal - mid;
        if (mid < lengthA && other > 0 && pbr_before(pbr_keyAt(start + mid, dims.x), pbr_keyAt(start + lengthA + other - 1, dims.x)))
        {
            lo = mid + 1;
        }
        else
        {
            hi = mid;
        }
    }
    int otherFinal = diagonal - lo;
    float2 a = (lo < lengthA) ? pbr_keyAt(start + lo, dims.x) : float2(3.402823466e38, 3.402823466e38);
    float2 b = (otherFinal < lengthB) ? pbr_keyAt(start + lengthA + otherFinal, dims.x) : float2(3.402823466e38, 3.402823466e38);
    float2 winner = pbr_before(a, b) ? a : b;
    return float4(winner, 0.0, 1.0);
}

// =============================================================================
// PASS 29: spriteMeanTiles — NEW this round. 32x32-texel reduction tiles over a
// 5x5 grid of overlapping bilinear-weighted nodes, feeding spriteMean. Ported
// verbatim from glsl/spriteMeanTiles.glsl. Only meaningful for shapeMode==0
// (texture); skipped whenever aperture is 0 or viewMode is flat.
// =============================================================================
float4 frag_spriteMeanTiles(NMVaryings i) : SV_Target
{
    if (shapeMode != 0 || aperture <= 0.0 || viewMode == 0) return float4(0.0, 0.0, 0.0, 0.0);
    uint dw, dh;
    spriteTex.GetDimensions(dw, dh);
    int2 dims = int2((int)dw, (int)dh);
    int2 coord = (int2)NM_FragCoord(i);
    int2 node = coord / 32;
    int2 tile = coord % 32;
    int2 start = max(tile * dims / 32, (node - int2(1, 1)) * dims / 4 - int2(1, 1));
    int2 end   = min((tile + int2(1, 1)) * dims / 32, (node + int2(1, 1)) * dims / 4 + int2(1, 1));
    float4 total = float4(0.0, 0.0, 0.0, 0.0);
    for (int y = start.y; y < end.y; y++)
    {
        for (int x = start.x; x < end.x; x++)
        {
            float2 uv = (float2((float)x, (float)y) + 0.5) / float2(dims);
            float2 weight = max(float2(0.0, 0.0), 1.0 - abs(uv * 4.0 - float2(node)));
            total += spriteTex.Load(int3(x, y, 0)) * (weight.x * weight.y);
        }
    }
    return total / (float)(dims.x * dims.y);
}

// =============================================================================
// PASS 30: spriteMean — NEW this round. Reduces spriteMeanTiles' 160x160 tiles
// into a 5x5 texel mean-sprite texture, or for a procedural shapeMode fills it
// with a fixed precomputed coverage constant. Ported verbatim from
// glsl/spriteMean.glsl. Skipped whenever aperture is 0 or viewMode is flat.
// =============================================================================
float pbr_proceduralCoverage()
{
    // Means of the same 5x5 centered SDF samples, evaluated in double precision
    // and rounded once to f32. Recompute if a shape changes. Fixed values avoid
    // driver-dependent coverage drift during defocus.
    if (shapeMode == 1) return 0.713220537;
    if (shapeMode == 2) return 0.310907274;
    if (shapeMode == 3) return 0.680000007;
    if (shapeMode == 4) return 0.519999981;
    if (shapeMode == 5) return 0.0951406509;
    if (shapeMode == 6) return 0.103062622;
    return 0.362012237; // Soft shape and the existing fallback.
}
float4 frag_spriteMean(NMVaryings i) : SV_Target
{
    if (aperture <= 0.0 || viewMode == 0) return float4(0.0, 0.0, 0.0, 0.0);
    if (shapeMode != 0) return (float4)pbr_proceduralCoverage();
    int2 origin = (int2)NM_FragCoord(i) * 32;
    float4 total = float4(0.0, 0.0, 0.0, 0.0);
    for (int y = 0; y < 32; y++)
    {
        for (int x = 0; x < 32; x++)
        {
            total += tilesTex.Load(int3(origin + int2(x, y), 0));
        }
    }
    return total;
}

// =============================================================================
// PASS 31: clearDefocus — NEW this round. Clears the defocus accumulation
// target to a flat value before the additive-mode deposit passes write into
// it. Ported verbatim from glsl/clearDefocus.glsl. Only runs for blendMode==0
// (additive); skipped whenever aperture is 0 or viewMode is flat.
// =============================================================================
float4 frag_clearDefocus(NMVaryings i) : SV_Target
{
    return (float4)clearValue;
}

#endif // NM_EFFECT_POINTSBILLBOARDRENDER_INCLUDED
