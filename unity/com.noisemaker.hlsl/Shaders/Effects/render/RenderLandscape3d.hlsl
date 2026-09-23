#ifndef NM_EFFECT_RENDERLANDSCAPE3D_INCLUDED
#define NM_EFFECT_RENDERLANDSCAPE3D_INCLUDED

// =============================================================================
// RenderLandscape3d.hlsl — render/renderLandscape3d (func: "renderLandscape3d")
// — NEW this round (reference 0ed489ec). Isometric/perspective voxel raymarch
// with face lighting, consuming a synth3d generator's volume+geometry bundle
// (its own companion generator is synth3d/heightmap3d). Ported PIXEL-IDENTICALLY
// from the canonical GLSL source (this effect ships GLSL, not WGSL, upstream —
// see PORTING-GUIDE golden rule #1 exception: "use GLSL only to disambiguate
// when WGSL is unclear" does not apply here, there is no WGSL source file for
// this effect; the GLSL IS top-left-origin / D3D-oriented already, matching
// HLSL exactly, so no per-effect Y flip is needed either way):
//   glsl/landscape.glsl   progName "landscape"   (main)
//
// 3D / RENDER TIER — RAYMARCH CONSUMER, same atlas-consumer model as
// RenderLit3d.hlsl: single fullscreen pass ("render"), MRT (drawBuffers:2).
//   SV_Target0 (color)  -> outputTex         (lit RGB, alpha)
//   SV_Target1 (geoOut) -> screenGeoBuffer   (xyz=normal*0.5+0.5, w=depth 0..1)
// INPUT volume atlas: volumeCache (<- inputTex3d), analyticalGeo (<- inputGeo),
// both volumeSize x volumeSize^2 rgba16f. Read via .Load (integer texel fetch,
// point, no filtering) — atlasTexel = (vx, vy + vz*volSize), same helper as
// RenderLit3d.hlsl's r3_atlasTexel.
//
// VIEW_MODE (reference 0ed489ec): declared `define: "VIEW_MODE"` on the
// reference global (an EFFECT-level compile-time define, unlike
// pointsRender/pointsBillboardRender's NEW per-PASS-clone define pattern this
// round — this effect has only one pass, no clones). Expander.cs's existing
// BuildDefines()/pre-round mechanism already handles effect-level `define`
// globals correctly; no compiler change was needed for this effect.
//
// PORTING-GUIDE / parity notes:
//  * texelFetch(t, ivec2, 0) -> t.Load(int3(coord, 0)).
//  * ivec3[axis] / vec3[axis] dynamic component indexing maps 1:1 to HLSL's
//    own vector indexing operator.
//  * any(lessThan(a,b)) -> any(a < b); any(greaterThanEqual(a,b)) -> any(a >= b);
//    lessThanEqual(a,b) (bvec) -> (a <= b) (bool3) — HLSL relational operators
//    are already component-wise on vectors, no helper needed.
//  * bvec3->ivec3 (1/0) cast -> HLSL bool3->int3 explicit cast, same semantics.
//  * mix/fract/clamp/normalize/cross/dot map 1:1. select() is not used here.
// =============================================================================

#include "../../Include/NMFullscreen.hlsl"

Texture2D volumeCache;   SamplerState sampler_volumeCache;
Texture2D analyticalGeo; SamplerState sampler_analyticalGeo;

#ifndef FILTERING
#define FILTERING 1
#endif

// ---- Per-effect named uniforms (match definition.js globals[*].uniform) -----
int    volumeSize;         // globals.volumeSize        default 64
float  threshold;          // globals.threshold         default 0.5
float  zoom;                // globals.zoom              default 1
float  panX;                // globals.panX              default 0
float  panY;                // globals.panY              default 0
float3 lightDirection;      // globals.lightDirection    default (-0.4,0.85,0.6)
float  ambient;             // globals.ambient           default 0.35
float  diffuseIntensity;    // globals.diffuseIntensity  default 0.85
float  specularIntensity;   // globals.specularIntensity default 0.12
float3 bgColor;              // globals.bgColor           default (0.025,0.045,0.075)
float  bgAlpha;              // globals.bgAlpha           default 1
int    VIEW_MODE;            // globals.viewMode (define) default 1 (ortho)
float  rotateX;              // globals.rotateX           default 0.3
float  rotateY;              // globals.rotateY           default 0
float  rotateZ;              // globals.rotateZ           default 0
float  viewScale;            // globals.viewScale         default 0.8
float  posX;                 // globals.posX              default 0
float  posY;                 // globals.posY              default 0
float  posZ;                 // globals.posZ              default 0
float  fieldOfView;          // globals.fieldOfView       default 60

