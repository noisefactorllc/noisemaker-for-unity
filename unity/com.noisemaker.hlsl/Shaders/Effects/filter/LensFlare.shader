Shader "Noisemaker/filter/lensFlare"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "lensFlare"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_lensFlare
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "LensFlare.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_lensFlare(NMVaryings i) : SV_Target
            {
                return nm_lens_flare(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
