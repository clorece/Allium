#ifndef CAUSTICS_GLSL
#define CAUSTICS_GLSL

#include "/lib/fragment/water.glsl"

vec2 causticsRefractLanding(vec2 surfXZ, float depthBelow, vec3 sunDirDown, float t) {
    const float WATER_IOR = 1.333;
    const float EPS = 0.08;

    float h  = waterHeight(surfXZ,                    t);
    float hx = waterHeight(surfXZ + vec2(EPS, 0.0),  t);
    float hz = waterHeight(surfXZ + vec2(0.0, EPS),  t);

    float ampN = WATER_WAVE_AMPLITUDE * WATER_NORMAL_STRENGTH;
    vec2  grad = (vec2(hx - h, hz - h) / EPS) * ampN;

    vec3 N = normalize(vec3(-grad.x, 1.0, -grad.y));

    vec3 R = refract(sunDirDown, N, 1.0 / WATER_IOR);

    if (R.y >= -1e-4) {
        return surfXZ;
    }

    float t_seabed = depthBelow / (-R.y);
    return surfXZ + R.xz * t_seabed;
}

float computeWaterCaustics(vec3 worldPos, float depthBelow, vec3 worldSunDir, float t) {
    if (depthBelow <= 0.05 || worldSunDir.y < 0.05) return 0.0;

    vec3 sunDirDown = -worldSunDir;

    float pixelFootprint = max(fwidth(worldPos.x), fwidth(worldPos.z));
    float penumbraRadius = depthBelow * 0.04;
    float jitterRadius   = max(pixelFootprint, penumbraRadius);

    vec2 jitterSeed = worldPos.xz + float(frameCounter) * 0.137;
    vec2 hash = fract(sin(vec2(dot(jitterSeed, vec2(127.1, 311.7)),
                               dot(jitterSeed, vec2(269.5, 183.3)))) * 43758.5453) - 0.5;
    vec2 baseSurfXZ = worldPos.xz + hash * jitterRadius;

    const float dxSample = 0.18;

    vec2 a = causticsRefractLanding(baseSurfXZ,                       depthBelow, sunDirDown, t);
    vec2 b = causticsRefractLanding(baseSurfXZ + vec2(dxSample, 0.0), depthBelow, sunDirDown, t);
    vec2 c = causticsRefractLanding(baseSurfXZ + vec2(0.0, dxSample), depthBelow, sunDirDown, t);

    vec2 da = (b - a) / dxSample;
    vec2 dc = (c - a) / dxSample;
    float jac = abs(da.x * dc.y - da.y * dc.x);

    float intensity = clamp(1.0 / max(jac, 0.05) - 1.0, -0.95, 10.0);

    intensity *= exp(-depthBelow * 0.05);

    intensity *= smoothstep(0.05, 0.35, worldSunDir.y);

    return intensity;
}

#endif
