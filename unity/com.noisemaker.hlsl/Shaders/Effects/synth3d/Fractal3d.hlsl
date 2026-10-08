#ifndef NM_EFFECT_FRACTAL3D_INCLUDED
#define NM_EFFECT_FRACTAL3D_INCLUDED

// =============================================================================
// Fractal3d.hlsl — synth3d/fractal3d (func: "fractal3d")
//
// 3D fractal VOLUME GENERATOR. Single pass, MRT (drawBuffers:2). Ported
// PIXEL-IDENTICALLY from the canonical WGSL source (top-left origin, no
// per-effect Y flip — Golden #1):
//   wgsl/precompute.wgsl   progName "precompute"   (frag_precompute, MRT 2)
//
// VOLUME-WRITE PASS (reference 04 §8 + reference 10 §3.7/§4.2): the effect
// renders into a 2D ATLAS RenderTexture of size volumeSize x volumeSize^2
// (default 64 x 4096 = rgba16f). The atlas stores a volumeSize^3 voxel volume
// as volumeSize stacked Z-slices, each slice volumeSize x volumeSize. A
// fragment at atlas pixel (x, y) maps to voxel (x, y % volumeSize,
// y / volumeSize). The viewport is the full atlas (not the screen). Downstream
// render/render3d or render/renderLit3d RAYMARCHES this atlas to a 2D image.
//
// MRT (drawBuffers:2):
//   color  -> volumeCache (SV_Target0): rgba16f. colorMode 0 (mono, default):
//             .rgb=normalizedDist; otherwise .r=normalizedDist .g=trap
//             .b=iterRatio; .a=1. (the volume scalar field / "vol" surface)
//   geoOut -> geoBuffer   (SV_Target1): rgba16f, xyz = normal*0.5+0.5,
//             w = normalizedDist. (the geo surface: xyz=normal, w=depth/sdf)
//
// SINGLE PASS, NO feedback, NO repeat, NO persistent state. The atlas + geo
// buffer are transient per-frame (pooled volumeCache/geoBuffer textures, not
// 'global_'). The effect re-runs whenever a uniform changes.
//
// NOTE: 3D / multi-output (MRT) volume-write effect → ships as a runtime-
// rendered Texture2D atlas. NO Shader Graph Custom Function wrapper (3D /
// multi-pass / geometry per PORTING-GUIDE checklist + task spec).
//
// PORTING-GUIDE / parity notes:
//  * Ported from WGSL. Since reference 27dccd6f the WGSL matches the GLSL
//    (WebGL2) volume: it declares colorMode and writes grayscale for mono
//    (colorMode 0), and its geo normal uses the outward SDF gradient,
//    normalize(gradient + 0.000001) (GLSL: + 1e-6, the same value).
//    One GLSL/WGSL difference remains, and we follow the WGSL:
//      (1) GLSL applies tileOffset + renderScale to the atlas coordinate and
//          scales volSize by renderScale (x = mod(x, scaledVolSize)); WGSL
//          uses the raw fragment coord and volumeSize directly. We reproduce
//          the WGSL: atlas pixel = int2(NM_FragCoord(i)), volSize = volumeSize
//          (no renderScale). Untiled at renderScale 1 the two are identical
//          (the atlas is volSize wide, so the GLSL x mod is a no-op); this
//          atlas is small enough to render untiled.
//          // TODO(verify) atlas is rendered untiled (tileOffset==0); if the
//          // runtime tiles it, fold tileOffset in via NM_GlobalCoord.
//  * Helpers (mandelbulb/juliaBulb/boxFold/sphereFold/mandelcube/juliaCube)
//    ported verbatim, inline. NONE come from NMCore (no pcg/prng/random/nm_mod
//    used by this effect) except nm_atan2. atan2 arg order copied literally:
//    atan2(z.y, z.x). The bulb steps use the accurate NMCore nm_atan2 and
//    fr_acos (the HLSL inverse-trig intrinsics are low precision here; the
//    reference WebGL ones are accurate).
//  * Full 32-bit float throughout. pow/log/sin/cos as written.
//  * WGSL vec2<i32>(position.xy) truncation -> int2(NM_FragCoord(i)). The
//    integer atlas decode uses i32 '%' and '/' (trunc-toward-zero) on
//    non-negative coords -> HLSL int % and / (same).
//  * No textures sampled (pure generator); no SamplerState needed.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) ------
// `type` is renamed to `noiseType` (WGSL reserves `type`) — same as the source.
int   volumeSize;   // globals.volumeSize  default 64   (atlas slice size)
int   noiseType;    // globals.type        default 0    (0=bulb 1=cube 2=jBulb 3=jCube)
float power;        // globals.power       default 8
int   iterations;   // globals.iterations  default 10
float bailout;      // globals.bailout     default 2
float juliaX;       // globals.juliaX      default 0
float juliaY;       // globals.juliaY      default 0
float juliaZ;       // globals.juliaZ      default 0
int   colorMode;    // globals.colorMode   default 0    (0=mono 1=rgb)

