Shader "Noisemaker/synth/modPattern"
{
    // synth/modPattern — interference patterns from modulo operations.
    // Single render pass, no texture inputs (synth generator).
    // Runtime binds params via MaterialPropertyBlock using the uniform names
    // declared in ModPattern.hlsl (shape1/scale1/repeat1, shape2/scale2/repeat2,
    // shape3/scale3/repeat3, blend, smoothing, animMode, speed).

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        // Pass for program "modPattern" (definition.js passes[0].program)
        Pass
        {
            Name "modPattern"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag
            #pragma target 4.5
            // Full 32-bit float; no half/min16float promotion.
            #pragma exclude_renderers gles
            #include "ModPattern.hlsl"

            // No texture inputs (synth generator).

            float4 frag(NMVaryings i) : SV_Target
            {
                // GLSL: globalCoord = gl_FragCoord.xy + tileOffset, centred on
                // fullResolution inside nm_modPattern. NM_GlobalCoord adds tileOffset.
                float2 fragCoord = NM_GlobalCoord(i);
                return nm_modPattern(fragCoord);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
