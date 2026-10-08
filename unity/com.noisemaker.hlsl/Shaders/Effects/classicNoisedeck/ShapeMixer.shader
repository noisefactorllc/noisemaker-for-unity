Shader "Noisemaker/classicNoisedeck/shapeMixer"
{
    // classicNoisedeck/shapeMixer — two-input shape mixer. Generates a procedural
    // shape field, animates it, blends the two inputs' luminance under a selectable
    // blend mode, and colorizes via palette modes. Single render pass.
    // Properties are inspector-only; the runtime binds params via
    // MaterialPropertyBlock by their reference uniform names and binds the two
    // input surfaces to inputTex / tex.

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        // progName "shapeMixer" (definition.js passes[0].program)
        Pass
        {
            Name "shapeMixer"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag
            #pragma target 4.5
            // Full 32-bit float; no half/min16float promotion (parity requirement).
            #pragma exclude_renderers gles
            #include "ShapeMixer.hlsl"

            // Input surfaces. Samplers must be bilinear, clamp-to-edge, LINEAR
            // (non-sRGB) to match the WebGL2/WebGPU RGBA path (H7).
            Texture2D    inputTex;
            SamplerState sampler_inputTex;
            Texture2D    tex;
            SamplerState sampler_tex;

            float4 frag(NMVaryings i) : SV_Target
            {
                // GLSL: globalCoord = gl_FragCoord.xy + tileOffset; st = globalCoord /
                // fullResolution. Each input is sampled at the tile's own coordinate,
                // gl_FragCoord.xy / textureSize(input). NM_FragCoord(i) is the
                // gl_FragCoord analog; diamonds() reads it through sm_fragCoordXY.
                sm_fragCoordXY = NM_FragCoord(i);
                float2 globalCoord = NM_GlobalCoord(i);
                float2 st = globalCoord / fullResolution;

                uint w1, h1, w2, h2;
                inputTex.GetDimensions(w1, h1);
                tex.GetDimensions(w2, h2);
                float4 color1 = inputTex.Sample(sampler_inputTex, NM_FragCoord(i) / float2(w1, h1));
                float4 color2 = tex.Sample(sampler_tex, NM_FragCoord(i) / float2(w2, h2));

                return nm_shapeMixer(color1, color2, st);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
