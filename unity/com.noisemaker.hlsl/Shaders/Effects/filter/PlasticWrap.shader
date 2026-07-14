Shader "Noisemaker/filter/plasticWrap"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "pwBlurH" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_pwBlurH
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "PlasticWrap.hlsl"
        ENDHLSL }
        Pass { Name "pwBlurV" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_pwBlurV
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "PlasticWrap.hlsl"
        ENDHLSL }
        Pass { Name "pwSpec" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_pwSpec
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "PlasticWrap.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
