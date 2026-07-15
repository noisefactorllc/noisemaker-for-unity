#ifndef NM_EFFECT_TEXTURE_INCLUDED
#define NM_EFFECT_TEXTURE_INCLUDED

// =============================================================================
// Texture.hlsl — filter/texture (func: "texture")
//
// Ported PIXEL-IDENTICALLY from the canonical WGSL source:
//   shaders/effects/filter/texture/wgsl/texture.wgsl
//
// Modes 0..4 retain their height-field contract. Modes 5..14 add procedural
// material textures with intensity/contrast/mono shaping.
//
// PORTING-GUIDE notes / hazards handled:
//  * Sampling UV is the fullscreen 0..1 `uv` (WGSL `in.uv`), used directly for
//    the textureSample AND as the height-field domain. Unity's stored runtime
//    texture orientation already reconciles the WGSL modes 5..14 source-UV flip,
//    so this path intentionally omits a second flip. Fresh directional pixel
//    evidence covers this runtime-specific orientation choice.
//  * `dims = textureDimensions(inputTex)` is the INPUT TEXTURE size; `pixel_step
//    = 1/dims` is the neighbor offset for the gradient. We mirror exactly.
//  * MODE is a compile-time const in WGSL (definition.js globals.mode.define =
//    "MODE"). Per PORTING-GUIDE it is dispatched at runtime with [branch] (same
//    variants the WGSL keeps; runtime const-folds). It is declared as an `int`
//    uniform named `MODE` — the EXACT define key the runtime injects, since
//    UniformBinder writes define ints by their key (mpb.SetInt("MODE", ...)),
//    mirroring Noise.hlsl's `int NOISE_TYPE`. A lowercase `mode` would never be
//    bound and would silently default to 0 (canvas). Default 3 = paper.
//  * fast_hash uses `bitcast<u32>(p.x)` for the int lattice coords -> HLSL
//    `asuint(p.x)` (two's-complement reinterpret of the i32). p is int3, so this
//    is a bit reinterpret of a signed int, identical to WGSL bitcast.
//  * hash_uint uses unsigned multiplies/shifts with literal 32-bit constants
//    (0x7feb352du etc.) — copy verbatim; wraps mod 2^32.
//  * value_noise z-wrap: `z0 = int(floor(motion)) % Z_LOOP` — HLSL `%` is trunc,
//    matching WGSL i32 `%`. Z_LOOP = 2.
//  * INV_UINT32_MAX = 1.0 / 4294967295.0 (full-precision divisor, H11).
//  * `mix` -> `lerp`; `fract` -> `frac`; `f32(u)`/`f32(octave)` -> (float)cast.
//  * Point, clamp-to-edge, non-sRGB sampler (H7) — enforced for runtime render
//    surfaces by TextureStore. Shader Graph receives its sampler from the caller.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// ---- Input texture + sampler (reference binding: sampler@0, inputTex@1) ------
Texture2D    inputTex;
SamplerState sampler_inputTex;

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) ------
// Bound by the runtime via MaterialPropertyBlock by these exact names.
int   MODE;   // globals.mode.define = "MODE", choices 0..14, default 3 (paper)
float alpha;  // globals.alpha.uniform, [0,1] default 0.5
float scale;  // globals.scale.uniform, [0.1,10] default 1.0
float intensity; // globals.intensity.uniform, [0,100] default 40
float contrast;  // globals.contrast.uniform, [0,100] default 50
float mono;      // globals.mono.uniform, boolean bound as 0.0/1.0
// `time` is engine-provided via NMFullscreen alias.

// ---- Effect-local constants (verbatim from WGSL) ----------------------------
static const float TEX_PI = 3.14159265359;
static const float INV_UINT32_MAX = 1.0 / 4294967295.0;
static const int   Z_LOOP = 2;
static const float SHADE_GAIN = 4.4;

float nm_texture_clamp01(float value)
{
    return clamp(value, 0.0, 1.0);
}

float nm_texture_s_curve01(float value)
{
    float c = nm_texture_clamp01(value);
    return c * c * (3.0 - 2.0 * c);
}

float nm_texture_fade(float t)
{
    return t * t * (3.0 - 2.0 * t);
}

float2 nm_texture_freq_for_shape(float base_freq, float2 dims)
{
    float w = max(dims.x, 1.0);
    float h = max(dims.y, 1.0);
    if (abs(w - h) < 0.5)
    {
        return float2(base_freq, base_freq);
    }
    if (w > h)
    {
        return float2(base_freq, base_freq * w / h);
    }
    return float2(base_freq * h / w, base_freq);
}