static const float PI = 3.141592653589793;

// Accurate acos for the spherical-coordinate step. The HLSL acos intrinsic is
// a low-precision polynomial on this toolchain (like atan2, see NMCore
// nm_atan2), while the reference WebGL acos is accurate; the bulb iteration
// amplifies that error. acos(x) = atan2(sqrt((1 - x)(1 + x)), x) keeps full
// precision near |x| = 1 (1 - x is exact there).
float fr_acos(float x)
{
    return nm_atan2(sqrt(max((1.0 - x) * (1.0 + x), 0.0)), x);
}

// =============================================================================
// PASS: precompute — generate 3D fractal volume as a 2D atlas (frag_precompute)
// =============================================================================

// Mandelbulb distance estimator
// Returns (distance estimate, orbit trap distance, iteration ratio)
float3 fr_mandelbulb(float3 pos, float n, int maxIter, float bail)
{
    float3 z = pos;
    float dr = 1.0;
    float r = 0.0;
    float trap = 1e10;
    float iter = 0.0;

    for (int i = 0; i < maxIter; i = i + 1)
    {
        r = length(z);
        if (r > bail) { break; }

        // Orbit trap - distance to origin
        trap = min(trap, r);

        // Convert to spherical coordinates
        float theta = fr_acos(z.z / r);
        float phi = nm_atan2(z.y, z.x);

        // Scale the running derivative
        dr = pow(r, n - 1.0) * n * dr + 1.0;

        // Scale and rotate the point
        float zr = pow(r, n);
        float newTheta = theta * n;
        float newPhi = phi * n;

        // Convert back to Cartesian coordinates
        z = zr * float3(
            sin(newTheta) * cos(newPhi),
            sin(newTheta) * sin(newPhi),
            cos(newTheta)
        );
        z = z + pos;

        iter = iter + 1.0;
    }

    // Distance estimator
    float dist = 0.5 * log(r) * r / dr;

    return float3(dist, trap, iter / (float)maxIter);
}

// Julia Mandelbulb - fixed c point
float3 fr_juliaBulb(float3 pos, float3 c, float n, int maxIter, float bail)
{
    float3 z = pos;
    float dr = 1.0;
    float r = 0.0;
    float trap = 1e10;
    float iter = 0.0;

    for (int i = 0; i < maxIter; i = i + 1)
    {
        r = length(z);
        if (r > bail) { break; }

        trap = min(trap, r);

        float theta = fr_acos(z.z / r);
        float phi = nm_atan2(z.y, z.x);

        dr = pow(r, n - 1.0) * n * dr + 1.0;

        float zr = pow(r, n);
        float newTheta = theta * n;
        float newPhi = phi * n;

        z = zr * float3(
            sin(newTheta) * cos(newPhi),
            sin(newTheta) * sin(newPhi),
            cos(newTheta)
        );
        z = z + c;  // Add constant c instead of pos

        iter = iter + 1.0;
    }

    float dist = 0.5 * log(r) * r / dr;
    return float3(dist, trap, iter / (float)maxIter);
}

// Box fold operation for Mandelbox/Mandelcube
float3 fr_boxFold(float3 z, float foldingLimit)
{
    return clamp(z, float3(-foldingLimit, -foldingLimit, -foldingLimit), float3(foldingLimit, foldingLimit, foldingLimit)) * 2.0 - z;
}

// Sphere fold operation for Mandelbox
float3 fr_sphereFold(float3 z, float minRadius, float fixedRadius)
{
    float r2 = dot(z, z);
    float minR2 = minRadius * minRadius;
    float fixedR2 = fixedRadius * fixedRadius;

    if (r2 < minR2)
    {
        return z * (fixedR2 / minR2);
    }
    else if (r2 < fixedR2)
    {
        return z * (fixedR2 / r2);
    }
    return z;
}

