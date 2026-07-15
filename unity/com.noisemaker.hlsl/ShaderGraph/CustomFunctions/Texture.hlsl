#ifndef NM_SG_TEXTURE_INCLUDED
#define NM_SG_TEXTURE_INCLUDED

// =============================================================================
// ShaderGraph Custom Function wrapper for filter/texture.
//
// Drops the effect into Shader Graph as a node. Each global param from
// definition.js maps to a named input:
//   mode  -> Mode  (float, runtime int 0..14) default 3 (paper)
//   alpha -> Alpha (float)                    [0,1] default 0.5
//   scale -> Scale (float)                    [0.1,10] default 1.0
//   intensity -> Intensity (float)            [0,100] default 40
//   contrast -> Contrast (float)              [0,100] default 50
//   mono -> Mono (float boolean, >0.5=true)             default true
//   time  -> Time  (float, engine global; 0..1 normalized animation time)
// InputTex/SS/UV provide the source surface. UV must be the fullscreen 0..1 UV
// (the WGSL uses `in.uv` for both the sample and the height-field domain).
//
// Single render pass — eligible for a Custom Function node (PORTING-GUIDE §1d).
//
// Self-contained (does NOT include NMFullscreen.hlsl / NMCore.hlsl) so it is
// safe to drop into a Shader Graph Custom Function node. Helpers/core are
// mirrored VERBATIM from Shaders/Effects/filter/Texture.hlsl, name-prefixed
// `nmsg_` to avoid symbol clashes with the runtime include.
// =============================================================================

static const float NMSG_TEX_PI = 3.14159265359;
static const float NMSG_TEX_INV_UINT32_MAX = 1.0 / 4294967295.0;
static const int   NMSG_TEX_Z_LOOP = 2;
static const float NMSG_TEX_SHADE_GAIN = 4.4;

float nmsg_texture_clamp01(float value)
{
    return clamp(value, 0.0, 1.0);
}

float nmsg_texture_s_curve01(float value)
{
    float c = nmsg_texture_clamp01(value);
    return c * c * (3.0 - 2.0 * c);
}

float nmsg_texture_fade(float t)
{
    return t * t * (3.0 - 2.0 * t);
}

float2 nmsg_texture_freq_for_shape(float base_freq, float2 dims)
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

uint nmsg_texture_hash_uint(uint x_in)
{
    uint x = x_in;
    x ^= x >> 16u;
    x *= 0x7feb352du;
    x ^= x >> 15u;
    x *= 0x846ca68bu;
    x ^= x >> 16u;
    return x;
}

float nmsg_texture_fast_hash(int3 p, uint salt)
{
    uint h = salt ^ 0x9e3779b9u;
    h ^= asuint(p.x) * 0x27d4eb2du;
    h = nmsg_texture_hash_uint(h);
    h ^= asuint(p.y) * 0xc2b2ae35u;
    h = nmsg_texture_hash_uint(h);
    h ^= asuint(p.z) * 0x165667b1u;
    h = nmsg_texture_hash_uint(h);
    return (float)h * NMSG_TEX_INV_UINT32_MAX;
}