int2 land_atlasTexel(int3 p)
{
    return int2(p.x, p.y + p.z * volumeSize);
}

// The landscape lattice stores samples at voxel centers. Filter the 3D
// coordinates explicitly so interpolation never crosses unrelated atlas rows.
float4 land_sampleAtlasTexel(Texture2D atlas, int3 p, bool material)
{
    int2 coord = land_atlasTexel(p);
    float4 value = atlas.Load(int3(coord, 0));
    if (material)
    {
        // Geometry defines empty samples. Volume alpha can hold unrelated data.
        float present = analyticalGeo.Load(int3(coord, 0)).a > 0.0 ? 1.0 : 0.0;
        return float4(value.rgb * present, present);
    }
    return value;
}

// Preserve constant fields exactly so flat surfaces have zero tangential gradient.
float4 land_interpolateAtlas(float4 a, float4 b, float weight)
{
    return a + (b - a) * weight;
}

struct Land_AtlasCoords
{
    int3 lo;
    float3 fraction;
};

Land_AtlasCoords land_atlasCoords(float3 p)
{
    float3 texel = clamp(p - 0.5, float3(0.0, 0.0, 0.0), float3((float)(volumeSize - 1), (float)(volumeSize - 1), (float)(volumeSize - 1)));
    Land_AtlasCoords c;
    c.lo = (int3)floor(texel);
    c.fraction = frac(texel);
    return c;
}

float4 land_sampleAtlasCoords(Texture2D atlas, Land_AtlasCoords coords, bool material)
{
    int3 lo = coords.lo;
    int3 hi = min(lo + int3(1, 1, 1), (int3)(volumeSize - 1));
    float3 f = coords.fraction;
    float4 c00 = land_interpolateAtlas(land_sampleAtlasTexel(atlas, int3(lo.x, lo.y, lo.z), material),
                     land_sampleAtlasTexel(atlas, int3(hi.x, lo.y, lo.z), material), f.x);
    float4 c10 = land_interpolateAtlas(land_sampleAtlasTexel(atlas, int3(lo.x, hi.y, lo.z), material),
                     land_sampleAtlasTexel(atlas, int3(hi.x, hi.y, lo.z), material), f.x);
    float4 c01 = land_interpolateAtlas(land_sampleAtlasTexel(atlas, int3(lo.x, lo.y, hi.z), material),
                     land_sampleAtlasTexel(atlas, int3(hi.x, lo.y, hi.z), material), f.x);
    float4 c11 = land_interpolateAtlas(land_sampleAtlasTexel(atlas, int3(lo.x, hi.y, hi.z), material),
                     land_sampleAtlasTexel(atlas, int3(hi.x, hi.y, hi.z), material), f.x);
    float4 value = land_interpolateAtlas(land_interpolateAtlas(c00, c10, f.y), land_interpolateAtlas(c01, c11, f.y), f.z);
    if (material && value.a > 0.0) value.rgb /= value.a;
    return value;
}

float4 land_sampleAtlas(Texture2D atlas, float3 p, bool material)
{
    return land_sampleAtlasCoords(atlas, land_atlasCoords(p), material);
}

bool land_isSolid(Land_AtlasCoords coords)
{
    float density = land_sampleAtlasCoords(analyticalGeo, coords, false).a;
    return density > 0.0 && density >= threshold;
}

struct Land_IsoHit
{
    float distance;
    float3 position;
    Land_AtlasCoords coords;
};

