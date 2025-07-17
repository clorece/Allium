#include "/lib/colors/skyColors.glsl"

#define SHOOTING_STARS 1 // [0 1]

const float shootingStarLifeTime = 8.0; // total lifetime duration in seconds

float GetStarNoise(vec2 pos) {
    //return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
    return fract(sin(mod(dot(pos, vec2(12.9898, 78.233)),6.283)) * 43758.5453);
}

float GetShootingStarNoise(vec2 pos) {
    // Different seed to differentiate from static stars
    return fract(sin(mod(dot(pos, vec2(78.233, 12.9898)), 6.283)) * 43758.5453);
}

vec2 GetStarCoord(vec3 viewPos, float sphereness) {
    vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos * 1000.0, 1.0)).xyz);
    vec3 starCoord = wpos / (wpos.y + length(wpos.xz) * sphereness);
    starCoord.x += 0.001 * syncedTime;
    return starCoord.xz;
}

#if SHOOTING_STARS == 1
    float GetStarLifetimeNoise(vec2 pos) {
        float freq = 2.0; 
        float t = syncedTime * 0.05;

        float lifetimeValue = 0.5 + 0.5 * sin((pos.x + t) * 6.28318 * freq);
            lifetimeValue = smoothstep(0.3, 0.7, lifetimeValue);

        return lifetimeValue;
    }

    vec3 GetShootingStarsLayer(vec2 starCoord, float VdotU, float VdotS) {
        if (VdotU < 0.0) return vec3(0.0);

        float shootingStarNum = 0.95;
        float starFactor = 512.0;

        starCoord.x += -0.1 * syncedTime;
        starCoord.y *= 50.0;

        starCoord = floor(starCoord * starFactor) / starFactor;

        float star = shootingStarNum;
        star *= GetStarNoise(starCoord.xy);
        star *= GetStarNoise(starCoord.xy + 0.15);
        star *= GetStarNoise(starCoord.xy + 0.29);

        star -= 0.85;
        star = max0(star);
        star *= star;

        float lifetimeMask = GetStarLifetimeNoise(starCoord.xy);
        star *= lifetimeMask;

        star *= min1(VdotU * 3.0) * max0(1.0 - pow(abs(VdotS) * 1.002, 100.0));
        star *= invRainFactor * pow2(pow2(invNoonFactor2)) * (1.0 - 0.5 * sunVisibility);

        vec3 shootingStarColor = 100.0 * star * vec3(1.0, 0.9, 0.7);

        const int trailSteps = 4;
        const float trailSpacing = 0.0025;
        vec3 trailColor = vec3(0.0);

        for (int i = 1; i <= trailSteps; i++) {
            vec2 trailPos = starCoord;
            trailPos.x += float(i) * trailSpacing;
            trailPos = floor(trailPos * starFactor) / starFactor;

            float trailStar = shootingStarNum;
            trailStar *= GetStarNoise(trailPos.xy);
            trailStar *= GetStarNoise(trailPos.xy + 0.15);
            trailStar *= GetStarNoise(trailPos.xy + 0.29);

            trailStar -= 0.85;
            trailStar = max0(trailStar);
            trailStar *= trailStar;

            // ** Apply lifetime mask on trail as well for consistent fading **
            float trailLifetimeMask = GetStarLifetimeNoise(trailPos.xy);
            trailStar *= trailLifetimeMask;

            float fade = exp(-float(i) * 0.7);
            trailStar *= fade;

            trailStar *= min1(VdotU * 3.0) * max0(1.0 - pow(abs(VdotS) * 1.002, 100.0));
            trailStar *= invRainFactor * pow2(pow2(invNoonFactor2)) * (1.0 - 0.5 * sunVisibility);

            trailColor += 100.0 * trailStar * vec3(1.0, 0.9, 0.7);
        }

        return (shootingStarColor + trailColor) * 6.0;
    }
#endif

vec3 GetStars(vec2 starCoord, float VdotU, float VdotS) {
    if (VdotU < 0.0) return vec3(0.0);

    starCoord *= 0.5;
    float starFactor = 2046.0;
    starCoord = floor(starCoord * starFactor) / starFactor;

    float star = 1.05;
    star *= GetStarNoise(starCoord.xy);
    star *= GetStarNoise(starCoord.xy+0.1);
    star *= GetStarNoise(starCoord.xy+0.23);

    star -= 0.7;

    star = max0(star);
    star *= star;

    star *= min1(VdotU * 3.0) * max0(1.0 - pow(abs(VdotS) * 1.002, 100.0));
    star *= invRainFactor * pow2(pow2(invNoonFactor2)) * (1.0 - 0.5 * sunVisibility);

    vec3 staticStars = 40.0 * star * vec3(0.38, 0.4, 0.5);

    #if SHOOTING_STARS == 1
        vec3 shootingStars = GetShootingStarsLayer(starCoord, VdotU, VdotS);
    #else
        vec3 shootingStars = vec3(0.0);
    #endif

    return staticStars + shootingStars;
}