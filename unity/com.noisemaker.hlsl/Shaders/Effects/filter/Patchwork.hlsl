#ifndef NM_PATCHWORK_INCLUDED
#define NM_PATCHWORK_INCLUDED

// filter/patchwork — canonical center-anchored needlepoint-grid WGSL port.
#include "../../Include/NMFullscreen.hlsl"

float squareSize;
float relief;
float lightAngle;

float nm_patchwork_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float2 nm_patchwork_to_sample_uv(float2 globalPixelPos, float2 texSize)
{
    return clamp((globalPixelPos - tileOffset) / texSize, float2(0.0, 0.0), float2(1.0, 1.0));
}

float4 nm_patchwork_cell_avg_3x3(Texture2D tex, SamplerState ss, float2 centerPx, float2 texSize)
{
    float sp = squareSize * 0.25;
    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    [unroll]
    for (int j = -1; j <= 1; j++)
    {
        [unroll]
        for (int k = -1; k <= 1; k++)
        {
            float2 p = centerPx + float2((float)k, (float)j) * sp;
            sum += tex.SampleLevel(ss, nm_patchwork_to_sample_uv(p, texSize), 0.0);
        }
    }
    return sum * (1.0 / 9.0);
}

float4 nm_patchwork(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 fullDims = texSize;
    if (fullResolution.x > 0.0) fullDims = fullResolution;
    // WGSL @builtin(position) is an exact half-integer pixel center. Reconstruct
    // that semantic before the discontinuous center-anchored floor() grid; the
    // fullscreen UV interpolation can otherwise land one ULP below a boundary.
    float2 globalCoord = floor(pos) + 0.5 + tileOffset;
    float2 uv = pos / texSize;
    float4 srcOwn = tex.Sample(ss, uv);

    float2 imgCenter = fullDims * 0.5;
    float2 relPx = globalCoord - imgCenter;
    float2 cellIdxF = floor(relPx / squareSize);
    float2 localPx = relPx - cellIdxF * squareSize;
    float2 cellCenter = imgCenter + (cellIdxF + 0.5) * squareSize;

    float3 cellColor = nm_patchwork_cell_avg_3x3(tex, ss, cellCenter, texSize).rgb;
    float h = nm_patchwork_lum(cellColor);
    float topFaceShade = 0.9 + 0.2 * (h - 0.5);

    float rimPx = 0.15 * squareSize;
    float dLeft = localPx.x;
    float dRight = squareSize - localPx.x;
    float dBottom = localPx.y;
    float dTop = squareSize - localPx.y;
    float dMin = min(min(dLeft, dRight), min(dBottom, dTop));

    float bevelMul = 1.0;
    if (dMin < rimPx)
    {
        float2 neighborIdx = cellIdxF;
        float2 edgeNormal;
        if (dMin == dLeft) { neighborIdx.x -= 1.0; edgeNormal = float2(-1.0, 0.0); }
        else if (dMin == dRight) { neighborIdx.x += 1.0; edgeNormal = float2(1.0, 0.0); }
        else if (dMin == dBottom) { neighborIdx.y -= 1.0; edgeNormal = float2(0.0, -1.0); }
        else { neighborIdx.y += 1.0; edgeNormal = float2(0.0, 1.0); }

        float2 neighborCenter = imgCenter + (neighborIdx + 0.5) * squareSize;
        float hNeighbor = nm_patchwork_lum(nm_patchwork_cell_avg_3x3(tex, ss, neighborCenter, texSize).rgb);
        float dh = h - hNeighbor;
        float a = radians(lightAngle);
        float2 lightDir = float2(cos(a), sin(a));
        float signTerm = dot(edgeNormal, lightDir);
        bevelMul = 1.0 + 0.35 * (relief / 100.0) * sign(dh) * signTerm;
    }

    float3 result = clamp(cellColor * topFaceShade * bevelMul, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
    return float4(result, srcOwn.a);
}

#endif
