#ifndef NM_SG_PARALLAX_INCLUDED
#define NM_SG_PARALLAX_INCLUDED

// =============================================================================
// ShaderGraph Custom Function wrapper for filter/parallax.
//
// Single-pass filter: pseudo-3D perspective shift from a height map —
// ray-marched parallax occlusion mapping with a configurable pivot height.
// Wire InputTex into HeightMap to displace the input by its own luminosity
// (that is the runtime default).
//
// All helpers mirrored VERBATIM from Shaders/Effects/filter/Parallax.hlsl,
// name-prefixed `nmsg_` to avoid symbol clashes. Self-contained; does NOT
// include NMFullscreen.hlsl or NMCore.hlsl.
//
// TODO(verify): SS must be a clamp, non-sRGB (linear) sampler state to match
// the runtime's sampling path (H7; the runtime surfaces are point/clamp —
// see TextureStore).
// =============================================================================

static const int   nmsg_PARALLAX_MARCH_STEPS = 32;
static const float nmsg_PARALLAX_SHIFT_SCALE = 0.15;

float nmsg_parallax_getLuminosity(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

float nmsg_parallax_getHeight(
    UnityTexture2D HeightMap, UnitySamplerState SS, float2 uv)
{
    float3 rgb = SAMPLE_TEXTURE2D_LOD(HeightMap.tex, SS.samplerstate, uv, 0.0).rgb;
    return nmsg_parallax_getLuminosity(rgb);
}

// Shader Graph Custom Function entry point.
// UV must be the input-texture-space 0..1 coordinate (fragCoord / texDims).
void NM_Parallax_float(
    UnityTexture2D InputTex,
    UnityTexture2D HeightMap,
    UnitySamplerState SS,
    float2  UV,
    float3  Direction,
    float   Pivot,
    out float4 Out)
{
    float3 v = float3(0.0, 0.0, 1.0);
    if (length(Direction) > 0.0)
    {
        v = normalize(Direction);
    }
    float2 shift = v.xy * nmsg_PARALLAX_SHIFT_SCALE;

    // View ray crosses this fragment's UV at height == pivot
    float  t     = 1.0;
    float2 rayUV = UV + shift * (1.0 - Pivot);
    float  f     = t - nmsg_parallax_getHeight(HeightMap, SS, rayUV);

    [branch]
    if (f > 0.0)
    {
        float stepSize = 1.0 / (float)nmsg_PARALLAX_MARCH_STEPS;
        [loop]
        for (int j = 1; j <= nmsg_PARALLAX_MARCH_STEPS; j = j + 1)
        {
            float  prevF  = f;
            float2 prevUV = rayUV;
            t     = 1.0 - (float)j * stepSize;
            rayUV = UV + shift * (t - Pivot);
            f     = t - nmsg_parallax_getHeight(HeightMap, SS, rayUV);
            if (f <= 0.0)
            {
                // Refine: interpolate between the straddling samples
                float wgt = f / (f - prevF);
                rayUV = lerp(rayUV, prevUV, wgt);
                break;
            }
        }
    }

    Out = SAMPLE_TEXTURE2D_LOD(InputTex.tex, SS.samplerstate, rayUV, 0.0);
}

#endif // NM_SG_PARALLAX_INCLUDED
