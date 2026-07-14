Shader "Noisemaker/filter/patchwork"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "patchwork"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_patchwork
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Patchwork.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_patchwork(NMVaryings i) : SV_Target
            {
                return nm_patchwork(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