uint nm_texture_hash_uint(uint x_in)
{
    uint x = x_in;
    x ^= x >> 16u;
    x *= 0x7feb352du;
    x ^= x >> 15u;
    x *= 0x846ca68bu;
    x ^= x >> 16u;
    return x;
}

float nm_texture_fast_hash(int3 p, uint salt)
{
    uint h = salt ^ 0x9e3779b9u;
    h ^= asuint(p.x) * 0x27d4eb2du;
    h = nm_texture_hash_uint(h);
    h ^= asuint(p.y) * 0xc2b2ae35u;
    h = nm_texture_hash_uint(h);
    h ^= asuint(p.z) * 0x165667b1u;
    h = nm_texture_hash_uint(h);
    return (float)h * INV_UINT32_MAX;
}

float nm_texture_value_noise(float2 uv, float2 freq, float motion, uint salt)
{
    float2 scaled_uv = uv * max(freq, float2(1.0, 1.0));
    float2 cell_floor = floor(scaled_uv);
    float2 frac_part = frac(scaled_uv);
    int2 base_cell = int2((int)cell_floor.x, (int)cell_floor.y);

    float z_floor = floor(motion);
    float z_frac = frac(motion);
    int z0 = (int)z_floor % Z_LOOP;
    int z1 = (z0 + 1) % Z_LOOP;

    float c000 = nm_texture_fast_hash(int3(base_cell.x + 0, base_cell.y + 0, z0), salt);
    float c100 = nm_texture_fast_hash(int3(base_cell.x + 1, base_cell.y + 0, z0), salt);
    float c010 = nm_texture_fast_hash(int3(base_cell.x + 0, base_cell.y + 1, z0), salt);
    float c110 = nm_texture_fast_hash(int3(base_cell.x + 1, base_cell.y + 1, z0), salt);
    float c001 = nm_texture_fast_hash(int3(base_cell.x + 0, base_cell.y + 0, z1), salt);
    float c101 = nm_texture_fast_hash(int3(base_cell.x + 1, base_cell.y + 0, z1), salt);
    float c011 = nm_texture_fast_hash(int3(base_cell.x + 0, base_cell.y + 1, z1), salt);
    float c111 = nm_texture_fast_hash(int3(base_cell.x + 1, base_cell.y + 1, z1), salt);

    float tx = nm_texture_fade(frac_part.x);
    float ty = nm_texture_fade(frac_part.y);
    float tz = nm_texture_fade(z_frac);

    float x00 = lerp(c000, c100, tx);
    float x10 = lerp(c010, c110, tx);
    float x01 = lerp(c001, c101, tx);
    float x11 = lerp(c011, c111, tx);

    float y0 = lerp(x00, x10, ty);
    float y1 = lerp(x01, x11, ty);

    return lerp(y0, y1, tz);
}

// Paper: 3-octave ridged noise (original texture)
float nm_texture_height_paper(float2 uv, float2 base_freq, float motion)
{
    float2 freq = max(base_freq, float2(1.0, 1.0));
    float amplitude = 0.5;
    float accum = 0.0;
    float total = 0.0;

    for (uint octave = 0u; octave < 3u; octave = octave + 1u)
    {
        uint salt = 0x9e3779b9u * (octave + 1u);
        float sample_val = nm_texture_value_noise(uv, freq, motion + (float)octave * 0.37, salt);
        float ridged = 1.0 - abs(sample_val * 2.0 - 1.0);
        accum = accum + ridged * amplitude;
        total = total + amplitude;
        freq = freq * 2.0;
        amplitude = amplitude * 0.55;
    }

    if (total <= 0.0) { return nm_texture_clamp01(accum); }
    return nm_texture_clamp01(accum / total);
}

// Stucco: 2-octave smooth noise, lower frequency, rounder bumps
float nm_texture_height_stucco(float2 uv, float2 base_freq, float motion)
{
    float2 freq = max(base_freq, float2(1.0, 1.0));
    float amplitude = 0.5;
    float accum = 0.0;
    float total = 0.0;

    for (uint octave = 0u; octave < 2u; octave = octave + 1u)
    {
        uint salt = 0x9e3779b9u * (octave + 1u);
        float sample_val = nm_texture_value_noise(uv, freq, motion + (float)octave * 0.37, salt);
        accum = accum + sample_val * amplitude;
        total = total + amplitude;
        freq = freq * 2.0;
        amplitude = amplitude * 0.5;
    }

    if (total <= 0.0) { return nm_texture_clamp01(accum); }
    return nm_texture_clamp01(accum / total);
}