// Mandelcube (simplified Mandelbox-like) distance estimator
float3 fr_mandelcube(float3 pos, float scale, int maxIter, float bail)
{
    float3 z = pos;
    float dr = 1.0;
    float trap = 1e10;
    float iter = 0.0;

    float foldingLimit = 1.0;
    float minRadius = 0.5;
    float fixedRadius = 1.0;

    for (int i = 0; i < maxIter; i = i + 1)
    {
        // Box fold
        z = fr_boxFold(z, foldingLimit);

        // Sphere fold
        float r2 = dot(z, z);
        float minR2 = minRadius * minRadius;
        float fixedR2 = fixedRadius * fixedRadius;

        if (r2 < minR2)
        {
            float factor = fixedR2 / minR2;
            z = z * factor;
            dr = dr * factor;
        }
        else if (r2 < fixedR2)
        {
            float factor = fixedR2 / r2;
            z = z * factor;
            dr = dr * factor;
        }

        // Scale and translate
        z = z * scale + pos;
        dr = dr * abs(scale) + 1.0;

        trap = min(trap, length(z));
        iter = iter + 1.0;

        if (length(z) > bail) { break; }
    }

    float r = length(z);
    float dist = r / abs(dr);

    return float3(dist, trap, iter / (float)maxIter);
}

// Julia Mandelcube - fixed c point
float3 fr_juliaCube(float3 pos, float3 c, float scale, int maxIter, float bail)
{
    float3 z = pos;
    float dr = 1.0;
    float trap = 1e10;
    float iter = 0.0;

    float foldingLimit = 1.0;
    float minRadius = 0.5;
    float fixedRadius = 1.0;

    for (int i = 0; i < maxIter; i = i + 1)
    {
        z = fr_boxFold(z, foldingLimit);

        float r2 = dot(z, z);
        float minR2 = minRadius * minRadius;
        float fixedR2 = fixedRadius * fixedRadius;

        if (r2 < minR2)
        {
            float factor = fixedR2 / minR2;
            z = z * factor;
            dr = dr * factor;
        }
        else if (r2 < fixedR2)
        {
            float factor = fixedR2 / r2;
            z = z * factor;
            dr = dr * factor;
        }

        z = z * scale + c;  // Add constant c instead of pos
        dr = dr * abs(scale) + 1.0;

        trap = min(trap, length(z));
        iter = iter + 1.0;

        if (length(z) > bail) { break; }
    }

    float r = length(z);
    float dist = r / abs(dr);

    return float3(dist, trap, iter / (float)maxIter);
}

// MRT output structure for volume cache and geometry buffer
// WGSL @location(0) color, @location(1) geoOut.
struct FractalOutput
{
    float4 color  : SV_Target0;  // -> volumeCache  (vol surface)
    float4 geoOut : SV_Target1;  // -> geoBuffer    (geo surface)
};

