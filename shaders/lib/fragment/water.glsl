#ifndef WATER_GLSL
#define WATER_GLSL


#ifndef WATER_WAVE_OCTAVES
#define WATER_WAVE_OCTAVES 4
#endif

float waterHash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float waterValueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = waterHash(i + vec2(0.0, 0.0));
    float b = waterHash(i + vec2(1.0, 0.0));
    float c = waterHash(i + vec2(0.0, 1.0));
    float d = waterHash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float waterOctave(vec2 uv, float choppy) {
    uv += waterValueNoise(uv);
    vec2 wv = 1.0 - abs(sin(uv));
    vec2 swv = abs(cos(uv));
    wv = mix(wv, swv, wv);
    return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
}


float waterHeightOctaves(vec2 worldXZ, float t, int octaves) {
    const mat2 octM = mat2(1.6, 1.2, -1.2, 1.6);
    vec2  wind   = normalize(vec2(0.86, 0.52)); // dominant wave travel direction
    float freq   = 0.25;   // lower base -> larger primary swells (less "tiled ripple" look)
    float amp    = 1.0;
    float choppy = 2.0;
    vec2  uv     = worldXZ;

    float h        = 0.0;
    float totalAmp = 0.0;

    for (int i = 0; i < WATER_WAVE_OCTAVES; i++) {
        if (i >= octaves) break;
        float ti = t * (1.0 + float(i) * 0.35);
        float d  = waterOctave((uv + wind * ti) * freq, choppy);
        d       += waterOctave((uv - wind * ti) * freq, choppy);
        h        += d * amp;
        totalAmp += amp;

        uv      = octM * uv + 113.97;
        freq   *= 1.35;
        amp    *= 0.2;
        choppy  = mix(choppy, 1.4, 0.2);
    }
    return h / max(totalAmp, 1e-4);
}

float waterHeight(vec2 worldXZ, float t) {
    return waterHeightOctaves(worldXZ, t, WATER_WAVE_OCTAVES);
}

#ifdef WATER_DISPLACEMENT

vec3 waterDisplacement(vec2 worldXZ, float t) {
    float h = waterHeightOctaves(worldXZ, t, WATER_DISPLACEMENT_OCTAVES);

    const float e = 0.25; // sampling step (blocks)
    float hx = waterHeightOctaves(worldXZ + vec2(e, 0.0), t, WATER_DISPLACEMENT_OCTAVES);
    float hz = waterHeightOctaves(worldXZ + vec2(0.0, e), t, WATER_DISPLACEMENT_OCTAVES);
    vec2  grad = vec2(hx - h, hz - h) / e;

    vec2  pull  = clamp(grad * (WATER_DISPLACEMENT_STEEPNESS * WATER_DISPLACEMENT_HEIGHT), vec2(-0.5), vec2(0.5));

    float dispY = (h - 0.5) * WATER_DISPLACEMENT_HEIGHT - WATER_DISPLACEMENT_OFFSET;

    return vec3(pull.x, dispY, pull.y);
}
#endif

vec3 waterSurfaceNormal(vec3 worldPos, vec3 geoN, float t, float amplitude, float strength, float eps) {
    vec3 ref = abs(geoN.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(ref, geoN));
    vec3 B = cross(geoN, T);

    vec2 p0 = vec2(dot(worldPos, T), dot(worldPos, B));
    vec2 p = p0;

    #ifdef WATER_PARALLAX
    vec3 V = normalize(cameraPosition - worldPos);
    vec3 viewTan = vec3(dot(V, T), dot(V, B), dot(V, geoN));
    vec2 parallaxDir = viewTan.xy / max(viewTan.z, 0.05); // cap at grazing angles
    float max_h = amplitude * strength * WATER_PARALLAX_HEIGHT;

    float currentHeight = 1.0;
    float stepSize = 1.0 / WATER_PARALLAX_STEPS;
    vec2 p_delta = -parallaxDir * max_h * stepSize;
    vec2 p_current = p0 + parallaxDir * max_h;

    for (int i = 0; i < WATER_PARALLAX_STEPS; i++) {
        float h_current = waterHeight(p_current, t);
        if (h_current >= currentHeight) break;
        currentHeight -= stepSize;
        p_current += p_delta;
    }

    vec2 p_prev = p_current - p_delta;
    float h_prev = waterHeight(p_prev, t) - (currentHeight + stepSize);
    float h_curr = waterHeight(p_current, t) - currentHeight;
    float weight = clamp(h_curr / (h_curr - h_prev), 0.0, 1.0);
    p = mix(p_current, p_prev, weight);
    #endif

    float h  = waterHeight(p,                  t) * amplitude;
    float hx = waterHeight(p + vec2(eps, 0.0), t) * amplitude;
    float hy = waterHeight(p + vec2(0.0, eps), t) * amplitude;

    vec2 grad = vec2(h - hx, h - hy) / eps;          // tangent-plane slope
    vec3 perturb = grad.x * T + grad.y * B;          // tilt the geometric normal in-plane
    return normalize(geoN + perturb * strength);
}

#endif
