Shader "Noisemaker/filter/parallax"
{
    // filter/parallax — pseudo-3D perspective shift from a height map.
    // Ray-marched parallax occlusion mapping with a configurable pivot height.
    // Single render pass.
    // Runtime binds all uniforms via MaterialPropertyBlock using the exact names
    // from definition.js globals[*].uniform; textures (inputTex, heightMap) bind
    // by pass-input name.


    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        // progName "parallax" (definition.js passes[0].program)
        Pass
        {
            Name "parallax"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment NMFrag_parallax
            #pragma target 4.5
            // Full 32-bit float; no half/min16float promotion (parity requirement).
            #pragma exclude_renderers gles
            #include "Parallax.hlsl"
            ENDHLSL
        }
    }
    Fallback Off
}
