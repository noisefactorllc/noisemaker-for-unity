Shader "Noisemaker/filter/chrome"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "chBlurH" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_chBlurH
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Chrome.hlsl"
        ENDHLSL }
        Pass { Name "chBlurV" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_chBlurV
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Chrome.hlsl"
        ENDHLSL }
        Pass { Name "chMap" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_chMap
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Chrome.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
