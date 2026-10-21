Shader "Noisemaker/synth/media"
{
    // synth/media — media input (camera/video/image). Single pass "mediaInput"
    // ported from mediaInput.glsl. imageTex is an EXTERNAL texture: the runtime
    // binds it via SetGlobalTexture under the pass input name (expander emits
    // "imageTex_step_N"); Media.hlsl declares Texture2D imageTex.

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        // progName "mediaInput" (definition passes[0].program)
        Pass
        {
            Name "mediaInput"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Media.hlsl"

            float4 frag(NMVaryings i) : SV_Target
            {
                // Reference main(): st = gl_FragCoord.xy / resolution; st.y = 1-st.y;
                // then getImage() re-derives st from gl_FragCoord and imageSize.
                float2 st = NM_GlFragCoord(i) / resolution;
                st.y = 1.0 - st.y;

                return getImage(st, i);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
