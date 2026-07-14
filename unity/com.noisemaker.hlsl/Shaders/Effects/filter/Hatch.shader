Shader "Noisemaker/filter/hatch"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        Pass
        {
            Name "hatch"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_hatch
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Hatch.hlsl"

            Texture2D inputTex;
            SamplerState sampler_inputTex;

            float4 frag_hatch(NMVaryings i) : SV_Target
            {
                return nm_hatch(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
