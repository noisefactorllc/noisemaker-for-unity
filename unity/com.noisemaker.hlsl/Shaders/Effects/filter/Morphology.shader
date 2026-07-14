Shader "Noisemaker/filter/morphology"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        Pass
        {
            Name "morphA"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_morphA
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Morphology.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_morphA(NMVaryings i) : SV_Target
            {
                return nm_morphology_a(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }

        Pass
        {
            Name "morphB"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_morphB
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Morphology.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_morphB(NMVaryings i) : SV_Target
            {
                return nm_morphology_b(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
