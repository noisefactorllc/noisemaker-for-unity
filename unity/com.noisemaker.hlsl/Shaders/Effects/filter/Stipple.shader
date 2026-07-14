Shader "Noisemaker/filter/stipple"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        Pass
        {
            Name "stipple"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_stipple
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Stipple.hlsl"

            Texture2D inputTex;
            SamplerState sampler_inputTex;

            float4 frag_stipple(NMVaryings i) : SV_Target
            {
                return nm_stipple(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