FractalOutput frag_precompute(NMVaryings i)
{
    FractalOutput o;

    int volSize = volumeSize;
    int scaledVolSize = (int)((float)volSize * renderScale);
    float scaledVolSizeF = (float)scaledVolSize;

    // Atlas is scaledVolSize x (scaledVolSize * scaledVolSize)
    // Pixel (x, y) maps to 3D coordinate (x, y % scaledVolSize, y / scaledVolSize)
    // GLSL: ivec2(gl_FragCoord.xy + tileOffset) — truncation of the global coord.
    float2 globalPixelCoord = NM_GlobalCoord(i);
    int2 pixelCoord = int2(globalPixelCoord);

    // GLSL: int(mod(float(pixelCoord.x), scaledVolSizeF)) — floored mod (nm_mod).
    int x = (int)nm_mod((float)pixelCoord.x, scaledVolSizeF);
    int y = pixelCoord.y % scaledVolSize;
    int z = pixelCoord.y / scaledVolSize;

    // Bounds check
    if (x >= scaledVolSize || y >= scaledVolSize || z >= scaledVolSize)
    {
        o.color = float4(0.0, 0.0, 0.0, 0.0);
        o.geoOut = float4(0.5, 0.5, 0.5, 0.0);
        return o;
    }

    // Convert to normalized 3D coordinates in [-1.5, 1.5] world space
    // Slightly larger than [-1,1] to capture the full fractal
    float3 p = (float3((float)x, (float)y, (float)z) / (scaledVolSizeF - 1.0) * 2.0 - 1.0) * 1.5;

    // Julia constant from uniforms (normalized from -100..100 to -1..1)
    float3 juliaC = float3(juliaX, juliaY, juliaZ) * 0.01;

    float3 result;

    // Select fractal noiseType
    if (noiseType == 0)
    {
        // Mandelbulb
        result = fr_mandelbulb(p, power, iterations, bailout);
    }
    else if (noiseType == 1)
    {
        // Mandelcube (use power as scale, clamped to reasonable range)
        float scale = clamp(power * 0.25, -3.0, 3.0);
        result = fr_mandelcube(p, scale, iterations, bailout);
    }
    else if (noiseType == 2)
    {
        // Julia Bulb
        result = fr_juliaBulb(p, juliaC, power, iterations, bailout);
    }
    else
    {
        // Julia Cube
        float scale = clamp(power * 0.25, -3.0, 3.0);
        result = fr_juliaCube(p, juliaC, scale, iterations, bailout);
    }

    // result.x = distance estimate (used for threshold)
    // result.y = orbit trap (for coloring)
    // result.z = iteration ratio (for coloring)

    // Normalize distance to 0-1 range for storage
    // Small distances = inside/near surface, large = outside
    float dist = result.x;
    float normalizedDist = 1.0 - clamp(dist * 2.0 + 0.5, 0.0, 1.0);

    // Normalize trap value
    float trap = clamp(result.y * 0.5, 0.0, 1.0);

    // Iteration ratio is already 0-1
    float iterRatio = result.z;

    // Compute analytical gradient using finite differences
    float eps = 0.01;
    float3 dx;
    float3 dy;
    float3 dz;

    if (noiseType == 0)
    {
        dx = fr_mandelbulb(p + float3(eps, 0.0, 0.0), power, iterations, bailout);
        dy = fr_mandelbulb(p + float3(0.0, eps, 0.0), power, iterations, bailout);
        dz = fr_mandelbulb(p + float3(0.0, 0.0, eps), power, iterations, bailout);
    }
    else if (noiseType == 1)
    {
        float scale = clamp(power * 0.25, -3.0, 3.0);
        dx = fr_mandelcube(p + float3(eps, 0.0, 0.0), scale, iterations, bailout);
        dy = fr_mandelcube(p + float3(0.0, eps, 0.0), scale, iterations, bailout);
        dz = fr_mandelcube(p + float3(0.0, 0.0, eps), scale, iterations, bailout);
    }
    else if (noiseType == 2)
    {
        dx = fr_juliaBulb(p + float3(eps, 0.0, 0.0), juliaC, power, iterations, bailout);
        dy = fr_juliaBulb(p + float3(0.0, eps, 0.0), juliaC, power, iterations, bailout);
        dz = fr_juliaBulb(p + float3(0.0, 0.0, eps), juliaC, power, iterations, bailout);
    }
    else
    {
        float scale = clamp(power * 0.25, -3.0, 3.0);
        dx = fr_juliaCube(p + float3(eps, 0.0, 0.0), juliaC, scale, iterations, bailout);
        dy = fr_juliaCube(p + float3(0.0, eps, 0.0), juliaC, scale, iterations, bailout);
        dz = fr_juliaCube(p + float3(0.0, 0.0, eps), juliaC, scale, iterations, bailout);
    }

    float3 gradient = float3(dx.x - dist, dy.x - dist, dz.x - dist) / eps;
    float3 normal = normalize(gradient + float3(0.000001, 0.000001, 0.000001));  // SDF gradient points outward

    // Output volume data based on colorMode
    // colorMode 0 = mono (grayscale), 1 = rgb (distance, trap, iteration)
    float4 color = float4(normalizedDist, trap, iterRatio, 1.0);
    if (colorMode == 0)
    {
        color = float4(normalizedDist, normalizedDist, normalizedDist, 1.0);
    }
    float4 geoOut = float4(normal * 0.5 + 0.5, normalizedDist);

    o.color = color;
    o.geoOut = geoOut;
    return o;
}

#endif // NM_EFFECT_FRACTAL3D_INCLUDED
