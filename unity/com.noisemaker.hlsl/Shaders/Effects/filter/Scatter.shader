Shader "Noisemaker/filter/scatter"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        Pass
        {
            Name "scatterJitter"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_scatterJitter
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Scatter.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_scatterJitter(NMVaryings i) : SV_Target
            {
                return nm_scatter_jitter(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }

        Pass
        {
            Name "scatterSmooth"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_scatterSmooth
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Scatter.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_scatterSmooth(NMVaryings i) : SV_Target
            {
                return nm_scatter_smooth(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
