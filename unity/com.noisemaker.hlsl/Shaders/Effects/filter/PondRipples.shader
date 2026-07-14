Shader "Noisemaker/filter/pondRipples"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "pondRipples"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_pondRipples
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "PondRipples.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_pondRipples(NMVaryings i) : SV_Target
            {
                return nm_pond_ripples(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
