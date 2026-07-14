Shader "Noisemaker/filter/watercolor"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        Pass
        {
            Name "wcSeed"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_wcSeed
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Watercolor.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_wcSeed(NMVaryings i) : SV_Target
            {
                return nm_watercolor_seed(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }

        Pass
        {
            Name "wcSimplify"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_wcSimplify
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Watercolor.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_wcSimplify(NMVaryings i) : SV_Target
            {
                return nm_watercolor_simplify(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }

        Pass
        {
            Name "wcComposite"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_wcComposite
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Watercolor.hlsl"
            Texture2D inputTex;
            Texture2D simplifiedTex;
            SamplerState sampler_inputTex;
            float4 frag_wcComposite(NMVaryings i) : SV_Target
            {
                return nm_watercolor_composite(
                    inputTex, simplifiedTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
