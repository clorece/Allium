#include "/lib/colors/cloudColors.glsl"

//#define PLANAR_CLOUDS

// Map view position to planar cloud coordinates
#ifdef PLANAR_CLOUDS
vec2 GetCloudCoords(vec3 viewPos, out vec3 wpos) {
    // Project onto XZ plane for planar clouds
    wpos = (gbufferModelViewInverse * vec4(viewPos * 1000.0, 1.0)).xyz;
    
    return wpos.xz * 0.001; // Scale for coverage size
}

float PhaseHG(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159 * pow(denom, 1.5));
} 

vec3 GetPlanarClouds(vec3 viewPos, float VdotU, float VdotS, float dither) {
    float coverage = 1.85;
    float softness = 1.0;
    float horizonFadeStart = 1.0;  // start fading at this height above horizon
    float horizonFadeEnd = 0.0;    // fully faded at or below this height (horizon level)

    vec3 wpos;
    vec2 cloudCoord = GetCloudCoords(viewPos, wpos);

    cloudCoord.x += 0.02 * syncedTime;
    cloudCoord.y += 0.01 * syncedTime;

    // Base noise (fBm)
    float cloudPattern = 0.0;
    float amplitude = 0.5;
    float frequency = 0.0005;
    float swirliness = 3.0;
    cloudCoord.x *= 1.5;
    for (int i = 0; i < 12; i++) {
        //cloudCoord.x *= sin(cloudCoord.y * 0.05) * 0.001;
        cloudPattern += amplitude * texture2D(noisetex, (cloudCoord - cloudPattern * swirliness) * 0.5 * frequency).r;
        frequency *= 1.55;
        amplitude *= 0.77;
        swirliness *= 1.15;
    }

    cloudPattern -= moonFactor * 0.5;

    // Soft edge with smoothstep
    float cloudAlpha = smoothstep(coverage - softness, coverage + softness, cloudPattern);

    vec3 playerPos = ViewToPlayer(viewPos);

    float xzMaxDistance = max(abs(playerPos.x), abs(playerPos.z));
    float cloudDistance = 128.0;
    cloudDistance = clamp((cloudDistance - xzMaxDistance) / cloudDistance, 0.0, 1.0);

    if (playerPos.y <= 5.0) {
        return vec3(0.0);
    }

    vec3 baseCloudColor = vec3(1.0);

    // Lighting phase
    float phase = PhaseHG(dot(normalize(mat3(gbufferModelViewInverse) * lightVec), normalize(wpos)), 0.1);

    vec3 sunLightColor = cloudLightColor * phase * (1.0 - rainFactor);

    vec3 skyColor = GetSky(VdotU, VdotS, dither, false, false);

    vec3 color = (sunLightColor) * 50.0;

    color += (dither - 0.5) / 64.0;
    color *= cloudAlpha * cloudDistance;

    return color;
}
#endif