#ifndef NM_EXTRUDE_INCLUDED
#define NM_EXTRUDE_INCLUDED

// filter/extrude — canonical block/pyramid WGSL port.
#include "../../Include/NMFullscreen.hlsl"

int EXTRUDE_TYPE;
int DEPTH_SOURCE;
float size;
float depth;
float solidFront;

static const float NM_EXTRUDE_TOP_SIGN = 1.0;
static const float NM_EXTRUDE_SHADE_TOP = 0.8875;
static const float NM_EXTRUDE_SHADE_BOTTOM = 0.6625;
static const float NM_EXTRUDE_SHADE_LEFT = 0.969856;
static const float NM_EXTRUDE_SHADE_RIGHT = 0.580144;
static const float NM_EXTRUDE_EPS = 1e-4;

float nm_extrude_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + float3(33.33, 33.33, 33.33));
    return frac((p3.x + p3.y) * p3.z);
}

float nm_extrude_lum(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float2 nm_extrude_to_sample_uv(float2 globalPixelPos, float2 texSize)
{
    return clamp((globalPixelPos - tileOffset) / texSize, float2(0.0, 0.0), float2(1.0, 1.0));
}

float4 nm_extrude_cell_avg_3x3(Texture2D tex, SamplerState ss, float2 centerPx, float2 texSize)
{
    float sp = size * 0.25;
    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    [unroll]
    for (int j = -1; j <= 1; j++)
    {
        [unroll]
        for (int k = -1; k <= 1; k++)
        {
            float2 p = centerPx + float2((float)k, (float)j) * sp;
            sum = sum + tex.SampleLevel(ss, nm_extrude_to_sample_uv(p, texSize), 0.0);
        }
    }
    return sum * (1.0 / 9.0);
}

float nm_extrude_cell_height(Texture2D tex, SamplerState ss, float2 cellC, float2 cellIdxF, float2 texSize)
{
    [branch]
    if (DEPTH_SOURCE == 1) return nm_extrude_hash12(cellIdxF);
    return nm_extrude_lum(nm_extrude_cell_avg_3x3(tex, ss, cellC, texSize).rgb);
}

float3 nm_extrude_bary_weights(float2 p, float2 a, float2 b, float2 c)
{
    float2 v0 = b - a;
    float2 v1 = c - a;
    float2 v2 = p - a;
    float d00 = dot(v0, v0);
    float d01 = dot(v0, v1);
    float d11 = dot(v1, v1);
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float denom = d00 * d11 - d01 * d01;
    if (abs(denom) < 1e-8) return float3(-2.0, -2.0, -2.0);
    float v = (d11 * d20 - d01 * d21) / denom;
    float w = (d00 * d21 - d01 * d20) / denom;
    float u = 1.0 - v - w;
    return float3(u, v, w);
}

int nm_extrude_pyramid_tri_hit(float2 P, float2 cellC, float2 apex, float2 halfCell)
{
    float2 topC = cellC + NM_EXTRUDE_TOP_SIGN * float2(0.0, halfCell.y);
    float2 botC = cellC - NM_EXTRUDE_TOP_SIGN * float2(0.0, halfCell.y);
    float leftX = cellC.x - halfCell.x;
    float rightX = cellC.x + halfCell.x;
    float2 Cbl = float2(leftX, botC.y);
    float2 Cbr = float2(rightX, botC.y);
    float2 Ctr = float2(rightX, topC.y);
    float2 Ctl = float2(leftX, topC.y);

    float3 bc = nm_extrude_bary_weights(P, Cbl, Cbr, apex);
    if (bc.x >= -NM_EXTRUDE_EPS && bc.y >= -NM_EXTRUDE_EPS && bc.z >= -NM_EXTRUDE_EPS) return 0;
    bc = nm_extrude_bary_weights(P, Cbr, Ctr, apex);
    if (bc.x >= -NM_EXTRUDE_EPS && bc.y >= -NM_EXTRUDE_EPS && bc.z >= -NM_EXTRUDE_EPS) return 1;
    bc = nm_extrude_bary_weights(P, Ctr, Ctl, apex);
    if (bc.x >= -NM_EXTRUDE_EPS && bc.y >= -NM_EXTRUDE_EPS && bc.z >= -NM_EXTRUDE_EPS) return 2;
    bc = nm_extrude_bary_weights(P, Ctl, Cbl, apex);
    if (bc.x >= -NM_EXTRUDE_EPS && bc.y >= -NM_EXTRUDE_EPS && bc.z >= -NM_EXTRUDE_EPS) return 3;
    return -1;
}

float nm_extrude_side_shade(float2 P, float2 cellC)
{
    float2 d = P - cellC;
    float dyUp = d.y * NM_EXTRUDE_TOP_SIGN;
    if (abs(d.x) > abs(dyUp)) return d.x > 0.0 ? NM_EXTRUDE_SHADE_RIGHT : NM_EXTRUDE_SHADE_LEFT;
    return dyUp > 0.0 ? NM_EXTRUDE_SHADE_TOP : NM_EXTRUDE_SHADE_BOTTOM;
}

float4 nm_extrude(Texture2D tex, SamplerState ss, float2 pos)
{
    uint tw, th;
    tex.GetDimensions(tw, th);
    float2 texSize = float2(tw, th);
    float2 globalRes = texSize;
    if (fullResolution.x > 0.0) globalRes = fullResolution;
    // WGSL @builtin(position) is an exact half-integer pixel center. Reconstruct
    // that semantic before the discontinuous center-anchored floor() grid; the
    // fullscreen UV interpolation can otherwise land one ULP below a boundary.
    float2 P = floor(pos) + 0.5 + tileOffset;
    float2 imgCenter = globalRes * 0.5;
    float2 halfCell = float2(size * 0.5, size * 0.5);

    float2 toCenter = imgCenter - P;
    float distToCenter = length(toCenter);
    float2 stepDir = float2(0.0, 0.0);
    if (distToCenter > 0.0) stepDir = toCenter / distToCenter;

    float bestPriority = -1.0e9;
    float2 bestCenterPx = float2(0.0, 0.0);
    float bestS = 1.0;
    bool bestIsTop = false;
    int bestTri = -1;
    bool found = false;

    [loop]
    for (int walk = 0; walk < 6; walk++)
    {
        float t = min((float)walk * size, distToCenter);
        float2 samplePos = P + stepDir * t;
        float2 cellIdxF = floor((samplePos - imgCenter) / size);
        float2 cellC = imgCenter + (cellIdxF + 0.5) * size;
        float h = nm_extrude_cell_height(tex, ss, cellC, cellIdxF, texSize);
        float s = 1.0 + h * (depth / 100.0) * 0.4;

        [branch]
        if (EXTRUDE_TYPE == 1)
        {
            float2 apex = imgCenter + (cellC - imgCenter) * s;
            int tri = nm_extrude_pyramid_tri_hit(P, cellC, apex, halfCell);
            if (tri >= 0 && s > bestPriority)
            {
                bestPriority = s;
                bestCenterPx = cellC;
                bestS = s;
                bestTri = tri;
                found = true;
            }
        }
        else
        {
            float2 faceCenter = imgCenter + (cellC - imgCenter) * s;
            float2 faceHalf = halfCell * s;
            bool topHit = all(abs(P - faceCenter) <= faceHalf + NM_EXTRUDE_EPS);
            bool sideHit = (!topHit) && all(abs(P - cellC) <= halfCell);
            if (topHit || sideHit)
            {
                float priority = s + (topHit ? 1000.0 : 0.0);
                if (priority > bestPriority)
                {
                    bestPriority = priority;
                    bestCenterPx = cellC;
                    bestS = s;
                    bestIsTop = topHit;
                    found = true;
                }
            }
        }

        if (t >= distToCenter) break;
    }

    float4 outColor;
    if (!found)
    {
        float2 cellC = imgCenter + (floor((P - imgCenter) / size) + 0.5) * size;
        outColor = nm_extrude_cell_avg_3x3(tex, ss, cellC, texSize);
    }
    else if (EXTRUDE_TYPE == 1)
    {
        float2 apex = imgCenter + (bestCenterPx - imgCenter) * bestS;
        float2 topC = bestCenterPx + NM_EXTRUDE_TOP_SIGN * float2(0.0, halfCell.y);
        float2 botC = bestCenterPx - NM_EXTRUDE_TOP_SIGN * float2(0.0, halfCell.y);
        float leftX = bestCenterPx.x - halfCell.x;
        float rightX = bestCenterPx.x + halfCell.x;
        float2 Cbl = float2(leftX, botC.y);
        float2 Cbr = float2(rightX, botC.y);
        float2 Ctr = float2(rightX, topC.y);
        float2 Ctl = float2(leftX, topC.y);

        float2 Ci;
        float2 Ci1;
        float shadeConst;
        if (bestTri == 0) { Ci = Cbl; Ci1 = Cbr; shadeConst = NM_EXTRUDE_SHADE_BOTTOM; }
        else if (bestTri == 1) { Ci = Cbr; Ci1 = Ctr; shadeConst = NM_EXTRUDE_SHADE_RIGHT; }
        else if (bestTri == 2) { Ci = Ctr; Ci1 = Ctl; shadeConst = NM_EXTRUDE_SHADE_TOP; }
        else { Ci = Ctl; Ci1 = Cbl; shadeConst = NM_EXTRUDE_SHADE_LEFT; }

        float3 bc = nm_extrude_bary_weights(P, Ci, Ci1, apex);
        float apexW = clamp(bc.z, 0.0, 1.0);
        float4 baseColor;
        if (solidFront != 0.0)
        {
            baseColor = nm_extrude_cell_avg_3x3(tex, ss, bestCenterPx, texSize);
        }
        else
        {
            float2 localPos = bc.x * Ci + bc.y * Ci1 + bc.z * bestCenterPx;
            baseColor = tex.SampleLevel(ss, nm_extrude_to_sample_uv(localPos, texSize), 0.0);
        }
        float shade = lerp(1.0, shadeConst, apexW);
        outColor = float4(baseColor.rgb * shade, baseColor.a);
    }
    else if (bestIsTop)
    {
        if (solidFront != 0.0)
        {
            outColor = nm_extrude_cell_avg_3x3(tex, ss, bestCenterPx, texSize);
        }
        else
        {
            float2 localPos = imgCenter + (P - imgCenter) / bestS;
            outColor = tex.SampleLevel(ss, nm_extrude_to_sample_uv(localPos, texSize), 0.0);
        }
    }
    else
    {
        float shade = nm_extrude_side_shade(P, bestCenterPx);
        float4 meanColor = nm_extrude_cell_avg_3x3(tex, ss, bestCenterPx, texSize);
        outColor = float4(meanColor.rgb * shade, meanColor.a);
    }

    return outColor;
}

#endif
