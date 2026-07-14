Shader "Noisemaker/filter/extrude"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "extrude"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_extrude
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Extrude.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_extrude(NMVaryings i) : SV_Target
            {
                return nm_extrude(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
