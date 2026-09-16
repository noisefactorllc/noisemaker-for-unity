Shader "Noisemaker/synth3d/heightmap3d"
{
    // synth3d/heightmap3d — NEW this round (reference 0ed489ec). Voxel heightfield
    // from separate height/diffuse 2D surfaces. ONE pass per frame: "precompute"
    // (passes[0]). Same VOLUME-WRITE atlas model as synth3d/noise3d: the render
    // target is a 2D ATLAS RenderTexture sized volumeSize x volumeSize^2 (rgba16f).
    // MRT (drawBuffers:2): SV_Target0 -> volumeCache (color), SV_Target1 ->
    // geoBuffer (geoOut). The runtime binds both MRT targets, sets the viewport to
    // the atlas dimensions, and sets named uniforms via MaterialPropertyBlock.
    //
    // NOTE: 3D / multi-output volume-write effect -> ships as a runtime-rendered
    // atlas RenderTexture. No Shader Graph Custom Function wrapper is provided.

    SubShader
    {
        Tags { "RenderType" = "Opaque" }

        // Volume-write fullscreen pass over the atlas: no depth test/write, no
        // blend, Cull Off (fullscreen triangle).
        ZWrite Off ZTest Always Cull Off

        // progName "precompute" (passes[0]) — volume-write, MRT (drawBuffers:2)
        Pass
        {
            Name "precompute"
            Blend Off
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_precompute
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "Heightmap3d.hlsl"
            ENDHLSL
        }
    }
    Fallback Off
}
