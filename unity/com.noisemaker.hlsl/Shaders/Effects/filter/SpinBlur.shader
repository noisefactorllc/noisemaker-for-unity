Shader "Noisemaker/filter/spinBlur"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "spinBlur"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_spinBlur
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "SpinBlur.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_spinBlur(NMVaryings i) : SV_Target
            {
                return nm_spin_blur(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
