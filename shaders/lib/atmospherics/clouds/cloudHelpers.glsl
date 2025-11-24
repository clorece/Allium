const float InverseLog2 = 1.0 / log(2.0);

#include "/lib/atmospherics/weather/weatherParams.glsl"

float CalculateMiePhase(float cosTheta, float anisotropy) {
    float term = 1.0 + anisotropy * anisotropy - 2.0 * anisotropy * cosTheta;
    return (1.0 - anisotropy * anisotropy) / ((6.0 * 3.14159265) * term * (term * 0.5 + 0.5)) * 0.85;
}

float PhaseHG(float cosTheta, float anisotropy) {
    float phaseForward = CalculateMiePhase(cosTheta, 0.5 * anisotropy) + CalculateMiePhase(cosTheta, 0.55 * anisotropy);
    float phaseBackward = CalculateMiePhase(cosTheta, -0.25 * anisotropy);
    return mix(phaseForward * 0.1, phaseBackward * 2.0, 0.35);
}

float SampleCloudMap(vec3 position) {
    vec2 texCoord = 0.5 + 0.5 * (position.xz / (1.8 * 100.0));
    return texture2D(noisetex, texCoord).x;
}

vec3 CalculateWindOffset(float windSpeed) { 
    return vec3(windSpeed * 0.7, windSpeed * 0.5, windSpeed * 0.2); 
}

float CalculateWindSpeed() {
    float windSpeed = 0.0004;
    #if CLOUD_SPEED_MULT == 100
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        windSpeed *= syncedTime;
    #else
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        windSpeed *= frameTimeCounter * CLOUD_SPEED_MULT_M;
    #endif
    return windSpeed;
}

float GlobalWindAngle = CalculateWindSpeed() * 0.05;
vec3 GlobalWindDirection = normalize(vec3(cos(GlobalWindAngle), 0.0, sin(GlobalWindAngle)));
mat3 GlobalWindShearMatrix = mat3(
    1.0 + GlobalWindDirection.x * 0.2, GlobalWindDirection.x * 0.1, 0.0,
    GlobalWindDirection.y * 0.1, 1.0, 0.0,
    GlobalWindDirection.z * 0.2, GlobalWindDirection.z * 0.1, 1.0
);

float curvatureDrop(float distXZ) {
    #ifdef CURVED_CLOUDS
        return CURVATURE_STRENGTH * (distXZ * distXZ) / max(2.0 * PLANET_RADIUS, 1.0);
    #else
        return 0.0;
    #endif
}

float CalculateCurvedY(vec3 position, vec3 cameraPos) {
    float distXZ = length((position - cameraPos).xz);
    return position.y - curvatureDrop(distXZ);
}

float Noise3D(vec3 position) {
    position.z = fract(position.z) * 128.0;
    float zInteger = floor(position.z);
    float zFraction = fract(position.z);
    
    zFraction = zFraction * zFraction * (3.0 - 2.0 * zFraction);
    
    vec2 offsetA = vec2(23.0, 29.0) * (zInteger) / 128.0;
    vec2 offsetB = vec2(23.0, 29.0) * (zInteger + 1.0) / 128.0;
    float noiseA = texture2D(noisetex, position.xy + offsetA).r;
    float noiseB = texture2D(noisetex, position.xy + offsetB).r;
    return mix(noiseA, noiseB, zFraction);
}