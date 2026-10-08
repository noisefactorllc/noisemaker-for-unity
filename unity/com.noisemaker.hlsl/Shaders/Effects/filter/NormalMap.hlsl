#ifndef NM_NORMALMAP_INCLUDED
#define NM_NORMALMAP_INCLUDED

// =============================================================================
// NormalMap.hlsl — filter/normalMap, ported PIXEL-IDENTICALLY from the
// canonical WGSL: shaders/effects/filter/normalMap/wgsl/normalMap.wgsl
//
// Normal map generation via a 3×3 Sobel filter. Each pixel reads 9 neighbours
// with wrap-around addressing (textureLoad / integer coords), computes the
// horizontal and vertical Sobel derivatives of a reference value, and encodes
// them into RGB with a Z component from their magnitude.
//
// PORTING NOTES:
//  * The WGSL is a compute shader that writes to a storage buffer using
//    textureLoad (integer pixel fetch, no sampling). In the Unity render-pass
//    path we reproduce this via Texture2D.Load(int3(x,y,0)), which gives the
//    identical bit-exact read. NM_FragCoord(i) gives the top-left pixel centre;
//    we truncate to int2 to match gid.xy in the compute shader.
//  * wrap_coord uses C-style truncate-toward-zero % — same as WGSL i32 %
//    (HLSL % is also truncate-toward-zero for integers). Manual fix for
//    negative remainders matches the WGSL verbatim.
//  * ENCODING: the WGSL now ports the GLSL math (upstream 27155c05), so the two
//    backends agree: one loop accumulates dx/dy, then
//    x = clamp01(dx*0.5+0.5), y = clamp01(dy*0.5+0.5),
//    z = clamp01(1 - (|dx|+|dy|)*0.5). (The older WGSL used scale 0.25, an
//    inverted X and a magnitude Z always >= 1; this port never followed it.)
//  * No per-effect globals (definition.js globals: {}). No named uniforms.
//  * DIMS: width/height = the input's textureDimensions (WGSL dims, the GLSL's
//    textureSize fallback when its unset `size` uniform reads 0).
//  * channelCount: the WGSL now calls sanitize_channelCount(0.0) and the GLSL
//    sanitize_channelCount(size.z) with size unset (0). Both return 1 (the
//    `count <= 1u` branch), so the value-map is texel.x (RED channel) and
//    oklab/srgb/cbrt are NOT used. We hard-wire channelCount = 1 to match.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

// No per-effect named uniforms (definition.js globals: {}).

// ---------------------------------------------------------------------------
// Verbatim helper functions (ported from WGSL, per-effect copies)
// ---------------------------------------------------------------------------

static const int2 SOBEL_OFFSETS[9] = {
    int2(-1, -1), int2(0, -1), int2(1, -1),
    int2(-1,  0), int2(0,  0), int2(1,  0),
    int2(-1,  1), int2(0,  1), int2(1,  1)
};

static const float SOBEL_X_KERNEL[9] = {
     0.5,  0.0, -0.5,
     1.0,  0.0, -1.0,
     0.5,  0.0, -0.5
};

static const float SOBEL_Y_KERNEL[9] = {
     0.5,  1.0,  0.5,
     0.0,  0.0,  0.0,
    -0.5, -1.0, -0.5
};

// WGSL: fn clamp01(value : f32) -> f32
float nm_clamp01(float value)
{
    return clamp(value, 0.0, 1.0);
}

// WGSL: fn wrap_coord(value : i32, limit : i32) -> i32
int nm_wrap_coord(int value, int limit)
{
    if (limit <= 0)
        return 0;
    int wrapped = value % limit;
    if (wrapped < 0)
        wrapped = wrapped + limit;
    return wrapped;
}

// WGSL: fn srgb_to_linear(value : f32) -> f32
float nm_srgb_to_linear(float value)
{
    if (value <= 0.04045)
        return value / 12.92;
    return pow((value + 0.055) / 1.055, 2.4);
}

