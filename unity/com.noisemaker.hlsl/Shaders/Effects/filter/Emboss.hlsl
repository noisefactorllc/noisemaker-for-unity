#ifndef NM_EMBOSS_INCLUDED
#define NM_EMBOSS_INCLUDED

// =============================================================================
// Emboss.hlsl — filter/emboss, ported PIXEL-IDENTICALLY from the canonical WGSL:
//   shaders/effects/filter/emboss/wgsl/emboss.wgsl
//
// Two visual contracts: the original color convolution (STYLE 0) and an opt-in
// gray directional relief (STYLE 1). Global-to-local texture mapping makes both
// paths tile-safe. The default color path stays literal and never uses trig.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

int STYLE;
float amount;
float angle;
float height;
float colorAmount;

static const float3 NM_EMBOSS_LUMA = float3(0.2126, 0.7152, 0.0722);

float3 nm_emboss_sampleGlobal(
    Texture2D inputTex,
    SamplerState sampler_inputTex,
    float2 globalUV)
{
    uint tw, th;
    inputTex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 fullDims = texSize;
    if (fullResolution.x > 0.0) { fullDims = fullResolution; }
    float2 localUV = (globalUV * fullDims - tileOffset) / texSize;
    return inputTex.Sample(sampler_inputTex, localUV).rgb;
}

float3 nm_emboss_colorDefault(
    Texture2D inputTex,
    SamplerState sampler_inputTex,
    float2 uv,
    float2 texelSize)
{
    float kernel[9] = {-2.0, -1.0, 0.0, -1.0, 1.0, 1.0, 0.0, 1.0, 2.0};

    // COLOR_DEFAULT_EXACT_BEGIN
    // Literal pre-angle/height offsets and arithmetic order. Do not route the
    // default through the rotated general path.
    float2 offsets[9] = {
        float2(-texelSize.x, -texelSize.y),
        float2(0.0, -texelSize.y),
        float2(texelSize.x, -texelSize.y),
        float2(-texelSize.x, 0.0),
        float2(0.0, 0.0),
        float2(texelSize.x, 0.0),
        float2(-texelSize.x, texelSize.y),
        float2(0.0, texelSize.y),
        float2(texelSize.x, texelSize.y)
    };
    uint tw, th;
    inputTex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 fullDims = texSize;
    if (fullResolution.x > 0.0) { fullDims = fullResolution; }

    float3 conv = float3(0.0, 0.0, 0.0);
    [unroll]
    for (int i = 0; i < 9; i = i + 1)
    {
        float2 g = uv + offsets[i] * amount * renderScale;
        float3 sampleColor = inputTex.Sample(sampler_inputTex,
            (g * fullDims - tileOffset) / texSize).rgb;
        conv = conv + sampleColor * kernel[i];
    }
    // COLOR_DEFAULT_EXACT_END
    return conv;
}

float3 nm_emboss_colorGeneral(
    Texture2D inputTex,
    SamplerState sampler_inputTex,
    float2 uv,
    float2 texelSize)
{
    float kernel[9] = {-2.0, -1.0, 0.0, -1.0, 1.0, 1.0, 0.0, 1.0, 2.0};
    float2 baseOffsetsPx[9] = {
        float2(-1.0, -1.0), float2(0.0, -1.0), float2(1.0, -1.0),
        float2(-1.0,  0.0), float2(0.0,  0.0), float2(1.0,  0.0),
        float2(-1.0,  1.0), float2(0.0,  1.0), float2(1.0,  1.0)
    };
    float theta = radians(angle - 135.0);
    float ct = cos(theta);
    float st = sin(theta);

    uint tw, th;
    inputTex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 fullDims = texSize;
    if (fullResolution.x > 0.0) { fullDims = fullResolution; }

    float3 conv = float3(0.0, 0.0, 0.0);
    [unroll]
    for (int i = 0; i < 9; i = i + 1)
    {
        float2 basePx = baseOffsetsPx[i];
        float2 rotatedPx = float2(
            ct * basePx.x + st * basePx.y,
            -st * basePx.x + ct * basePx.y) * height;
        float2 offsetUV = rotatedPx * texelSize * amount * renderScale;
        float2 g = uv + offsetUV;
        float3 sampleColor = inputTex.Sample(sampler_inputTex,
            (g * fullDims - tileOffset) / texSize).rgb;
        conv = conv + sampleColor * kernel[i];
    }
    return conv;
}

float3 nm_emboss_gray(
    Texture2D inputTex,
    SamplerState sampler_inputTex,
    float2 uv,
    float3 centerRGB)
{
    float theta = radians(angle);
    float2 direction = float2(cos(theta), sin(theta));
    float2 offsetUV = direction * (height * renderScale) / fullResolution;
    float positiveLuma = dot(nm_emboss_sampleGlobal(inputTex, sampler_inputTex, uv + offsetUV), NM_EMBOSS_LUMA);
    float negativeLuma = dot(nm_emboss_sampleGlobal(inputTex, sampler_inputTex, uv - offsetUV), NM_EMBOSS_LUMA);
    float signedEdge = positiveLuma - negativeLuma;
    float edgeMagnitude = abs(signedEdge);
    float relief = 0.5 + 0.5 * signedEdge;
    float centerLuma = dot(centerRGB, NM_EMBOSS_LUMA);
    float3 sourceChroma = centerRGB - (float3)centerLuma;
    float3 tracedColor = sourceChroma * edgeMagnitude * clamp(colorAmount / 100.0, 0.0, 1.0);
    return (float3)relief + tracedColor;
}

// -----------------------------------------------------------------------------
// nm_emboss — core per-pixel evaluation.
// Full per-pixel evaluation, including global-to-local tile sampling.
// -----------------------------------------------------------------------------
float4 nm_emboss(
    Texture2D    inputTex,
    SamplerState sampler_inputTex,
    float2       fragCoord)
{
    uint tw, th;
    inputTex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 globalCoord = fragCoord + tileOffset;
    float2 globalUV = globalCoord / fullResolution;
    float2 texelSize = 1.0 / texSize;
    float2 uv = fragCoord / texSize;
    float4 origColor = inputTex.Sample(sampler_inputTex, uv);
    bool fullFrame = all(tileOffset == float2(0.0, 0.0)) && all(fullResolution == texSize);
    float2 colorTexelSize = 1.0 / fullResolution;
    if (fullFrame) { colorTexelSize = texelSize; }

    float3 result;
    [branch]
    if (STYLE == 0)
    {
        [branch]
        if (angle == 135.0 && height == 1.0)
        {
            result = nm_emboss_colorDefault(inputTex, sampler_inputTex, globalUV, colorTexelSize);
        }
        else
        {
            result = nm_emboss_colorGeneral(inputTex, sampler_inputTex, globalUV, colorTexelSize);
        }
    }
    else
    {
        result = nm_emboss_gray(inputTex, sampler_inputTex, globalUV, origColor.rgb);
    }
    return float4(clamp(result, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0)), origColor.a);
}

#endif // NM_EMBOSS_INCLUDED
