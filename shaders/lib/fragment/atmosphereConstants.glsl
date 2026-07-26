#ifndef ATMOSPHERE_CONSTANTS_GLSL
#define ATMOSPHERE_CONSTANTS_GLSL

#ifndef SUN_ILLUMINANCE
#define SUN_ILLUMINANCE 10.0
#endif
#ifndef MOON_ILLUMINANCE
#define MOON_ILLUMINANCE 0.02
#endif

#define SUN_COLOR_BASE  (vec3(1.0, 0.9, 0.81) * SUN_ILLUMINANCE)
#define MOON_COLOR_BASE (vec3(0.7, 0.78, 1.0) * MOON_ILLUMINANCE)

#define PLANET_RADIUS     6371e3
#define ATMOSPHERE_HEIGHT 110e3
#define SCALE_HEIGHTS     vec2(8.0e3, 1.2e3)  // Rayleigh, Mie

#ifndef MIE_G
#define MIE_G 0.80
#endif

#ifdef RAYLEIGH_SCATTER_R
#define COEFF_RAYLEIGH vec3(RAYLEIGH_SCATTER_R, RAYLEIGH_SCATTER_G, RAYLEIGH_SCATTER_B) * 1e-6
#else
#define COEFF_RAYLEIGH vec3(5.8e-6, 1.35e-5, 3.31e-5)
#endif

#ifdef MIE_SCATTER_R
#define COEFF_MIE      vec3(MIE_SCATTER_R, MIE_SCATTER_G, MIE_SCATTER_B) * 1e-6
#else
#define COEFF_MIE      vec3(3.0e-6, 3.0e-6,  3.0e-6)
#endif

#define AIR_NUMBER_DENSITY        2.5035422e25

#ifdef OZONE_PEAK
#define OZONE_CONCENTRATION_PEAK  (OZONE_PEAK * 1e-6)
#else
#define OZONE_CONCENTRATION_PEAK  8e-6
#endif

#define OZONE_CROSS_SECTION       vec3(3.472e-21, 4.14e-21, 1.11e-22)

const float pi    = 3.14159265359;
const float rPI   = 1.0 / pi;
const float rLOG2 = 1.0 / log(2.0);

const float OZONE_NUMBER_DENSITY = AIR_NUMBER_DENSITY * OZONE_CONCENTRATION_PEAK;
const vec3  COEFF_OZONE          = OZONE_CROSS_SECTION * (OZONE_NUMBER_DENSITY * 1.0e-6);

const vec2  INVERSE_SCALE_HEIGHTS = 1.0 / SCALE_HEIGHTS;
const vec2  SCALED_PLANET_RADIUS  = PLANET_RADIUS * INVERSE_SCALE_HEIGHTS;
const float ATMOSPHERE_RADIUS         = PLANET_RADIUS + ATMOSPHERE_HEIGHT;
const float ATMOSPHERE_RADIUS_SQUARED = ATMOSPHERE_RADIUS * ATMOSPHERE_RADIUS;

const mat3 COEFF_ATTENUATION = mat3(COEFF_RAYLEIGH, COEFF_MIE * 1.11, COEFF_OZONE);

vec2 GetRaySphereIntersection(vec3 position, vec3 direction, float radius) {
    float PoD = dot(position, direction);
    float radiusSquared = radius * radius;

    float delta = PoD * PoD + radiusSquared - dot(position, position);
    if (delta < 0.0) return vec2(-1.0);
    delta = sqrt(delta);

    return -PoD + vec2(-delta, delta);
}

float GetRayleighPhase(float cosTheta) {
    const vec2 mul_add = vec2(0.1, 0.28) * rPI;
    return cosTheta * mul_add.x + mul_add.y;
}

float GetMiePhase(float cosTheta, const float g) {
    float gg = g * g;
    return (gg * -0.25 + 0.25) * rPI * pow(-(2.0 * g) * cosTheta + (gg + 1.0), -1.5);
}

vec2 GetPhase(float cosTheta, const float g) {
    return vec2(GetRayleighPhase(cosTheta), GetMiePhase(cosTheta, g));
}

vec3 GetAtmosphereDensity(float centerDistance) {
    vec2 rayleighMie = exp(centerDistance * -INVERSE_SCALE_HEIGHTS + SCALED_PLANET_RADIUS);

    float ozone = exp(-max(0.0, (35000.0 - centerDistance) - PLANET_RADIUS) * (1.0 / 5000.0))
                * exp(-max(0.0, (centerDistance - 35000.0) - PLANET_RADIUS) * (1.0 / 15000.0));

    return vec3(rayleighMie, ozone);
}

#endif
