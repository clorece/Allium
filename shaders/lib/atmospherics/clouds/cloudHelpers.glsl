const float invLog2 = 1.0 / log(2.0);

#include "/lib/atmospherics/weather/weatherParams.glsl"

float Mie(float x, float g) {
    float t = 1.0 + g*g - 2.0*g*x;
    return (1.0 - g*g) / ((6.0*3.14159265) * t * (t*0.5 + 0.5)) * 0.85;
}

float PhaseHG(float cosTheta, float g) {
    float mie1 = Mie(cosTheta, 0.5*g) + Mie(cosTheta, 0.55*g);
    float mie2 = Mie(cosTheta, -0.25*g);
    return mix(mie1 * 0.1, mie2 * 2.0, 0.35);
}

float getCloudMap(vec3 p) {
    vec2 uv = 0.5 + 0.5 * (p.xz/(1.8 * 100.0));
    return texture2D(noisetex, uv).x;
}

vec3 Offset(float wind) { 
    return vec3(wind * 0.7, wind * 0.5, wind * 0.2); 
}

float GetWind() {
    float wind = 0.0004;
    #if CLOUD_SPEED_MULT == 100
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        wind *= syncedTime;
    #else
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        wind *= frameTimeCounter * CLOUD_SPEED_MULT_M;
    #endif
    return wind;
}

float angle = GetWind() * 0.05;
vec3 windDir = normalize(vec3(cos(angle), 0.0, sin(angle)));
mat3 shearMatrix = mat3(
    1.0 + windDir.x * 0.2, windDir.x * 0.1, 0.0,
    windDir.y * 0.1, 1.0, 0.0,
    windDir.z * 0.2, windDir.z * 0.1, 1.0
);

float curvatureDrop(float dx) {
    #ifdef CURVED_CLOUDS
        return CURVATURE_STRENGTH * (dx * dx) / max(2.0 * PLANET_RADIUS, 1.0);
    #else
        return 0.0;
    #endif
}

float curvedY(vec3 pos, vec3 cam) {
    float dx = length((pos - cam).xz);
    return pos.y - curvatureDrop(dx);
}

float Noise3D(vec3 p) {
    p.z = fract(p.z) * 128.0;
    float iz = floor(p.z);
    float fz = fract(p.z);
    
    fz = fz * fz * (3.0 - 2.0 * fz);
    
    vec2 a_off = vec2(23.0, 29.0) * (iz) / 128.0;
    vec2 b_off = vec2(23.0, 29.0) * (iz + 1.0) / 128.0;
    float a = texture2D(noisetex, p.xy + a_off).r;
    float b = texture2D(noisetex, p.xy + b_off).r;
    return mix(a, b, fz);
}

float Noise3D2(vec3 p) {
    p.z = fract(p.z) * 20.0;
    float iz = floor(p.z);
    float fz = fract(p.z);
    vec2 a_off = vec2(23.0, 29.0) * (iz) / 20.0;
    vec2 b_off = vec2(23.0, 29.0) * (iz + 1.0) / 20.0;
    float a = texture2D(colortex3, p.xy + a_off).r;
    float b = texture2D(colortex3, p.xy + b_off).b;
    return mix(a, b, fz);
}