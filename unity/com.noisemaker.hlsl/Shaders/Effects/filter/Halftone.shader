Shader "Noisemaker/filter/halftone"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "halftone"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_halftone
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Halftone.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_halftone(NMVaryings i) : SV_Target
            {
                return nm_halftone(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
