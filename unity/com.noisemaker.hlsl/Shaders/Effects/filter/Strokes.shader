Shader "Noisemaker/filter/strokes"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "stkSmear" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_stkSmear
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Strokes.hlsl"
        ENDHLSL }
        Pass { Name "stkPost" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_stkPost
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Strokes.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
