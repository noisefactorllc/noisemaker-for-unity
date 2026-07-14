Shader "Noisemaker/filter/highPass"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "hpBlurH" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_hpBlurH
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "HighPass.hlsl"
        ENDHLSL }
        Pass { Name "hpBlurV" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_hpBlurV
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "HighPass.hlsl"
        ENDHLSL }
        Pass { Name "hpCombine" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_hpCombine
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "HighPass.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
