Shader "Noisemaker/filter/craquelure"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "craquelure"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_craquelure
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Craquelure.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_craquelure(NMVaryings i) : SV_Target
            {
                return nm_craquelure(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
