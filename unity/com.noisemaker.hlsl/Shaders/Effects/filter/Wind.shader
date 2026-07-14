Shader "Noisemaker/filter/wind"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "wind"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_wind
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Wind.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_wind(NMVaryings i) : SV_Target
            {
                return nm_wind(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
