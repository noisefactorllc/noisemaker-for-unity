// synth/media — media input shader (programs: mediaInput).
// Port of shaders/effects/synth/media/glsl/mediaInput.glsl (upstream d3b5238c).
// Normalizes camera/video/image textures, crop + tilt + tile + flip controls,
// preserving aspect ratio. Offset remapping never samples outside the source.

#include "NMFullscreen.hlsl"

// External texture (definition externalTexture: "imageTex"). Bound by the
// runtime as a SetGlobalTexture under the pass input's uniform name.
Texture2D    imageTex;   SamplerState sampler_imageTex;

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) ------
int   position;    // globals.position   default 4 (midCenter)
int   tiling;      // globals.tiling     default 0 (none)
int   flip;        // globals.flip       default 0 (none)
float rotation;    // globals.rotation   default 0
float scaleAmt;    // globals.scaleAmt   default 100
float offsetX;     // globals.offsetX    default 0
float offsetY;     // globals.offsetY    default 0
float3 bgColor;    // globals.bgColor    default [0,0,0]
float bgAlpha;     // globals.bgAlpha    default 0
float2 imageSize;  // globals.imageSize  default [1024,1024]

#define PI 3.14159265359
#define TAU 6.28318530718

float map(float value, float inMin, float inMax, float outMin, float outMax)
{
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

float2 rotate2D(float2 st, float rot)
{
    rot = map(rot, -180.0, 180.0, 0.5, -0.5);
    float angle = rot * TAU * -1.0;

    // Handle aspect ratio of input media
    float2 size = imageSize;
    float aspect = size.x / size.y;
    st -= float2(0.5 * aspect, 0.5);
    st = mul(float2x2(cos(angle), -sin(angle), sin(angle), cos(angle)), st);
    st += float2(0.5 * aspect, 0.5);
    return st;
}

float2 mediaTile(float2 st)
{
    if (tiling == 0) {
        // no tiling
        return st;
    } else if (tiling == 1) {
        // tile both
        return frac(st);
    } else if (tiling == 2) {
        // horiz only
        return float2(frac(st.x), st.y);
    } else if (tiling == 3) {
        // vert only
        return float2(st.x, frac(st.y));
    }
    return st;
}

// External uploads use straight alpha. Interpolate premultiplied texels so
// transparent pixels cannot darken edges or bleed their hidden RGB into them.
float4 mediaTexel(int2 p, int2 size)
{
    float4 c = imageTex.Load(int3(clamp(p, int2(0, 0), size - int2(1, 1)), 0));
    return float4(c.rgb * c.a, c.a);
}

float4 sampleMedia(float2 uv)
{
    int2 size;
    uint sw, sh;
    imageTex.GetDimensions(sw, sh);
    size = int2((int)sw, (int)sh);
    float2 p = uv * float2(size) - 0.5;
    int2 lo = (int2)floor(p);
    float2 f = frac(p);
    return lerp(lerp(mediaTexel(lo, size), mediaTexel(lo + int2(1, 0), size), f.x),
                lerp(mediaTexel(lo + int2(0, 1), size), mediaTexel(lo + int2(1, 1), size), f.x), f.y);
}

// gl_FragCoord analog: pixel-centered target coords.
float2 NM_GlFragCoord(NMVaryings i) { return floor(i.uv * _NM_Resolution.xy) + 0.5; }

float4 getImage(float2 stIn, NMVaryings i)
{
    float2 size = imageSize;
    float2 frag = NM_GlFragCoord(i);
    // Under tiled print export gl_FragCoord is tile-local. Add the tile's
    // global offset so every tile and the untiled reference sample the same
    // absolute image pixel. Branch on the runtime offset so the untiled
    // path keeps the original expression bit-for-bit across compilers with
    // relaxed math (tileOffset is 0 when not tiling).
    float2 st;
    if (tileOffset.x == 0.0 && tileOffset.y == 0.0) {
        st = frag / size;
    } else {
        st = (frag + tileOffset) / size;
    }
    st.y = 1.0 - st.y;

    float scale = 100.0 / scaleAmt;

    if (scale == 0.0) {
        scale = 1.0;
    }
    st *= scale;

    // Keep the original untiled math exact on both backends.
    if (fullResolution.x > 0.0 && (fullResolution.x != resolution.x || fullResolution.y != resolution.y)) {
        // Position adjustments based on anchor point
        if (position == 0) {
            // top left
            st.y += (fullResolution.y / size.y * scale) - (scale - (1.0 / size.y * scale));
        } else if (position == 1) {
            // top center
            st.x -= (fullResolution.x / size.x * scale * 0.5) - (0.5 - (1.0 / size.x * scale));
            st.y += (fullResolution.y / size.y * scale) - (scale - (1.0 / size.y * scale));
        } else if (position == 2) {
            // top right
            st.x -= (fullResolution.x / size.x * scale) - (1.0 - (1.0 / size.x * scale));
            st.y += (fullResolution.y / size.y * scale) - (scale - (1.0 / size.y * scale));
        } else if (position == 3) {
            // mid left
            st.y += (fullResolution.y / size.y * scale * 0.5) + (0.5 - (1.0 / size.y * scale)) - (scale);
        } else if (position == 4) {
            // mid center
            st.x -= (fullResolution.x / size.x * scale * 0.5) - (0.5 - (1.0 / size.x * scale));
            st.y += (fullResolution.y / size.y * scale * 0.5) + (0.5 - (1.0 / size.y * scale)) - (scale);
        } else if (position == 5) {
            // mid right
            st.x -= (fullResolution.x / size.x * scale) - (1.0 - (1.0 / size.x * scale));
            st.y += (fullResolution.y / size.y * scale * 0.5) + (0.5 - (1.0 / size.y * scale)) - (scale);
        } else if (position == 6) {
            // bottom left
            st.y += 1.0 - (scale - (1.0 / size.y * scale));
        } else if (position == 7) {
            // bottom center
            st.x -= (fullResolution.x / size.x * scale * 0.5) - (0.5 - (1.0 / size.x * scale));
            st.y += 1.0 - (scale - (1.0 / size.y * scale));
        } else if (position == 8) {
            // bottom right
            st.x -= (fullResolution.x / size.x * scale) - (1.0 - (1.0 / size.x * scale));
            st.y += 1.0 - (scale - (1.0 / size.y * scale));
        }

        st.x -= map(offsetX, -100.0, 100.0, -fullResolution.x / size.x * scale, fullResolution.x / size.x * scale) * 1.5;
        st.y -= map(offsetY, -100.0, 100.0, -fullResolution.y / size.y * scale, fullResolution.y / size.y * scale) * 1.5;
    } else {
        // Position adjustments based on anchor point
        if (position == 0) {
            // top left
            st.y += (resolution.y / size.y * scale) - (scale - (1.0 / size.y * scale));
        } else if (position == 1) {
            // top center
            st.x -= (resolution.x / size.x * scale * 0.5) - (0.5 - (1.0 / size.x * scale));
            st.y += (resolution.y / size.y * scale) - (scale - (1.0 / size.y * scale));
        } else if (position == 2) {
            // top right
            st.x -= (resolution.x / size.x * scale) - (1.0 - (1.0 / size.x * scale));
            st.y += (resolution.y / size.y * scale) - (scale - (1.0 / size.y * scale));
        } else if (position == 3) {
            // mid left
            st.y += (resolution.y / size.y * scale * 0.5) + (0.5 - (1.0 / size.y * scale)) - (scale);
        } else if (position == 4) {
            // mid center
            st.x -= (resolution.x / size.x * scale * 0.5) - (0.5 - (1.0 / size.x * scale));
            st.y += (resolution.y / size.y * scale * 0.5) + (0.5 - (1.0 / size.y * scale)) - (scale);
        } else if (position == 5) {
            // mid right
            st.x -= (resolution.x / size.x * scale) - (1.0 - (1.0 / size.x * scale));
            st.y += (resolution.y / size.y * scale * 0.5) + (0.5 - (1.0 / size.y * scale)) - (scale);
        } else if (position == 6) {
            // bottom left
            st.y += 1.0 - (scale - (1.0 / size.y * scale));
        } else if (position == 7) {
            // bottom center
            st.x -= (resolution.x / size.x * scale * 0.5) - (0.5 - (1.0 / size.x * scale));
            st.y += 1.0 - (scale - (1.0 / size.y * scale));
        } else if (position == 8) {
            // bottom right
            st.x -= (resolution.x / size.x * scale) - (1.0 - (1.0 / size.x * scale));
            st.y += 1.0 - (scale - (1.0 / size.y * scale));
        }

        st.x -= map(offsetX, -100.0, 100.0, -resolution.x / size.x * scale, resolution.x / size.x * scale) * 1.5;
        st.y -= map(offsetY, -100.0, 100.0, -resolution.y / size.y * scale, resolution.y / size.y * scale) * 1.5;
    }

    // Correct for aspect ratio before rotation
    st.x *= size.x / size.y;
    // Zero rotation is an exact identity. Avoid backend-dependent rounding
    // in the remap/trigonometry path before bilinear texture filtering.
    if (rotation != 0.0) st = rotate2D(st, rotation);
    st.x /= size.x / size.y;

    st = mediaTile(st);

    // Nudge 1px up and left to center properly
    st += 1.0 / size;

    // Flip and mirror operations
    if (flip == 1) {
       // flip both
       st.x = 1.0 - st.x;
       st.y = 1.0 - st.y;
    } else if (flip == 2) {
       // flip h
       st.x = 1.0 - st.x;
    } else if (flip == 3) {
       // flip v
       st.y = 1.0 - st.y;
    } else if (flip == 11) {
       // mirror lr
       if (st.x > 0.5) {
           st.x = 1.0 - st.x;
       }
    } else if (flip == 12) {
       // mirror rl
       if (st.x < 0.5) {
           st.x = 1.0 - st.x;
       }
    } else if (flip == 13) {
       // mirror ud
       if (st.y > 0.5) {
           st.y = 1.0 - st.y;
       }
    } else if (flip == 14) {
       // mirror du
       if (st.y < 0.5) {
           st.y = 1.0 - st.y;
       }
    } else if (flip == 15) {
       // mirror lr ud
       if (st.x > 0.5) {
           st.x = 1.0 - st.x;
       }
       if (st.y > 0.5) {
           st.y = 1.0 - st.y;
       }
    } else if (flip == 16) {
       // mirror lr du
       if (st.x > 0.5) {
           st.x = 1.0 - st.x;
       }
       if (st.y < 0.5) {
           st.y = 1.0 - st.y;
       }
    } else if (flip == 17) {
       // mirror rl ud
       if (st.x < 0.5) {
           st.x = 1.0 - st.x;
       }
       if (st.y > 0.5) {
           st.y = 1.0 - st.y;
       }
    } else if (flip == 18) {
       // mirror rl du
       if (st.x < 0.5) {
           st.x = 1.0 - st.x;
       }
       if (st.y < 0.5) {
           st.y = 1.0 - st.y;
       }
    }

    float4 text = sampleMedia(st);

    if (st.x < 0.0 || st.x > 1.0 || st.y < 0.0 || st.y > 1.0) {
        // Don't draw texture if out of coordinate bounds
        return float4(bgColor * bgAlpha, bgAlpha);
    }

    return text;
}
