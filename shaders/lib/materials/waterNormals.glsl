// Gerstner Waves Simulation by Sergio_2357
// https://www.shadertoy.com/view/ddVSDt


// Gerstner wave utilities

// Gerstner wave utilities

uint hash(uint s) {
    s ^= 2747636419u;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    return s;
}

float randf(uint seed) {
    uint h = hash(seed);
    return float(h % 1000000u) / 1000000.0;
}

// Standard Gerstner wave - more stable
vec2 GerstnerWave(vec2 uv, float amplitude, float wavelength, float speed, float direction, float time) {
    vec2 d = vec2(cos(direction), sin(direction));
    float k = 2.0 * 3.14159 / wavelength;
    float c = sqrt(9.8 / k);
    float f = k * (dot(d, uv) - c * speed * time);
    float a = amplitude / k;
    
    return d * (a * cos(f));
}

// Generate multiple Gerstner waves with random directions
vec2 GetGerstnerLayer(vec2 uv, float time, uint seed, float amplitude, float wavelength, float speed, int numWaves) {
    vec2 result = vec2(0.0);
    
    for (int i = 0; i < numWaves; i++) {
        uint s = seed + uint(i) * 1000u;
        
        float dir = randf(s) * 3.14159 * 2.0;
        float a = amplitude * (0.8 + randf(s + 1u) * 0.4);
        float wl = wavelength * (0.8 + randf(s + 2u) * 0.4);
        float sp = speed * (0.8 + randf(s + 3u) * 0.4);
        
        result += GerstnerWave(uv, a, wl, sp, dir, time);
    }
    
    return result;
}

vec2 GetCombinedWaves(vec2 uv, vec2 wind) {
    wind *= 0.9;
    
    vec2 nMed   = texture2D(gaux4, uv + 0.25 * wind).rg - 0.5;
        nMed   += texture2D(gaux4, uv * 1.25 + 0.25 * wind).rg - 0.5;
    vec2 nSmall = texture2D(gaux4, uv * 2.0 - 2.0 * wind).rg - 0.5;
        nSmall += texture2D(gaux4, uv * 3.0 - 2.0 * wind).rg - 0.5 * 0.75;
        nSmall += texture2D(gaux4, uv * 4.0 - 2.0 * wind).rg - 0.5 * 0.55;
    vec2 nBig   = texture2D(gaux4, uv * 0.35 + 0.65 * wind).rg - 0.5;
        nBig   += texture2D(gaux4, uv * 0.55 + 0.75 * wind).rg - 0.5;
    
    
    float time = length(wind) * 16.0;
    uv *= 12.0;
    
    vec2 gMed   = GetGerstnerLayer(uv, time * 0.25, 100u, 0.15, 2.0, 2.0, 3);
        gMed   += GetGerstnerLayer(uv * 1.25, time * 0.25, 200u, 0.12, 2.8, 1.0, 3);
    
    vec2 gSmall = GetGerstnerLayer(uv * 1.0, time * 2.0, 300u, 0.1, 1.0, 1.95, 4);
        gSmall += GetGerstnerLayer(uv * 2.0, time * 2.0, 400u, 0.08, 0.8, 1.95, 4);
    
    vec2 gBig   = GetGerstnerLayer(uv * 0.35, time * 0.65, 500u, 0.2, 4.0, 1.28, 2);
        gBig   += GetGerstnerLayer(uv * 0.55, time * 0.75, 600u, 0.18, 3.5, 1.28, 2);
        gBig   *= 0.85;

    //vec2 n = (nSmall * WATER_BUMP_SMALL) * 0.65;
    vec2 n = (nMed * WATER_BUMP_MED +
            nSmall * WATER_BUMP_SMALL * 0.75 +
            nBig * WATER_BUMP_BIG) * 0.65;
    vec2 g = (gMed * WATER_BUMP_MED +
            gSmall * WATER_BUMP_SMALL +
            gBig * WATER_BUMP_BIG) * 5.0;

    vec2 height = (g * 0.5 + n * 0.5) * 2.0;

    #ifdef DH_WATER
        height *= 0.35;
    #endif

    return height;
}


/*
vec2 GetCombinedWaves(vec2 uv, vec2 wind) {
    wind *= 0.9;
    
    
    vec2 nMed   = texture2D(gaux4, uv + 0.25 * wind).rg - 0.5;
        nMed   += texture2D(gaux4, uv * 1.25 + 0.25 * wind).rg - 0.5;
    vec2 nSmall = texture2D(gaux4, uv * 2.0 - 2.0 * wind).rg - 0.5;
        nSmall += texture2D(gaux4, uv * 3.0 - 2.0 * wind).rg - 0.5;
    vec2 nBig   = texture2D(gaux4, uv * 0.35 + 0.65 * wind).rg - 0.5;
        nBig   += texture2D(gaux4, uv * 0.55 + 0.75 * wind).rg - 0.5;

    float time = length(wind) * 6.0;

    uv *= 3.0;
    uv.x *= 1.75;
    
    // Medium waves
    vec2 gMed   = GetGerstnerNormal(uv, time * 0.25, 4.0, 1.0, 0.15) * 0.8;
        //gMed   += GetGerstnerNormal(uv * 1.25, time * 0.25, 3.5, 1.1, 0.12);
    
    // Small waves
    vec2 gSmall = GetGerstnerNormal(uv * 2.0, time * 2.0, 2.0, 1.5, 0.2) * 0.65;
        gSmall += GetGerstnerNormal(uv * 3.0, time * 2.0, 1.5, 1.8, 0.18) * 0.35;
    
    // Big waves
    vec2 gBig   = GetGerstnerNormal(uv * 0.35, time * 0.65, 8.0, 0.8, 0.1) * 1.0;
        //gBig   += GetGerstnerNormal(uv * 0.55, time * 0.75, 7.0, 0.9, 0.08);

    vec2 n = (nMed * WATER_BUMP_MED +
            nSmall * WATER_BUMP_SMALL * 0.75 +
            nBig * WATER_BUMP_BIG) * 0.25;
    vec2 g = (gMed * WATER_BUMP_MED +
            gSmall * WATER_BUMP_SMALL +
            gBig * WATER_BUMP_BIG) * 1.5;


    return (g * 0.5 + n * 0.5) * 1.5;
}
*/