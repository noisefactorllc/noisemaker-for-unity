Shader "Noisemaker/mixer/uvRemap"
{
    // mixer/uvRemap — remap UVs of one input using color channels of another.
    // Single render pass. Properties are for the inspector only; the runtime
    // binds params via MaterialPropertyBlock by their reference uniform names
    // and binds the two input surfaces to inputTex / tex.

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        // progName "uvRemap" (definition.js passes[0].program)
        Pass
        {
            Name "uvRemap"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag
            #pragma target 4.5
            // Full 32-bit float; no half/min16float promotion (parity requirement).
            #pragma exclude_renderers gles

            // Input surfaces. Samplers must be bilinear, clamp-to-edge, LINEAR
            // (non-sRGB) to match the WebGL2/WebGPU RGBA path (H7). Declared
            // BEFORE the #include so UvRemap.hlsl resolves them as globals
            // (HLSL cannot pass Texture2D/SamplerState as function params).
            Texture2D    inputTex;
            SamplerState sampler_inputTex;
            Texture2D    tex;
            SamplerState sampler_tex;

            #include "UvRemap.hlsl"

            float4 frag(NMVaryings i) : SV_Target
            {
                // GLSL:
                //   vec2 localUV = gl_FragCoord.xy / resolution;
                //   vec4 colorA = texture(inputTex, localUV);
                //   vec4 colorB = texture(tex, localUV);
                // Same local UV (render-target size, no tileOffset) samples BOTH
                // textures.
                float2 st = NM_FragCoord(i) / resolution;

                float4 colorA = inputTex.Sample(sampler_inputTex, st);
                float4 colorB = tex.Sample(sampler_tex, st);

                return nm_uvRemap(colorA, colorB);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