// WGSL: fn cbrt_safe(value : f32) -> f32
// select(b,a,c) in WGSL = c ? a : b  (reversed order — copy literally)
float nm_cbrt_safe(float value)
{
    if (value == 0.0)
        return 0.0;
    float sign_value = (value >= 0.0) ? 1.0 : -1.0;  // select(-1.0, 1.0, value >= 0.0)
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

// WGSL: fn oklab_l_component(rgb : vec3<f32>) -> f32
float nm_oklab_l_component(float3 rgb)
{
    float r = nm_srgb_to_linear(nm_clamp01(rgb.x));
    float g = nm_srgb_to_linear(nm_clamp01(rgb.y));
    float b = nm_srgb_to_linear(nm_clamp01(rgb.z));

    float l = 0.4121656120 * r + 0.5362752080 * g + 0.0514575653 * b;
    float m = 0.2118591070 * r + 0.6807189584 * g + 0.1074065790 * b;
    float s = 0.0883097947 * r + 0.2818474174 * g + 0.6302613616 * b;

    float l_c = nm_cbrt_safe(l);
    float m_c = nm_cbrt_safe(m);
    float s_c = nm_cbrt_safe(s);

    return nm_clamp01(0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c);
}

// WGSL: fn value_map_component(texel : vec4<f32>, channelCount : u32) -> f32
float nm_value_map_component(float4 texel, uint channelCount)
{
    if (channelCount <= 1u)
        return texel.x;
    if (channelCount == 2u)
        return texel.x;
    if (channelCount == 3u)
        return nm_oklab_l_component(texel.xyz);
    // channelCount >= 4 (CHANNEL_CAP path)
    float3 clamped_rgb = clamp(texel.xyz, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
    return nm_oklab_l_component(clamped_rgb);
}

// ---------------------------------------------------------------------------
// nm_normalMap — core per-pixel evaluation.
// inputTex  : source texture, accessed via integer Load (exact texel fetch).
// fragCoord : integer pixel coordinate (top-left, matching WGSL gid.xy).
// ---------------------------------------------------------------------------
float4 nm_normalMap(Texture2D inputTex, int2 fragCoord)
{
    uint tw, th;
    inputTex.GetDimensions(tw, th);
    int width_i  = (int)tw;
    int height_i = (int)th;

    // WGSL: channelCount = sanitize_channelCount(0.0) (GLSL: size.z, unset = 0).
    // as_u32(0)=0 and `if (count <= 1u) return 1u` -> channelCount = 1 (NOT 4 — a
    // prior port misread this as the CHANNEL_CAP default). With channelCount == 1,
    // value_map_component returns texel.x (the RED channel) and the oklab/srgb/cbrt
    // path is never taken. Hard-wiring 4 ran the Sobel over oklab luminance instead
    // of the red channel -> wrong normal map (ssim 0.64).
    uint channelCount = 1u;

    // Sobel derivatives of the reference value, as the GLSL computes them (WGSL:
    // one loop accumulating dx and dy from compute_reference_value(coords)).
    float dx = 0.0;
    float dy = 0.0;
    [unroll]
    for (int i = 0; i < 9; i++)
    {
        int2 offset = SOBEL_OFFSETS[i];
        int2 coords = int2(nm_wrap_coord(fragCoord.x + offset.x, width_i),
                           nm_wrap_coord(fragCoord.y + offset.y, height_i));
        float value = nm_value_map_component(inputTex.Load(int3(coords, 0)), channelCount);
        dx += value * SOBEL_X_KERNEL[i];
        dy += value * SOBEL_Y_KERNEL[i];
    }

    // WGSL and GLSL agree:
    //   x_value = clamp01(dx * 0.5 + 0.5)
    //   y_value = clamp01(dy * 0.5 + 0.5)
    //   z_value = clamp01(1.0 - (abs(dx) + abs(dy)) * 0.5)
    float x_value = nm_clamp01(dx * 0.5 + 0.5);
    float y_value = nm_clamp01(dy * 0.5 + 0.5);
    float z_value = nm_clamp01(1.0 - (abs(dx) + abs(dy)) * 0.5);

    // Alpha: original texel alpha (WGSL: texel.w)
    float4 orig = inputTex.Load(int3(fragCoord.x, fragCoord.y, 0));

    return float4(x_value, y_value, z_value, orig.w);
}

#endif // NM_NORMALMAP_INCLUDED
