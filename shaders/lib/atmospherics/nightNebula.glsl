#include "/lib/atmospherics/stars.glsl"

// Nebula implementation by flytrap https://godotshaders.com/shader/2d-nebula-shader/

#ifndef HQ_NIGHT_NEBULA
    const int OCTAVE = 5;
#else
    const int OCTAVE = 8;
#endif
const float timescale = 5.0;
const float zoomScale = 3.5;
const vec4 CLOUD1_COL = vec4(0.41, 0.64, 0.97, 0.4);
const vec4 CLOUD2_COL = vec4(0.81, 0.55, 0.21, 0.2);
const vec4 CLOUD3_COL = vec4(0.51, 0.81, 0.98, 1.0);

float sinM(float x) {
    return sin(mod(x, 2.0 * pi));
}

float cosM(float x) {
    return cos(mod(x, 2.0 * pi));
}

float rand(vec2 inCoord){
    return fract(sinM(dot(inCoord, vec2(23.53, 44.0))) * 42350.45);
}

float perlin(vec2 inCoord){
    vec2 i = floor(inCoord);
    vec2 j = fract(inCoord);
    vec2 coord = smoothstep(0.0, 1.0, j);

    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    return mix(mix(a, b, coord.x), mix(c, d, coord.x), coord.y);
}

float fbmCloud(vec2 inCoord, float minimum){
    float value = 0.0;
    float scale = 0.5;

    for (int i = 0; i < OCTAVE; i++){
        value += perlin(inCoord) * scale;
        inCoord *= 2.0;
        scale *= 0.5;
    }

    return smoothstep(0.0, 1.0, (smoothstep(minimum, 1.0, value) - minimum) / (1.0 - minimum));
}

float fbmCloud2(vec2 inCoord, float minimum){
    float value = 0.0;
    float scale = 0.5;

    for (int i = 0; i < OCTAVE; i++){
        value += perlin(inCoord) * scale;
        inCoord *= 2.0;
        scale *= 0.5;
    }

    return (smoothstep(minimum, 1.0, value) - minimum) / (1.0 - minimum);
}

vec3 GetNightNebula(vec3 viewPos, float VdotU, float VdotS) {
    float nebulaFactor = 1.0;

    vec2 UV = GetStarCoord(viewPos, 0.75);
    vec2 centeredUV = UV + 0.25;
    centeredUV.x *= 1.2;

    float band = smoothstep(0.3, 0.0, abs(centeredUV.y));
    float noise = fbmCloud2(UV * 12.0, 0.2);

    vec3 baseColor = mix(vec3(0.3, 0.4, 0.6), vec3(0.9, 0.7, 0.4), smoothstep(-0.5, 0.5, centeredUV.x));

    float brightness = noise * band * 0.2;

    float dust = smoothstep(0.05, 0.01, abs(centeredUV.y + 0.1 * sin(centeredUV.x * 10.0)));
    float dustMask = mix(1.0, 0.3, dust);
    brightness *= dustMask;

    float bandCenterFalloff = smoothstep(0.15, 0.0, abs(centeredUV.y));

    float starFactor = 1024.0;
    vec2 starCoord = floor(UV * 0.75 * starFactor) / starFactor;
    float starNoise = GetStarNoise(starCoord) * GetStarNoise(starCoord + 0.1);
    float starIntensity = bandCenterFalloff * max(0.0, starNoise - 0.6);
    brightness += starIntensity;

    #if PLANETARY_STARS_CONDITION >= 1
        float planetFactor = 512.0;
        vec2 planetCoord = floor(UV * planetFactor) / planetFactor;

        float p1 = GetStarNoise(planetCoord);
        float p2 = GetStarNoise(planetCoord + vec2(0.12, 0.21));
        float p3 = GetStarNoise(planetCoord + vec2(0.33, 0.77));
        float pNoise = p1 * p2 * p3;
        pNoise -= 0.81;
        float planetMask = max0(pNoise);
        planetMask *= planetMask;

        float hue = fract(sin(dot(planetCoord, vec2(17.23, 48.73))) * 43758.5453);
        vec3 planetColor = hsv2rgb(vec3(hue, 0.6, 1.0));

        float flicker = 0.9 + 0.1 * sin(syncedTime * 2.0 + dot(planetCoord, vec2(23.0, 19.0)) * 10.0);

        float nebulaDensityBoost = bandCenterFalloff;

        vec3 planetStars = 128.0 * nebulaDensityBoost * planetMask * flicker * planetColor;
    #else
        vec3 planetStars = vec3(0.0);
    #endif

    vec3 finalColor = baseColor * brightness + planetStars;
    return finalColor * nightFactor;
}