float nmsg_texture_value_noise(float2 uv, float2 freq, float motion, uint salt)
{
    float2 scaled_uv = uv * max(freq, float2(1.0, 1.0));
    float2 cell_floor = floor(scaled_uv);
    float2 frac_part = frac(scaled_uv);
    int2 base_cell = int2((int)cell_floor.x, (int)cell_floor.y);

    float z_floor = floor(motion);
    float z_frac = frac(motion);
    int z0 = (int)z_floor % NMSG_TEX_Z_LOOP;
    int z1 = (z0 + 1) % NMSG_TEX_Z_LOOP;

    float c000 = nmsg_texture_fast_hash(int3(base_cell.x + 0, base_cell.y + 0, z0), salt);
    float c100 = nmsg_texture_fast_hash(int3(base_cell.x + 1, base_cell.y + 0, z0), salt);
    float c010 = nmsg_texture_fast_hash(int3(base_cell.x + 0, base_cell.y + 1, z0), salt);
    float c110 = nmsg_texture_fast_hash(int3(base_cell.x + 1, base_cell.y + 1, z0), salt);
    float c001 = nmsg_texture_fast_hash(int3(base_cell.x + 0, base_cell.y + 0, z1), salt);
    float c101 = nmsg_texture_fast_hash(int3(base_cell.x + 1, base_cell.y + 0, z1), salt);
    float c011 = nmsg_texture_fast_hash(int3(base_cell.x + 0, base_cell.y + 1, z1), salt);
    float c111 = nmsg_texture_fast_hash(int3(base_cell.x + 1, base_cell.y + 1, z1), salt);

    float tx = nmsg_texture_fade(frac_part.x);
    float ty = nmsg_texture_fade(frac_part.y);
    float tz = nmsg_texture_fade(z_frac);

    float x00 = lerp(c000, c100, tx);
    float x10 = lerp(c010, c110, tx);
    float x01 = lerp(c001, c101, tx);
    float x11 = lerp(c011, c111, tx);

    float y0 = lerp(x00, x10, ty);
    float y1 = lerp(x01, x11, ty);

    return lerp(y0, y1, tz);
}

float nmsg_texture_height_paper(float2 uv, float2 base_freq, float motion)
{
    float2 freq = max(base_freq, float2(1.0, 1.0));
    float amplitude = 0.5;
    float accum = 0.0;
    float total = 0.0;

    for (uint octave = 0u; octave < 3u; octave = octave + 1u)
    {
        uint salt = 0x9e3779b9u * (octave + 1u);
        float sample_val = nmsg_texture_value_noise(uv, freq, motion + (float)octave * 0.37, salt);
        float ridged = 1.0 - abs(sample_val * 2.0 - 1.0);
        accum = accum + ridged * amplitude;
        total = total + amplitude;
        freq = freq * 2.0;
        amplitude = amplitude * 0.55;
    }

    if (total <= 0.0) { return nmsg_texture_clamp01(accum); }
    return nmsg_texture_clamp01(accum / total);
}

float nmsg_texture_height_stucco(float2 uv, float2 base_freq, float motion)
{
    float2 freq = max(base_freq, float2(1.0, 1.0));
    float amplitude = 0.5;
    float accum = 0.0;
    float total = 0.0;

    for (uint octave = 0u; octave < 2u; octave = octave + 1u)
    {
        uint salt = 0x9e3779b9u * (octave + 1u);
        float sample_val = nmsg_texture_value_noise(uv, freq, motion + (float)octave * 0.37, salt);
        accum = accum + sample_val * amplitude;
        total = total + amplitude;
        freq = freq * 2.0;
        amplitude = amplitude * 0.5;
    }

    if (total <= 0.0) { return nmsg_texture_clamp01(accum); }
    return nmsg_texture_clamp01(accum / total);
}

float nmsg_texture_height_canvas(float2 uv, float2 base_freq, float motion)
{
    float2 st = uv * base_freq;
    float warpX = abs(sin(st.x * NMSG_TEX_PI));
    float weftY = abs(sin(st.y * NMSG_TEX_PI));
    float weave = warpX * weftY;

    float noise = nmsg_texture_value_noise(uv, base_freq * 0.5, motion, 0x12345678u);
    return nmsg_texture_clamp01(weave * 0.85 + noise * 0.15);
}

float nmsg_texture_height_halftone(float2 uv, float2 base_freq)
{
    float2 st = uv * base_freq;
    float2 cell = frac(st) - 0.5;
    float dotv = 1.0 - nmsg_texture_clamp01(length(cell) * 3.0);
    return dotv * dotv;
}

float nmsg_texture_height_crosshatch(float2 uv, float2 base_freq)
{
    float2 st = uv * base_freq;
    float d1 = abs(sin((st.x + st.y) * NMSG_TEX_PI));
    float d2 = abs(sin((st.x - st.y) * NMSG_TEX_PI));
    return nmsg_texture_clamp01(d1 * d2);
}