Land_IsoHit land_traceIsosurface(float3 origin, float3 direction, float start, float leave)
{
    float3 position = origin + direction * start;
    Land_AtlasCoords coords = land_atlasCoords(position);
    if (land_isSolid(coords))
    {
        Land_IsoHit hit;
        hit.distance = start;
        hit.position = position;
        hit.coords = coords;
        return hit;
    }
    // Half-voxel steps cover the entire box, including long diagonal rays.
    float stepSize = 0.5 / length(direction);
    float previous = start;
    [loop]
    for (int step = 0; step < volumeSize * 4; step++)
    {
        float distance = min(previous + stepSize, leave);
        position = origin + direction * distance;
        coords = land_atlasCoords(position);
        if (land_isSolid(coords))
        {
            float lo = previous;
            float hi = distance;
            [unroll]
            for (int refine = 0; refine < 8; refine++)
            {
                float mid = (lo + hi) * 0.5;
                float3 candidate = origin + direction * mid;
                Land_AtlasCoords candidateCoords = land_atlasCoords(candidate);
                if (land_isSolid(candidateCoords))
                {
                    hi = mid;
                    position = candidate;
                    coords = candidateCoords;
                }
                else
                {
                    lo = mid;
                }
            }
            // Reuse the tested interpolation coordinates for material sampling.
            // Recomputing them from position can round onto the empty boundary.
            Land_IsoHit hit;
            hit.distance = hi;
            hit.position = position;
            hit.coords = coords;
            return hit;
        }
        if (distance >= leave) break;
        previous = distance;
    }
    Land_IsoHit miss;
    miss.distance = -1.0;
    miss.position = float3(0.0, 0.0, 0.0);
    miss.coords.lo = int3(0, 0, 0);
    miss.coords.fraction = float3(0.0, 0.0, 0.0);
    return miss;
}

float3 land_isosurfaceNormal(float3 p, float3 fallback)
{
    float3 gradient = float3(
        land_sampleAtlas(analyticalGeo, p - float3(0.5, 0.0, 0.0), false).a - land_sampleAtlas(analyticalGeo, p + float3(0.5, 0.0, 0.0), false).a,
        land_sampleAtlas(analyticalGeo, p - float3(0.0, 0.5, 0.0), false).a - land_sampleAtlas(analyticalGeo, p + float3(0.0, 0.5, 0.0), false).a,
        land_sampleAtlas(analyticalGeo, p - float3(0.0, 0.0, 0.5), false).a - land_sampleAtlas(analyticalGeo, p + float3(0.0, 0.0, 0.5), false).a);
    if (dot(gradient, gradient) > 1e-12) return normalize(gradient);
    return fallback;
}

float3 land_lighting(float3 color, float3 normal, float3 viewDirection)
{
    float3 light = float3(0.0, 1.0, 0.0);
    if (dot(lightDirection, lightDirection) > 0.000001) { light = normalize(lightDirection); }
    float3 halfVector = light + viewDirection;
    float specular = 0.0;
    if (dot(halfVector, halfVector) > 0.000001)
    {
        specular = pow(max(dot(normal, normalize(halfVector)), 0.0), 32.0) * specularIntensity;
    }
    return color * (ambient + max(dot(normal, light), 0.0) * diffuseIntensity) + specular;
}

// Inverse of the billboard renderer's X -> Y -> Z rotation.
float3 land_inverseRotation(float3 inputVec)
{
    float3 c = cos(float3(rotateX, rotateY, rotateZ));
    float3 s = sin(float3(rotateX, rotateY, rotateZ));
    float3 p = float3(inputVec.x * c.z + inputVec.y * s.z, -inputVec.x * s.z + inputVec.y * c.z, inputVec.z);
    p = float3(p.x * c.y - p.z * s.y, p.y, p.x * s.y + p.z * c.y);
    return float3(p.x, p.y * c.x + p.z * s.x, -p.y * s.x + p.z * c.x);
}

float3 land_forwardRotation(float3 inputVec)
{
    float3 c = cos(float3(rotateX, rotateY, rotateZ));
    float3 s = sin(float3(rotateX, rotateY, rotateZ));
    float3 p = float3(inputVec.x, inputVec.y * c.x - inputVec.z * s.x, inputVec.y * s.x + inputVec.z * c.x);
    p = float3(p.x * c.y + p.z * s.y, p.y, -p.x * s.y + p.z * c.y);
    return float3(p.x * c.z - p.y * s.z, p.x * s.z + p.y * c.z, p.z);
}

struct LandscapeOutput
{
    float4 fragColor;
    float4 geoOut;
};

