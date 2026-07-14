Shader "Noisemaker/filter/stamp"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "stBlurH" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_stBlurH
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Stamp.hlsl"
        ENDHLSL }
        Pass { Name "stBlurV" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_stBlurV
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Stamp.hlsl"
        ENDHLSL }
        Pass { Name "stThreshold" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_stThreshold
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Stamp.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
