Shader "Noisemaker/filter/oilPaint"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass { Name "oilFlatten" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_oilFlatten
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "OilPaint.hlsl"
        ENDHLSL }
        Pass { Name "oilPost" HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_oilPost
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "OilPaint.hlsl"
        ENDHLSL }
    }
    Fallback Off
}
