Shader "Noisemaker/points/heightGrid"
{
    // points/heightGrid — NEW this round (reference 0ed489ec). Arranges every
    // pointsEmit-allocated slot into a height-mapped XZ grid, sourced from
    // separate height/diffuse 2D surfaces. 2 passes per frame in definition
    // order: agent, passthrough (same structure as points/flow).
    //
    //  Pass "agent" (MRT, drawBuffers:3): renders fullscreen across the agent
    //    STATE texture; writes the three updated state textures via MRT.
    //  Pass "passthrough": fullscreen blit of inputTex -> outputTex.
    //
    // `resolution` stays at the SCREEN size for both passes even though the
    // agent target is the smaller stateSize texture (ref 04 §10.1) — same as
    // every other Common Agent Architecture effect in this port.

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off

        // progName "agent" (passes[0]) — MRT agent state update.
        Pass
        {
            Name "agent"
            Blend Off
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_agent
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "HeightGrid.hlsl"
            ENDHLSL
        }

        // progName "passthrough" (passes[1]) — fullscreen blit input -> output.
        Pass
        {
            Name "passthrough"
            Blend Off
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag_passthrough
            #pragma target 4.5
            #pragma exclude_renderers gles
            #include "HeightGrid.hlsl"
            ENDHLSL
        }
    }
    Fallback Off
}