LandscapeOutput land_renderPerspective(float2 uv)
{
    LandscapeOutput result;
    result.fragColor = float4(bgColor * bgAlpha, bgAlpha);
    result.geoOut = float4(0.5, 0.5, 1.0, 1.0);
    float size = (float)volumeSize;
    float focalLength = 1.0 / tan(clamp(fieldOfView, 10.0, 150.0) * 0.00872664626);
    // The volume spans [-40,40]. Position follows rotation; camera Z is 80.
    float3 origin = (land_inverseRotation(float3(-posX, -posY, 80.0 - posZ)) / 80.0 + 0.5) * size;
    float2 framedUv = (uv + float2(panX, panY)) / max(zoom, 0.001);
    float3 cameraRay = float3(framedUv * 2.0 / (focalLength * max(viewScale, 0.001)), -1.0);
    float3 direction = land_inverseRotation(cameraRay) * (size / 80.0);
    float3 nearT = float3(-1e30, -1e30, -1e30);
    float3 farT = float3(1e30, 1e30, 1e30);
    float3 delta = float3(1e30, 1e30, 1e30);
    int3 stepDir = int3(0, 0, 0);
    [unroll]
    for (int axis = 0; axis < 3; axis++)
    {
        if (abs(direction[axis]) < 1e-8)
        {
            if (origin[axis] < 0.0 || origin[axis] >= size) { return result; }
        }
        else
        {
            float a = -origin[axis] / direction[axis];
            float b = (size - origin[axis]) / direction[axis];
            nearT[axis] = min(a, b);
            farT[axis] = max(a, b);
            delta[axis] = 1.0 / abs(direction[axis]);
            stepDir[axis] = (direction[axis] > 0.0) ? 1 : -1;
        }
    }
    float enter = max(max(nearT.x, nearT.y), nearT.z);
    float leave = min(min(farT.x, farT.y), farT.z);
    float distance = max(enter, 0.1);
    if (distance >= leave) { return result; }
    int3 cell = clamp((int3)floor(origin + direction * distance + (float3)stepDir * 0.0001), int3(0, 0, 0), (int3)(volumeSize - 1));
    float3 nextT = float3(1e30, 1e30, 1e30);
    [unroll]
    for (int axis2 = 0; axis2 < 3; axis2++)
    {
        if (stepDir[axis2] != 0)
        {
            float boundary = (float)cell[axis2] + ((stepDir[axis2] > 0) ? 1.0 : 0.0);
            nextT[axis2] = (boundary - origin[axis2]) / direction[axis2];
        }
    }
    float3 viewDirection = normalize(-cameraRay);
    float3 normal = normalize(-direction);
    if (enter >= 0.1)
    {
        normal = float3(0.0, 0.0, 0.0);
        if (nearT.y >= nearT.x && nearT.y >= nearT.z) { normal.y = -(float)stepDir.y; }
        else if (nearT.x >= nearT.z) { normal.x = -(float)stepDir.x; }
        else { normal.z = -(float)stepDir.z; }
    }
    // FILTERING is injected as a constant when the runtime compiles a variant.
    if (FILTERING == 0)
    {
        Land_IsoHit hit = land_traceIsosurface(origin, direction, distance, leave);
        if (hit.distance < 0.0) return result;
        float3 p = hit.position;
        if (hit.distance > distance) normal = land_isosurfaceNormal(p, normal);
        float3 worldNormal = land_forwardRotation(normal);
        result.fragColor = float4(land_lighting(land_sampleAtlasCoords(volumeCache, hit.coords, true).rgb, worldNormal, viewDirection), 1.0);
        result.geoOut = float4(worldNormal * 0.5 + 0.5, clamp(hit.distance / 320.0, 0.0, 1.0));
        return result;
    }
    [loop]
    for (int step = 0; step < volumeSize * 3; step++)
    {
        if (any(cell < int3(0, 0, 0)) || any(cell >= (int3)volumeSize) || distance >= leave) { break; }
        int2 atlas = land_atlasTexel(cell);
        float density = analyticalGeo.Load(int3(atlas, 0)).a;
        if (density > 0.0 && density >= threshold)
        {
            float3 worldNormal = land_forwardRotation(normal);
            result.fragColor = float4(land_lighting(volumeCache.Load(int3(atlas, 0)).rgb, worldNormal, viewDirection), 1.0);
            result.geoOut = float4(worldNormal * 0.5 + 0.5, clamp(distance / 320.0, 0.0, 1.0));
            return result;
        }
        distance = min(min(nextT.x, nextT.y), nextT.z);
        bool3 crossed = nextT <= distance;
        normal = float3(0.0, 0.0, 0.0);
        if (crossed.y) { normal.y = -(float)stepDir.y; }
        else if (crossed.x) { normal.x = -(float)stepDir.x; }
        else { normal.z = -(float)stepDir.z; }
        cell += stepDir * (int3)crossed;
        nextT += delta * (float3)crossed;
    }
    return result;
}

