Shader "Noisemaker/filter/directionalBlur"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        Pass
        {
            Name "directionalBlur"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_directionalBlur
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "DirectionalBlur.hlsl"

            Texture2D inputTex;
            SamplerState sampler_inputTex;

            float4 frag_directionalBlur(NMVaryings i) : SV_Target
            {
                return nm_directional_blur(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