float nmsg_texture_height_field(int mode, float2 uv, float2 base_freq, float motion)
{
    [branch] if (mode == 0) { return nmsg_texture_height_canvas(uv, base_freq, motion); }
    [branch] if (mode == 1) { return nmsg_texture_height_crosshatch(uv, base_freq); }
    [branch] if (mode == 2) { return nmsg_texture_height_halftone(uv, base_freq); }
    [branch] if (mode == 4) { return nmsg_texture_height_stucco(uv, base_freq, motion); }
    return nmsg_texture_height_paper(uv, base_freq, motion);  // 3 = paper (default)
}

uint nmsg_texture_material_hash(int2 p, uint salt, uint layer)
{
    uint h = salt ^ (layer * 0x9e3779b9u);
    h ^= asuint(p.x) * 0x27d4eb2du;
    h = nmsg_texture_hash_uint(h);
    h ^= asuint(p.y) * 0xc2b2ae35u;
    return nmsg_texture_hash_uint(h);
}

float2 nmsg_texture_material_gradient(int2 p, uint salt, uint layer)
{
    uint h = nmsg_texture_material_hash(p, salt, layer);
    float2 gradient = float2((float)(h & 0xffffu), (float)(h >> 16u)) * (2.0 / 65535.0) - 1.0;
    gradient *= rsqrt(max(dot(gradient, gradient), 0.000001));
    return gradient;
}

float2 nmsg_texture_material_fade(float2 t)
{
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float nmsg_texture_material_gradient_layer(float2 p, uint salt, uint layer)
{
    float2 cellFloor = floor(p);
    int2 cell = int2((int)cellFloor.x, (int)cellFloor.y);
    float2 local = frac(p);
    float n00 = dot(nmsg_texture_material_gradient(cell, salt, layer), local);
    float n10 = dot(nmsg_texture_material_gradient(cell + int2(1, 0), salt, layer), local - float2(1.0, 0.0));
    float n01 = dot(nmsg_texture_material_gradient(cell + int2(0, 1), salt, layer), local - float2(0.0, 1.0));
    float n11 = dot(nmsg_texture_material_gradient(cell + int2(1, 1), salt, layer), local - float2(1.0, 1.0));
    float2 blendv = nmsg_texture_material_fade(local);
    return lerp(lerp(n00, n10, blendv.x), lerp(n01, n11, blendv.x), blendv.y);
}

float nmsg_texture_material_noise(float2 globalPixel, float2 cellSize, float motion, uint salt)
{
    float2 p = globalPixel / max(cellSize, float2(0.5, 0.5));
    float zFloor = floor(motion);
    int z0 = (int)zFloor % NMSG_TEX_Z_LOOP;
    int z1 = (z0 + 1) % NMSG_TEX_Z_LOOP;
    float n0 = nmsg_texture_material_gradient_layer(p, salt, (uint)z0);
    float n1 = nmsg_texture_material_gradient_layer(p, salt, (uint)z1);
    float n = lerp(n0, n1, nmsg_texture_material_fade((float2)frac(motion)).x);
    return nmsg_texture_clamp01(0.5 + n * 0.72);
}

float nmsg_texture_material_soft(float2 globalPixel, float motion, uint salt, float size)
{
    float2 primaryCell = (float2)max(size * 3.25, 1.5);
    float primary = nmsg_texture_material_noise(globalPixel, primaryCell, motion, salt);
    float secondary = nmsg_texture_material_noise(globalPixel + float2(17.31, 29.17), primaryCell * 1.87,
        motion + 0.41, salt ^ 0x68bc21ebu);
    return primary * 0.68 + secondary * 0.32;
}

float nmsg_texture_material_directional(float2 globalPixel, float motion, uint salt, float size)
{
    float2 primaryCell = float2(max(size * 22.0, 8.0), max(size * 2.0, 1.25));
    float2 secondaryCell = float2(max(size * 37.0, 13.0), max(size * 3.7, 2.3));
    float primary = nmsg_texture_material_noise(globalPixel, primaryCell, motion, salt);
    float secondary = nmsg_texture_material_noise(globalPixel + float2(19.37, 11.83), secondaryCell,
        motion + 0.41, salt ^ 0x68bc21ebu);
    return primary * 0.72 + secondary * 0.28;
}

float nmsg_texture_material_sprinkles(float2 globalPixel, float motion, uint salt, float size)
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
            float jx = nmsg_texture_fast_hash(int3(cell, 0), salt) - 0.5;
            float jy = nmsg_texture_fast_hash(int3(cell, 1), salt ^ 0x68bc21ebu) - 0.5;
            float2 point = float2((float)x, (float)y) + 0.5 + float2(jx, jy) * 0.6;
            nearest = min(nearest, length(local - point));
        }
    }
    return lerp(0.45, 1.0, 1.0 - smoothstep(0.10, 0.22, nearest));
}