// Canvas: woven fabric pattern with slight noise perturbation
float nm_texture_height_canvas(float2 uv, float2 base_freq, float motion)
{
    float2 st = uv * base_freq;
    float warpX = abs(sin(st.x * TEX_PI));
    float weftY = abs(sin(st.y * TEX_PI));
    float weave = warpX * weftY;

    float noise = nm_texture_value_noise(uv, base_freq * 0.5, motion, 0x12345678u);
    return nm_texture_clamp01(weave * 0.85 + noise * 0.15);
}

// Halftone: regular circular dot grid
float nm_texture_height_halftone(float2 uv, float2 base_freq)
{
    float2 st = uv * base_freq;
    float2 cell = frac(st) - 0.5;
    float dotv = 1.0 - nm_texture_clamp01(length(cell) * 3.0);
    return dotv * dotv;
}

// Crosshatch: two overlapping diagonal sine ridges
float nm_texture_height_crosshatch(float2 uv, float2 base_freq)
{
    float2 st = uv * base_freq;
    float d1 = abs(sin((st.x + st.y) * TEX_PI));
    float d2 = abs(sin((st.x - st.y) * TEX_PI));
    return nm_texture_clamp01(d1 * d2);
}

// Dispatch to the active mode's height function. WGSL const-folds MODE; in HLSL
// MODE is a runtime int uniform branched with [branch] (PORTING-GUIDE). The
// uniform name MUST be the injected define key "MODE" (UniformBinder writes
// define ints by their key via mpb.SetInt), matching Noise.hlsl's NOISE_TYPE.
float nm_texture_height_field(float2 uv, float2 base_freq, float motion)
{
    [branch] if (MODE == 0) { return nm_texture_height_canvas(uv, base_freq, motion); }
    [branch] if (MODE == 1) { return nm_texture_height_crosshatch(uv, base_freq); }
    [branch] if (MODE == 2) { return nm_texture_height_halftone(uv, base_freq); }
    [branch] if (MODE == 4) { return nm_texture_height_stucco(uv, base_freq, motion); }
    return nm_texture_height_paper(uv, base_freq, motion);  // 3 = paper (default)
}

uint nm_texture_material_hash(int2 p, uint salt, uint layer)
{
    uint h = salt ^ (layer * 0x9e3779b9u);
    h ^= asuint(p.x) * 0x27d4eb2du;
    h = nm_texture_hash_uint(h);
    h ^= asuint(p.y) * 0xc2b2ae35u;
    return nm_texture_hash_uint(h);
}

float2 nm_texture_material_gradient(int2 p, uint salt, uint layer)
{
    uint h = nm_texture_material_hash(p, salt, layer);
    float2 gradient = float2((float)(h & 0xffffu), (float)(h >> 16u)) * (2.0 / 65535.0) - 1.0;
    gradient *= rsqrt(max(dot(gradient, gradient), 0.000001));
    return gradient;
}

