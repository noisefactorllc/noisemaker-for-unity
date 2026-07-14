Shader "Noisemaker/filter/photocopy"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "pcBlurH" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_pcBlurH
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Photocopy.hlsl"
        ENDHLSL }
        Pass { Name "pcBlurV" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_pcBlurV
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Photocopy.hlsl"
        ENDHLSL }
        Pass { Name "pcCombine" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_pcCombine
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Photocopy.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