float nmsg_texture_material_edge_mask(
    UnityTexture2D InputTex, UnitySamplerState SS, float2 uv, float2 pixelStep)
{
    float3 weights = float3(0.2126, 0.7152, 0.0722);
    float l = dot(SAMPLE_TEXTURE2D(InputTex.tex, SS.samplerstate, uv - float2(pixelStep.x, 0.0)).xyz, weights);
    float r = dot(SAMPLE_TEXTURE2D(InputTex.tex, SS.samplerstate, uv + float2(pixelStep.x, 0.0)).xyz, weights);
    float d = dot(SAMPLE_TEXTURE2D(InputTex.tex, SS.samplerstate, uv - float2(0.0, pixelStep.y)).xyz, weights);
    float u = dot(SAMPLE_TEXTURE2D(InputTex.tex, SS.samplerstate, uv + float2(0.0, pixelStep.y)).xyz, weights);
    return clamp(length(float2(r - l, u - d)) * 6.0, 0.0, 1.0);
}

float nmsg_texture_material_value(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    int mode,
    float scaleArg,
    float2 globalPixel,
    float2 dims,
    float2 uv,
    float motion,
    uint salt)
{
    float size = max(scaleArg, 0.1);
    [branch] if (mode == 6) { return nmsg_texture_material_soft(globalPixel, motion, salt, size); }
    [branch] if (mode == 7) { return nmsg_texture_material_sprinkles(globalPixel, motion, salt, size); }
    [branch] if (mode == 8)
    {
        float a = nmsg_texture_material_noise(globalPixel, (float2)(13.0 * size), motion, salt);
        float b = nmsg_texture_material_noise(globalPixel, (float2)(6.0 * size), motion + 0.31, salt ^ 0x9e3779b9u);
        float c = nmsg_texture_material_noise(globalPixel, (float2)(2.5 * size), motion + 0.67, salt ^ 0x85ebca6bu);
        return a * 0.58 + b * 0.28 + c * 0.14;
    }
    [branch] if (mode == 9)
    {
        float n = nmsg_texture_material_noise(globalPixel, (float2)max(size * 1.5, 0.8), motion, salt);
        return nmsg_texture_s_curve01(nmsg_texture_s_curve01(n));
    }
    [branch] if (mode == 10) { return nmsg_texture_material_noise(globalPixel, (float2)(4.5 * size), motion, salt); }
    [branch] if (mode == 11)
    {
        return step(0.5, nmsg_texture_material_noise(globalPixel, (float2)max(size * 1.5, 0.8), motion, salt));
    }
    [branch] if (mode == 12) { return nmsg_texture_material_directional(globalPixel, motion, salt, size); }
    [branch] if (mode == 13) { return nmsg_texture_material_directional(globalPixel.yx, motion, salt, size); }
    [branch] if (mode == 14)
    {
        float n = nmsg_texture_material_noise(globalPixel, (float2)max(size * 1.5, 0.8), motion, salt);
        return lerp(0.5, n, nmsg_texture_material_edge_mask(InputTex, SS, uv, 1.0 / dims));
    }
    return nmsg_texture_material_noise(globalPixel, (float2)max(size * 1.5, 0.8), motion, salt);
}

float nmsg_texture_shape_material(float raw, float intensityArg, float contrastArg)
{
    float amount = intensityArg / 40.0;
    float shaped = raw * amount + 0.5 * (1.0 - amount);
    float c = clamp(contrastArg / 100.0, 0.0, 1.0);
    if (c < 0.5) { return lerp(0.5, shaped, c * 2.0); }
    return lerp(shaped, nmsg_texture_s_curve01(shaped), (c - 0.5) * 2.0);
}

