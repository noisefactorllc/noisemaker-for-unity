Shader "Noisemaker/filter/unsharpMask"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "usmBlurH" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_usmBlurH
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "UnsharpMask.hlsl"
        ENDHLSL }
        Pass { Name "usmBlurV" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_usmBlurV
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "UnsharpMask.hlsl"
        ENDHLSL }
        Pass { Name "usmCombine" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_usmCombine
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "UnsharpMask.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