float2 nm_texture_material_fade(float2 t)
{
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float nm_texture_material_gradient_layer(float2 p, uint salt, uint layer)
{
    float2 cellFloor = floor(p);
    int2 cell = int2((int)cellFloor.x, (int)cellFloor.y);
    float2 local = frac(p);
    float n00 = dot(nm_texture_material_gradient(cell, salt, layer), local);
    float n10 = dot(nm_texture_material_gradient(cell + int2(1, 0), salt, layer), local - float2(1.0, 0.0));
    float n01 = dot(nm_texture_material_gradient(cell + int2(0, 1), salt, layer), local - float2(0.0, 1.0));
    float n11 = dot(nm_texture_material_gradient(cell + int2(1, 1), salt, layer), local - float2(1.0, 1.0));
    float2 blendv = nm_texture_material_fade(local);
    return lerp(lerp(n00, n10, blendv.x), lerp(n01, n11, blendv.x), blendv.y);
}

float nm_texture_material_noise(float2 globalPixel, float2 cellSize, float motion, uint salt)
{
    float2 p = globalPixel / max(cellSize, float2(0.5, 0.5));
    float zFloor = floor(motion);
    int z0 = (int)zFloor % Z_LOOP;
    int z1 = (z0 + 1) % Z_LOOP;
    float n0 = nm_texture_material_gradient_layer(p, salt, (uint)z0);
    float n1 = nm_texture_material_gradient_layer(p, salt, (uint)z1);
    float n = lerp(n0, n1, nm_texture_material_fade((float2)frac(motion)).x);
    return nm_texture_clamp01(0.5 + n * 0.72);
}

float nm_texture_material_soft(float2 globalPixel, float motion, uint salt, float size)
{
    float2 primaryCell = (float2)max(size * 3.25, 1.5);
    float primary = nm_texture_material_noise(globalPixel, primaryCell, motion, salt);
    float secondary = nm_texture_material_noise(globalPixel + float2(17.31, 29.17), primaryCell * 1.87,
        motion + 0.41, salt ^ 0x68bc21ebu);
    return primary * 0.68 + secondary * 0.32;
}

float nm_texture_material_directional(float2 globalPixel, float motion, uint salt, float size)
{
    float2 primaryCell = float2(max(size * 22.0, 8.0), max(size * 2.0, 1.25));
    float2 secondaryCell = float2(max(size * 37.0, 13.0), max(size * 3.7, 2.3));
    float primary = nm_texture_material_noise(globalPixel, primaryCell, motion, salt);
    float secondary = nm_texture_material_noise(globalPixel + float2(19.37, 11.83), secondaryCell,
        motion + 0.41, salt ^ 0x68bc21ebu);
    return primary * 0.72 + secondary * 0.28;
}

float nm_texture_material_sprinkles(float2 globalPixel, float motion, uint salt, float size)
{
    float2 p = globalPixel / max(4.0 * size, 1.0) + float2(motion * 0.31, motion * 0.19);
    float2 cellFloor = floor(p);
    int2 baseCell = int2((int)cellFloor.x, (int)cellFloor.y);
    float2 local = frac(p);
    float nearest = 10.0;
    [unroll]
    for (int y = -1; y <= 1; y++)
    {
        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            int2 cell = baseCell + int2(x, y);
            float jx = nm_texture_fast_hash(int3(cell, 0), salt) - 0.5;
            float jy = nm_texture_fast_hash(int3(cell, 1), salt ^ 0x68bc21ebu) - 0.5;
            float2 samplePoint = float2((float)x, (float)y) + 0.5 + float2(jx, jy) * 0.6;
            nearest = min(nearest, length(local - samplePoint));
        }
    }
    return lerp(0.45, 1.0, 1.0 - smoothstep(0.10, 0.22, nearest));
}

float nm_texture_material_edge_mask(float2 uv, float2 pixelStep)
{
    float3 weights = float3(0.2126, 0.7152, 0.0722);
    float l = dot(inputTex.Sample(sampler_inputTex, uv - float2(pixelStep.x, 0.0)).xyz, weights);
    float r = dot(inputTex.Sample(sampler_inputTex, uv + float2(pixelStep.x, 0.0)).xyz, weights);
    float d = dot(inputTex.Sample(sampler_inputTex, uv - float2(0.0, pixelStep.y)).xyz, weights);
    float u = dot(inputTex.Sample(sampler_inputTex, uv + float2(0.0, pixelStep.y)).xyz, weights);
    return clamp(length(float2(r - l, u - d)) * 6.0, 0.0, 1.0);
}

float nm_texture_material_value(float2 globalPixel, float2 dims, float2 uv, float motion, uint salt)
{
    float size = max(scale, 0.1);
    [branch] if (MODE == 6) { return nm_texture_material_soft(globalPixel, motion, salt, size); }
    [branch] if (MODE == 7) { return nm_texture_material_sprinkles(globalPixel, motion, salt, size); }
    [branch] if (MODE == 8)
    {
        float a = nm_texture_material_noise(globalPixel, (float2)(13.0 * size), motion, salt);
        float b = nm_texture_material_noise(globalPixel, (float2)(6.0 * size), motion + 0.31, salt ^ 0x9e3779b9u);
        float c = nm_texture_material_noise(globalPixel, (float2)(2.5 * size), motion + 0.67, salt ^ 0x85ebca6bu);
        return a * 0.58 + b * 0.28 + c * 0.14;
    }
    [branch] if (MODE == 9)
    {
        float n = nm_texture_material_noise(globalPixel, (float2)max(size * 1.5, 0.8), motion, salt);
        return nm_texture_s_curve01(nm_texture_s_curve01(n));
    }
    [branch] if (MODE == 10) { return nm_texture_material_noise(globalPixel, (float2)(4.5 * size), motion, salt); }
    [branch] if (MODE == 11)
    {
        return step(0.5, nm_texture_material_noise(globalPixel, (float2)max(size * 1.5, 0.8), motion, salt));
    }
    [branch] if (MODE == 12) { return nm_texture_material_directional(globalPixel, motion, salt, size); }
    [branch] if (MODE == 13) { return nm_texture_material_directional(globalPixel.yx, motion, salt, size); }
    [branch] if (MODE == 14)
    {
        float n = nm_texture_material_noise(globalPixel, (float2)max(size * 1.5, 0.8), motion, salt);
        return lerp(0.5, n, nm_texture_material_edge_mask(uv, 1.0 / dims));
    }
    return nm_texture_material_noise(globalPixel, (float2)max(size * 1.5, 0.8), motion, salt);
}

