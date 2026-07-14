#ifndef NM_EFFECT_OIL_PAINT_INCLUDED
#define NM_EFFECT_OIL_PAINT_INCLUDED

#include "../../Include/NMFullscreen.hlsl"

Texture2D inputTex;
Texture2D flatTex;
SamplerState sampler_inputTex;

int MODE;
float size;
float detail;
float textureAmount;
float seed;

float nm_oil_hash12(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float nm_oil_vnoise(float2 p)
{
    float2 cell = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(nm_oil_hash12(cell), nm_oil_hash12(cell + float2(1.0, 0.0)), u.x),
                lerp(nm_oil_hash12(cell + float2(0.0, 1.0)), nm_oil_hash12(cell + float2(1.0, 1.0)), u.x), u.y);
}

float nm_oil_fbm(float2 p)
{
    float v = 0.0;
    float a = 0.5;
    [unroll]
    for (int octave = 0; octave < 5; octave++)
    {
        v += a * nm_oil_vnoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

float nm_oil_lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

float2 nm_oil_lumGradientFlat(float2 uv)
{
    uint w, h;
    flatTex.GetDimensions(w, h);
    float2 px = 1.0 / float2(w, h);
    float tl = nm_oil_lum(flatTex.Sample(sampler_inputTex, uv + px * float2(-1.0,  1.0)).rgb);
    float l  = nm_oil_lum(flatTex.Sample(sampler_inputTex, uv + px * float2(-1.0,  0.0)).rgb);
    float bl = nm_oil_lum(flatTex.Sample(sampler_inputTex, uv + px * float2(-1.0, -1.0)).rgb);
    float tr = nm_oil_lum(flatTex.Sample(sampler_inputTex, uv + px * float2( 1.0,  1.0)).rgb);
    float r  = nm_oil_lum(flatTex.Sample(sampler_inputTex, uv + px * float2( 1.0,  0.0)).rgb);
    float br = nm_oil_lum(flatTex.Sample(sampler_inputTex, uv + px * float2( 1.0, -1.0)).rgb);
    float t  = nm_oil_lum(flatTex.Sample(sampler_inputTex, uv + px * float2( 0.0,  1.0)).rgb);
    float b  = nm_oil_lum(flatTex.Sample(sampler_inputTex, uv + px * float2( 0.0, -1.0)).rgb);
    return float2(tr + 2.0 * r + br - tl - 2.0 * l - bl,
                  tl + 2.0 * t + tr - bl - 2.0 * b - br);
}

float3 nm_oil_tent3x3(float2 uv)
{
    uint w, h;
    flatTex.GetDimensions(w, h);
    float2 px = 1.0 / float2(w, h);
    float3 sum = 0.0;
    float wsum = 0.0;
    [unroll]
    for (int dy = -1; dy <= 1; dy++)
    {
        [unroll]
        for (int dx = -1; dx <= 1; dx++)
        {
            float weight = (dx == 0 ? 2.0 : 1.0) * (dy == 0 ? 2.0 : 1.0);
            sum += flatTex.Sample(sampler_inputTex, uv + float2(dx, dy) * px).rgb * weight;
            wsum += weight;
        }
    }
    return sum / wsum;
}

float nm_oil_sCurve(float x)
{
    float t = clamp(x, 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

float3 nm_oil_modeColor(float2 uv, float3 c, float2 globalCoord)
{
    if (MODE == 0) return c;
    if (MODE == 1)
    {
        float3 blurred = nm_oil_tent3x3(uv);
        return c + (c - blurred) * (detail / 25.0);
    }
    if (MODE == 2)
    {
        float levels = floor(lerp(8.0, 3.0, detail / 100.0) + 0.5);
        float3 poster = floor(c * levels) / levels;
        float gradMag = length(nm_oil_lumGradientFlat(uv));
        float edgeDarken = clamp(gradMag * 1.5, 0.0, 1.0) * 0.15;
        return poster * (1.0 - edgeDarken);
    }
    if (MODE == 3)
    {
        float gradMag = length(nm_oil_lumGradientFlat(uv));
        float3 darkened = c * (1.0 - 0.6 * (detail / 100.0) * gradMag);
        return float3(nm_oil_sCurve(darkened.x), nm_oil_sCurve(darkened.y), nm_oil_sCurve(darkened.z));
    }
    if (MODE == 4)
    {
        float3 blurred = nm_oil_tent3x3(uv);
        return lerp(c, blurred, detail / 100.0);
    }
    float band = nm_oil_fbm((globalCoord + (float)((int)seed) * 37.0) / (4.0 + size));
    float shift = (band * 2.0 - 1.0) * (detail / 100.0) * 0.25;
    return clamp(c + shift.xxx, 0.0, 1.0);
}

float4 NMFrag_oilFlatten(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    int2 dims = int2(w, h);
    int2 icenter = int2(floor(NM_FragCoord(i)));
    float radius = size;
    if (MODE == 0) radius = min(size, 3.0);
    float fr = clamp(radius, 1.0, 12.0);
    float frSq = fr * fr;
    int sampleLimit = (int)ceil(fr);

    precise float3 m0=0,m1=0,m2=0,m3=0,m4=0,m5=0,m6=0,m7=0;
    precise float3 q0=0,q1=0,q2=0,q3=0,q4=0,q5=0,q6=0,q7=0;
    float n0=0,n1=0,n2=0,n3=0,n4=0,n5=0,n6=0,n7=0;

    [loop]
    for (int y = -sampleLimit; y <= sampleLimit; y++)
    {
        [loop]
        for (int x = -sampleLimit; x <= sampleLimit; x++)
        {
            float2 d = float2(x, y);
            if (abs(d.x) > fr || abs(d.y) > fr || dot(d, d) > frSq) continue;
            if (fr > 8.0 && dot(d, d) > 64.0 && (abs(x) + abs(y)) % 2 != 0) continue;
            int2 sc = clamp(icenter + int2(x, y), int2(0, 0), dims - int2(1, 1));
            precise float3 c = inputTex.Load(int3(sc, 0)).rgb;
            precise float3 cc = c * c;
            if (x == 0 && y == 0) { m4+=c; q4+=cc; n4+=1.0; }
            else if (d.x > 0.0 && d.y >= 0.0)
            {
                if (abs(d.x) <= abs(d.y)) { m5+=c; q5+=cc; n5+=1.0; }
                else { m4+=c; q4+=cc; n4+=1.0; }
            }
            else if (d.x <= 0.0 && d.y > 0.0)
            {
                if (abs(d.x) < abs(d.y)) { m6+=c; q6+=cc; n6+=1.0; }
                else { m7+=c; q7+=cc; n7+=1.0; }
            }
            else if (d.x < 0.0 && d.y <= 0.0)
            {
                if (abs(d.x) <= abs(d.y)) { m1+=c; q1+=cc; n1+=1.0; }
                else { m0+=c; q0+=cc; n0+=1.0; }
            }
            else
            {
                if (abs(d.x) < abs(d.y)) { m2+=c; q2+=cc; n2+=1.0; }
                else { m3+=c; q3+=cc; n3+=1.0; }
            }
        }
    }

    precise float3 bestC = 0.0;
    precise float bestV = 1e9;
    if(n0>=1.0){precise float3 m=m0/n0;precise float3 v=q0/n0-m*m;precise float tv=v.x+v.y+v.z;if(tv<bestV){bestV=tv;bestC=m;}}
    if(n1>=1.0){precise float3 m=m1/n1;precise float3 v=q1/n1-m*m;precise float tv=v.x+v.y+v.z;if(tv<bestV){bestV=tv;bestC=m;}}
    if(n2>=1.0){precise float3 m=m2/n2;precise float3 v=q2/n2-m*m;precise float tv=v.x+v.y+v.z;if(tv<bestV){bestV=tv;bestC=m;}}
    if(n3>=1.0){precise float3 m=m3/n3;precise float3 v=q3/n3-m*m;precise float tv=v.x+v.y+v.z;if(tv<bestV){bestV=tv;bestC=m;}}
    if(n4>=1.0){precise float3 m=m4/n4;precise float3 v=q4/n4-m*m;precise float tv=v.x+v.y+v.z;if(tv<bestV){bestV=tv;bestC=m;}}
    if(n5>=1.0){precise float3 m=m5/n5;precise float3 v=q5/n5-m*m;precise float tv=v.x+v.y+v.z;if(tv<bestV){bestV=tv;bestC=m;}}
    if(n6>=1.0){precise float3 m=m6/n6;precise float3 v=q6/n6-m*m;precise float tv=v.x+v.y+v.z;if(tv<bestV){bestV=tv;bestC=m;}}
    if(n7>=1.0){precise float3 m=m7/n7;precise float3 v=q7/n7-m*m;precise float tv=v.x+v.y+v.z;if(tv<bestV){bestV=tv;bestC=m;}}
    return float4(bestC, 1.0);
}

float4 NMFrag_oilPost(NMVaryings i) : SV_Target
{
    uint w, h;
    inputTex.GetDimensions(w, h);
    float2 pos = NM_FragCoord(i);
    float2 uv = pos / float2(w, h);
    float4 src = inputTex.Sample(sampler_inputTex, uv);
    float3 c = flatTex.Sample(sampler_inputTex, uv).rgb;
    float2 globalCoord = floor(pos) + tileOffset;
    float3 outc = nm_oil_modeColor(uv, c, globalCoord);
    float3 grained = outc * (0.85 + 0.3 * nm_oil_vnoise(globalCoord / 2.0));
    outc = lerp(outc, grained, (textureAmount / 100.0) * 0.5);
    return float4(clamp(outc, 0.0, 1.0), src.a);
}

#endif
