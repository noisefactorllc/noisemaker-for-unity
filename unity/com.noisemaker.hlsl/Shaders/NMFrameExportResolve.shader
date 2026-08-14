Shader "Noisemaker/FrameExportResolve"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        ZWrite Off ZTest Always Cull Off Blend Off

        Pass
        {
            Name "resolve"
            HLSLPROGRAM
            #pragma vertex NMVertFullscreen
            #pragma fragment frag
            #pragma target 4.5
            #include "Include/NMFullscreen.hlsl"

            Texture2D _NMExportSource;
            float4 _NMExportExtent;
            int _NMExportAlphaMode;

            float4 frag(NMVaryings input) : SV_Target
            {
                int2 coord = min(int2(input.uv * _NMExportExtent.xy),
                    int2(_NMExportExtent.xy) - 1);
                float4 color = _NMExportSource.Load(int3(coord, 0));
                if (_NMExportAlphaMode == 1)
                    color.a = 1.0;
                else if (_NMExportAlphaMode == 2)
                    color.rgb *= color.a;
                return color;
            }
            ENDHLSL
        }
    }
    Fallback Off
}
