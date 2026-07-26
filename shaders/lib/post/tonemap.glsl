#ifndef TONEMAP_GLSL
#define TONEMAP_GLSL

#include "/lib/options.glsl"

// Reinhard-Jodie (Luminance-preserving Reinhard, very natural highlights)
vec3 ReinhardJodie(vec3 color) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = color / (1.0 + color);
    return mix(color / (1.0 + luma), tc, tc);
}

// ACES Filmic curve (Narkowicz 2015 approximation)
vec3 ACESFilmic(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// Timothy Lottes (2016) high-fidelity curve
vec3 Lottes(vec3 color) {
    const float a = 1.6;
    const float d = 0.977;
    const float hdrMax = 8.0;
    const float midIn = 0.18;
    const float midOut = 0.18;

    vec3 x = pow(color, vec3(a));
    float mIn = pow(midIn, a);
    float mOut = pow(midOut, a);
    float hMax = pow(hdrMax, a);

    float b = (mIn * (hMax - mOut)) / (hMax - mIn * mOut);
    float c = (hMax * mIn) / (hMax - mIn * mOut);

    return clamp(x / (c * x + b), 0.0, 1.0);
}

// Uncharted 2 (John Hable's cinematic curve)
vec3 HableOperator(vec3 x) {
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 Uncharted2(vec3 color) {
    const float W = 11.2;
    vec3 curr = HableOperator(color * 2.0); // apply standard 2.0 exposure bias
    vec3 whiteScale = 1.0 / HableOperator(vec3(W));
    return clamp(curr * whiteScale, 0.0, 1.0);
}


vec3 applyTonemap(vec3 color) {
    #if TONEMAP_OPERATOR == 0
        return ACESFilmic(color);
    #elif TONEMAP_OPERATOR == 1
        return Lottes(color);
    #elif TONEMAP_OPERATOR == 2
        return ReinhardJodie(color);
    #elif TONEMAP_OPERATOR == 3
        return Uncharted2(color);
    #else
        float exposureVal = 1.0;
        color = max(vec3(0.0), color - vec3(0.2 / exposureVal));
        color = (color * (exposureVal * color + 0.5)) / (color * (exposureVal * color + 1.7) + 0.5);
        return clamp(color, 0.0, 1.0);
    #endif
}

#endif