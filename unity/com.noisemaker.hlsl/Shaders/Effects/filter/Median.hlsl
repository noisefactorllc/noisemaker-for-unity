#ifndef NM_MEDIAN_INCLUDED
#define NM_MEDIAN_INCLUDED

// filter/median — exact dense whole-color median / Dust & Scratches.
// RADIUS remains the runtime integer define carrier, while storage stays fixed
// at the maximum 7x7 neighborhood so Metal sees one stable array layout.
#include "../../Include/NMFullscreen.hlsl"

int RADIUS;
float threshold;

bool nm_median_less_record(uint2 a, uint blueA, uint2 b, uint blueB)
{
    if (a.x != b.x) return a.x < b.x;
    if (a.y != b.y) return a.y < b.y;
    return blueA < blueB;
}

uint2 nm_median_pack_record_major(float4 color)
{
    float brightness = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    uint packedRg = (f32tof16(color.r) & 0xffffu) |
        ((f32tof16(color.g) & 0xffffu) << 16u);
    uint orderedRg = ((packedRg & 0xffffu) << 16u) | (packedRg >> 16u);
    return uint2(asuint(brightness), orderedRg);
}

uint nm_median_pack_record_blue(float4 color)
{
    return f32tof16(color.b) & 0xffffu;
}

float3 nm_median_unpack_record_rgb(uint2 major, uint blue)
{
    uint packedRg = (major.y << 16u) | (major.y >> 16u);
    float r = f16tof32(packedRg & 0xffffu);
    float g = f16tof32((packedRg >> 16u) & 0xffffu);
    float b = f16tof32(blue & 0xffffu);
    return float3(r, g, b);
}

float4 nm_median_read_record(
    Texture2D tex, int2 center, int2 dimensions, int x, int y)
{
    int2 coord = clamp(center + int2(x, y), int2(0, 0), dimensions - int2(1, 1));
    return tex.Load(int3(coord, 0));
}

float4 nm_median(Texture2D tex, float2 pos)
{
    uint2 majorRecords[49];
    uint blueRecords[49];
    uint tw, th;
    tex.GetDimensions(tw, th);
    int2 dimensions = int2((int)tw, (int)th);
    int2 center = (int2)pos;
    float3 originalRgb = float3(0.0, 0.0, 0.0);
    float centerAlpha = 1.0;
    int index = 0;

    [loop]
    for (int y = -RADIUS; y <= RADIUS; y++)
    {
        [loop]
        for (int x = -RADIUS; x <= RADIUS; x++)
        {
            float4 sampleColor = nm_median_read_record(tex, center, dimensions, x, y);
            majorRecords[index] = nm_median_pack_record_major(sampleColor);
            blueRecords[index] = nm_median_pack_record_blue(sampleColor);
            if (x == 0 && y == 0)
            {
                originalRgb = sampleColor.rgb;
                centerAlpha = sampleColor.a;
            }
            index++;
        }
    }

    int realCount = (2 * RADIUS + 1) * (2 * RADIUS + 1);
    int medianIndex = realCount >> 1;
    int left = 0;
    int right = realCount - 1;
    [loop]
    while (left < right)
    {
        uint2 pivotMajor = majorRecords[medianIndex];
        uint pivotBlue = blueRecords[medianIndex];
        int scanLeft = left;
        int scanRight = right;
        [loop]
        while (scanLeft <= scanRight)
        {
            [loop]
            while (nm_median_less_record(
                majorRecords[scanLeft], blueRecords[scanLeft], pivotMajor, pivotBlue))
            {
                scanLeft++;
            }
            [loop]
            while (nm_median_less_record(
                pivotMajor, pivotBlue, majorRecords[scanRight], blueRecords[scanRight]))
            {
                scanRight--;
            }
            if (scanLeft <= scanRight)
            {
                uint2 temporaryMajor = majorRecords[scanLeft];
                majorRecords[scanLeft] = majorRecords[scanRight];
                majorRecords[scanRight] = temporaryMajor;
                uint temporaryBlue = blueRecords[scanLeft];
                blueRecords[scanLeft] = blueRecords[scanRight];
                blueRecords[scanRight] = temporaryBlue;
                scanLeft++;
                scanRight--;
            }
        }
        if (scanRight < medianIndex) left = scanLeft;
        if (medianIndex < scanLeft) right = scanRight;
    }

    float3 medianRgb = nm_median_unpack_record_rgb(
        majorRecords[medianIndex], blueRecords[medianIndex]);
    float3 difference = abs(originalRgb - medianRgb);
    float maxDifference = max(max(difference.r, difference.g), difference.b);
    bool replaceCenter = threshold <= 0.0 || maxDifference >= threshold / 100.0;
    return float4(replaceCenter ? medianRgb : originalRgb, centerAlpha);
}

#endif
