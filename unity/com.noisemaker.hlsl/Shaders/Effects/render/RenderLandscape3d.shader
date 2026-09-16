Shader "Noisemaker/render/renderLandscape3d"
{
    // render/renderLandscape3d — NEW this round (reference 0ed489ec).
    // Isometric/perspective voxel raymarch with face lighting. ONE pass per
    // frame ("render"): a fullscreen draw at SCREEN resolution that raymarches
    // an input vol-tier atlas into a lit 2D image. MRT (drawBuffers:2):
    //   SV_Target0 (color)  -> outputTex        (lit RGB, alpha)
    //   SV_Target1 (geoOut) -> screenGeoBuffer  (xyz=normal*0.5+0.5, w=depth)
    //
    // INPUTS (runtime binds per definition.js inputs{}):
    //   volumeCache   <- inputTex3d  : vol-tier 2D atlas (diffuse color).
    //   analyticalGeo <- inputGeo    : geo-tier atlas (alpha = density mask,
    //                                  sampled by the body — unlike renderLit3d,
    //                                  which never samples its geo input).
    //
    // Same fullscreen-volume-consumer render state as render/renderLit3d.

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off

        // progName "landscape" (passes[0]) — raymarch + lighting, MRT drawBuffers:2
        Pass
        {
            Name "landscape"
            Blend Off
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_render
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "RenderLandscape3d.hlsl"
            ENDHLSL
        }
    }
    Fallback Off
}
