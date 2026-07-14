Shader "Noisemaker/filter/mosaicTiles"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off
        Pass
        {
            Name "mosaicTiles"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_mosaicTiles
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "MosaicTiles.hlsl"
            Texture2D inputTex;
            SamplerState sampler_inputTex;
            float4 frag_mosaicTiles(NMVaryings i) : SV_Target
            {
                return nm_mosaic_tiles(inputTex, sampler_inputTex, NM_FragCoord(i));
            }
            ENDHLSL
        }
    }
    Fallback Off
}