// =============================================================================
// PASS: render — raymarch + lighting, MRT (frag_render)
// =============================================================================
struct Land_FragmentOutput
{
    float4 color  : SV_Target0;   // -> outputTex
    float4 geoOut : SV_Target1;   // -> screenGeoBuffer
};

Land_FragmentOutput frag_render(NMVaryings i)
{
    Land_FragmentOutput o;
    o.color = float4(bgColor * bgAlpha, bgAlpha);
    o.geoOut = float4(0.5, 0.5, 1.0, 1.0);
    float2 fullRes = (fullResolution.x > 0.0) ? fullResolution : resolution;
    float2 fragCoord = NM_FragCoord(i);
    float2 uv = (fragCoord + tileOffset - fullRes * 0.5) / fullRes.y;

    // VIEW_MODE is a compile-time define (bare identifier); the inactive path
    // is dead code eliminated only in the reference's shader-permutation
    // model — this port keeps it as a runtime branch (PORTING-GUIDE).
    if (VIEW_MODE == 2)
    {
        LandscapeOutput persp = land_renderPerspective(uv);
        o.color = persp.fragColor;
        o.geoOut = persp.geoOut;
        return o;
    }

    float size = (float)volumeSize;
    float aspect = fullRes.x / fullRes.y;
    float span = max(1.6329931619, 1.4142135624 / aspect) * size * 1.08 / max(zoom, 0.001);
    float3 right = float3(0.7071067812, 0.0, -0.7071067812);
    float3 up = float3(-0.4082482905, 0.8164965809, -0.4082482905);
    float3 origin = (float3)(size * 2.5) + right * (uv.x + panX) * span + up * (uv.y + panY) * span;

    float3 nearT = origin - size;
    float enter = max(max(nearT.x, nearT.y), nearT.z);
    float leave = min(min(origin.x, origin.y), origin.z);
    if (enter >= leave) { return o; }
    float distance = max(enter, 0.0);
    int3 cell = clamp((int3)floor(origin - (float3)(distance + 0.0001)), int3(0, 0, 0), (int3)(volumeSize - 1));
    float3 nextT = origin - (float3)cell;
    float3 normal = float3(0.0, 0.0, 1.0);
    if (nearT.y >= nearT.x && nearT.y >= nearT.z) { normal = float3(0.0, 1.0, 0.0); }
    else if (nearT.x >= nearT.z) { normal = float3(1.0, 0.0, 0.0); }

    if (FILTERING == 0)
    {
        Land_IsoHit hit = land_traceIsosurface(origin, float3(-1.0, -1.0, -1.0), distance, leave);
        if (hit.distance < 0.0) return o;
        float3 p = hit.position;
        if (hit.distance > distance) normal = land_isosurfaceNormal(p, normal);
        o.color = float4(land_lighting(land_sampleAtlasCoords(volumeCache, hit.coords, true).rgb, normal, float3(0.5773502692, 0.5773502692, 0.5773502692)), 1.0);
        o.geoOut = float4(normal * 0.5 + 0.5, clamp(hit.distance / (size * 4.0), 0.0, 1.0));
        return o;
    }

    [loop]
    for (int step = 0; step < volumeSize * 3; step++)
    {
        if (any(cell < int3(0, 0, 0)) || distance >= leave) { break; }
        int2 atlas = land_atlasTexel(cell);
        float density = analyticalGeo.Load(int3(atlas, 0)).a;
        if (density > 0.0 && density >= threshold)
        {
            float3 color = volumeCache.Load(int3(atlas, 0)).rgb;
            o.color = float4(land_lighting(color, normal, float3(0.5773502692, 0.5773502692, 0.5773502692)), 1.0);
            o.geoOut = float4(normal * 0.5 + 0.5, clamp(distance / (size * 4.0), 0.0, 1.0));
            return o;
        }
        distance = min(min(nextT.x, nextT.y), nextT.z);
        bool3 crossed = nextT <= distance;
        if (crossed.y) { normal = float3(0.0, 1.0, 0.0); }
        else if (crossed.x) { normal = float3(1.0, 0.0, 0.0); }
        else { normal = float3(0.0, 0.0, 1.0); }
        cell -= (int3)crossed;
        nextT += (float3)crossed;
    }
    return o;
}

#endif // NM_EFFECT_RENDERLANDSCAPE3D_INCLUDED