// Shader Graph Custom Function entry. Samples InputTex at UV (the fullscreen
// 0..1 UV), derives `dims` from the bound texture (WGSL `textureDimensions`),
// then applies the texture shading. `Time` is the engine-provided normalized
// animation time. `Mode` is the int dispatch (passed as float -> int).
// SS is caller-provided. Use a point, clamp, non-sRGB sampler to mirror runtime
// render surfaces; this Shader Graph path retains its own explicit Y flip.
void NM_Texture_float(
    UnityTexture2D InputTex,
    UnitySamplerState SS,
    float2         UV,
    float          Mode,
    float          Alpha,
    float          Scale,
    float          Intensity,
    float          Contrast,
    float          Mono,
    float          Time,
    out float4     Out)
{
    int mode = (int)Mode;

    float texW, texH;
    InputTex.GetDimensions(texW, texH);
    float2 dims = float2(texW, texH);
    float2 pixel_step = 1.0 / dims;

    float2 sourceUV = UV;
    [branch] if (mode >= 5) { sourceUV.y = 1.0 - sourceUV.y; }
    float4 base_color = SAMPLE_TEXTURE2D(InputTex.tex, SS.samplerstate, sourceUV);

    float a = clamp(Alpha, 0.0, 1.0);
    if (a <= 0.0)
    {
        Out = base_color;
        return;
    }

    [branch]
    if (mode >= 5)
    {
        float2 globalPixel = UV * dims;
        float materialMotion = Time * (float)NMSG_TEX_Z_LOOP;
        float r = nmsg_texture_shape_material(nmsg_texture_material_value(
            InputTex, SS, mode, Scale, globalPixel, dims, sourceUV, materialMotion,
            0x1234abcdu), Intensity, Contrast);
        float3 material = (float3)r;
        if (Mono <= 0.5)
        {
            material.g = nmsg_texture_shape_material(nmsg_texture_material_value(
                InputTex, SS, mode, Scale, globalPixel, dims, sourceUV, materialMotion,
                0x68bc21ebu), Intensity, Contrast);
            material.b = nmsg_texture_shape_material(nmsg_texture_material_value(
                InputTex, SS, mode, Scale, globalPixel, dims, sourceUV, materialMotion,
                0x02e5be93u), Intensity, Contrast);
        }
        Out = float4(clamp(lerp(base_color.xyz, material, a),
            float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0)), base_color.w);
        return;
    }

    float freq_scale = 24.0;
    [branch] if (mode == 4) { freq_scale = 48.0; }
    float2 base_freq = nmsg_texture_freq_for_shape(freq_scale * (10.01 - Scale), dims);
    float motion = Time * (float)NMSG_TEX_Z_LOOP;

    float h_center = nmsg_texture_height_field(mode, UV, base_freq, motion);
    float h_right  = nmsg_texture_height_field(mode, UV + float2(pixel_step.x, 0.0), base_freq, motion);
    float h_left   = nmsg_texture_height_field(mode, UV - float2(pixel_step.x, 0.0), base_freq, motion);
    float h_up     = nmsg_texture_height_field(mode, UV + float2(0.0, pixel_step.y), base_freq, motion);
    float h_down   = nmsg_texture_height_field(mode, UV - float2(0.0, pixel_step.y), base_freq, motion);

    float gx = h_right - h_left;
    float gy = h_down - h_up;
    float gradient = sqrt(gx * gx + gy * gy);

    float gain = NMSG_TEX_SHADE_GAIN * 0.25;
    [branch] if (mode == 4) { gain = NMSG_TEX_SHADE_GAIN * 0.5; }
    float shade_base = nmsg_texture_clamp01(gradient * gain);

    float highlight_mix = nmsg_texture_clamp01((shade_base * shade_base) * 1.25);
    float base_factor = 0.9 + h_center * 0.35;
    float factor = clamp(base_factor + highlight_mix * 0.35, 0.85, 1.6);

    float3 scaled_rgb = clamp(base_color.xyz * factor, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));

    Out = float4(lerp(base_color.xyz, scaled_rgb, a), base_color.w);
}

#endif // NM_SG_TEXTURE_INCLUDED
