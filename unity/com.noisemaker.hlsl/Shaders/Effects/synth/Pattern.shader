Shader "Noisemaker/synth/pattern"
{
    // synth/pattern — geometric pattern generator. Single render pass.
    // Runtime binds params via MaterialPropertyBlock by the names declared in
    // Pattern.hlsl (patternType, scale, thickness, smoothness, rotation, skew,
    // animation, speed, fgColor, bgColor). Properties block is for inspector
    // convenience only; values come from MaterialPropertyBlock at render time.

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        // progName "pattern" (definition.js passes[0].program)
        Pass
        {
            Name "pattern"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag
            #pragma target 4.5
            // Full 32-bit float; no half/min16float promotion.
            #pragma exclude_renderers gles
            #include "Pattern.hlsl"

            // No texture inputs (synth generator).

            float4 frag(NMVaryings i) : SV_Target
            {
                // GLSL: globalCoord = gl_FragCoord.xy + tileOffset, normalized by
                // fullResolution inside nm_pattern. NM_GlobalCoord adds tileOffset.
                return nm_pattern(NM_GlobalCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