float nm_texture_shape_material(float raw)
{
    float amount = intensity / 40.0;
    float shaped = raw * amount + 0.5 * (1.0 - amount);
    float c = clamp(contrast / 100.0, 0.0, 1.0);
    if (c < 0.5) { return lerp(0.5, shaped, c * 2.0); }
    return lerp(shaped, nm_texture_s_curve01(shaped), (c - 0.5) * 2.0);
}

// ---- Pass: "texture" (progName "texture") -----------------------------------
float4 NMFrag_texture(NMVaryings i) : SV_Target
{
    float2 uv = i.uv;
    float2 sourceUV = uv;

    float4 base_color = inputTex.Sample(sampler_inputTex, sourceUV);

    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 dims = float2((float)w, (float)h);
    float2 pixel_step = 1.0 / dims;

    float a = clamp(alpha, 0.0, 1.0);
    if (a <= 0.0)
    {
        return base_color;
    }

    [branch]
    if (MODE >= 5)
    {
        float2 globalDims = dims;
        if (fullResolution.x > 0.0) { globalDims = fullResolution; }
        float2 globalPixel = floor(NM_FragCoord(i)) + 0.5 + tileOffset;
        float materialMotion = time * (float)Z_LOOP;
        float r = nm_texture_shape_material(nm_texture_material_value(
            globalPixel, globalDims, sourceUV, materialMotion, 0x1234abcdu));
        float3 material = (float3)r;
        if (mono <= 0.5)
        {
            material.g = nm_texture_shape_material(nm_texture_material_value(
                globalPixel, globalDims, sourceUV, materialMotion, 0x68bc21ebu));
            material.b = nm_texture_shape_material(nm_texture_material_value(
                globalPixel, globalDims, sourceUV, materialMotion, 0x02e5be93u));
        }
        return float4(clamp(lerp(base_color.xyz, material, a),
            float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0)), base_color.w);
    }

    // Paper and stucco use different base frequencies
    float freq_scale = 24.0;
    [branch] if (MODE == 4) { freq_scale = 48.0; }
    float2 base_freq = nm_texture_freq_for_shape(freq_scale * (10.01 - scale), dims);
    float motion = time * (float)Z_LOOP;

    // Sample height field at center and 4 neighbors for gradient
    float h_center = nm_texture_height_field(uv, base_freq, motion);
    float h_right  = nm_texture_height_field(uv + float2(pixel_step.x, 0.0), base_freq, motion);
    float h_left   = nm_texture_height_field(uv - float2(pixel_step.x, 0.0), base_freq, motion);
    float h_up     = nm_texture_height_field(uv + float2(0.0, pixel_step.y), base_freq, motion);
    float h_down   = nm_texture_height_field(uv - float2(0.0, pixel_step.y), base_freq, motion);

    float gx = h_right - h_left;
    float gy = h_down - h_up;
    float gradient = sqrt(gx * gx + gy * gy);

    // Stucco uses stronger shading for more pronounced bumps
    float gain = SHADE_GAIN * 0.25;
    [branch] if (MODE == 4) { gain = SHADE_GAIN * 0.5; }
    float shade_base = nm_texture_clamp01(gradient * gain);

    float highlight_mix = nm_texture_clamp01((shade_base * shade_base) * 1.25);
    float base_factor = 0.9 + h_center * 0.35;
    float factor = clamp(base_factor + highlight_mix * 0.35, 0.85, 1.6);

    float3 scaled_rgb = clamp(base_color.xyz * factor, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));

    return float4(lerp(base_color.xyz, scaled_rgb, a), base_color.w);
}

#endif // NM_EFFECT_TEXTURE_INCLUDED
