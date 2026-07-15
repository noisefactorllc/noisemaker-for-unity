Shader "Noisemaker/filter/emboss"
{
    // filter/emboss — original color convolution plus opt-in gray directional relief.
    // Single render pass ("emboss"), with tile-safe global sampling.
    // Ported pixel-identically from shaders/effects/filter/emboss/wgsl/emboss.wgsl.

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        // Pass name matches definition.js passes[0].program = "emboss"
        Pass
        {
            Name "emboss"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag
            #pragma target 4.5
            // Full 32-bit float; no half/min16float promotion (parity requirement).
            #pragma exclude_renderers gles
            #include "Emboss.hlsl"

            // Input surface. Sampler: point, clamp-to-edge, linear (non-sRGB) — H7.
            Texture2D    inputTex;
            SamplerState sampler_inputTex;

            float4 frag(NMVaryings i) : SV_Target
            {
                return nm_emboss(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
