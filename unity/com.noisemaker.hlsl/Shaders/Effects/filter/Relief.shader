Shader "Noisemaker/filter/relief"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "rlBlurH" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_rlBlurH
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Relief.hlsl"
        ENDHLSL }
        Pass { Name "rlBlurV" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_rlBlurV
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Relief.hlsl"
        ENDHLSL }
        Pass { Name "rlShade" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_rlShade
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Relief.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
