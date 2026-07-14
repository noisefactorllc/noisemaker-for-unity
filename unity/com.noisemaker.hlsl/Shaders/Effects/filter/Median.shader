Shader "Noisemaker/filter/median"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "median"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_median
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Median.hlsl"
            Texture2D inputTex;
            float4 frag_median(NMVaryings i) : SV_Target
            {
                return nm_median(inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
