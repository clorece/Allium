#include "/lib/colors/skyColors.glsl"

//#define SHOOTING_STARS
#define PLANETARY_STARS_CONDITION 2 // [0 1 2]

float GetStarNoise(vec2 pos) {
    //return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
    return fract(sin(mod(dot(pos, vec2(12.9898, 78.233)),6.283)) * 43758.5453);
}

vec2 GetStarCoord(vec3 viewPos, float sphereness) {
    vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos * 1000.0, 1.0)).xyz);
    vec3 starCoord = wpos / (wpos.y + length(wpos.xz) * sphereness);
    starCoord.x += 0.001 * syncedTime;
    return starCoord.xz;
}

#ifdef SHOOTING_STARS
    float GetStarLifetimeNoise(vec2 pos) {
        float freq = 6.0; 
        float t = syncedTime * 0.05;

        float lifetimeValue = 0.5 + 0.5 * sin((pos.x + t) * 6.28318 * freq);
            lifetimeValue = smoothstep(0.3, 0.7, lifetimeValue);

        return lifetimeValue;
    }

    vec3 GetShootingStarsLayer(vec2 starCoord, float VdotU, float VdotS) {
        if (VdotU < 0.0) return vec3(0.0);

        float shootingStarNum = 0.9;
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

            trailColor += 2048.0 * trailStar * vec3(1.0, 0.9, 0.7);
        }

        return (shootingStarColor + trailColor) * 6.0;
    }
#endif

vec3 GetStars(vec2 starCoord, float VdotU, float VdotS) {
    if (VdotU < 0.0) return vec3(0.0);

    vec2 baseCoord = starCoord * 0.5;
    float starFactor = 1536.0;
    vec2 staticCoord = floor(baseCoord * starFactor) / starFactor;

    float star = 1.05;
    star *= GetStarNoise(staticCoord);
    star *= GetStarNoise(staticCoord + 0.1);
    star *= GetStarNoise(staticCoord + 0.23);
    star -= 0.7;
    star = max0(star);
    star *= star;

    float fade = min1(VdotU * 3.0) * max0(1.0 - pow(abs(VdotS) * 1.002, 100.0));
    fade *= invRainFactor * pow2(pow2(invNoonFactor2)) * (1.0 - 0.5 * sunVisibility);

    vec3 staticStars = 30.0 * star * vec3(0.38, 0.4, 0.5) * fade;

    #if PLANETARY_STARS_CONDITION == 2
        float planetFactor = 768.0;
        vec2 planetCoord = floor(baseCoord * planetFactor) / planetFactor;

        float p1 = GetStarNoise(planetCoord);
        float p2 = GetStarNoise(planetCoord + vec2(0.12, 0.21));
        float p3 = GetStarNoise(planetCoord + vec2(0.33, 0.77));
        float pNoise = p1 * p2 * p3;
        pNoise -= 0.93;
        float planetMask = max0(pNoise);
        planetMask *= planetMask;

        float hue = fract(sin(dot(planetCoord, vec2(17.23, 48.73))) * 43758.5453);
        vec3 planetColor = hsv2rgb(vec3(hue, 0.6, 1.0));

        vec3 planetStars = 8196.0 * planetMask * planetColor * fade;

        float flicker = 0.9 + 0.1 * sin(syncedTime * 2.5 + dot(planetCoord, vec2(23.0, 19.0)) * 10.0);
        planetStars *= flicker;
    #else
        vec3 planetStars = vec3(0.0);
    #endif

    #ifdef SHOOTING_STARS
        vec3 shootingStars = GetShootingStarsLayer(staticCoord, VdotU, VdotS);
    #else
        vec3 shootingStars = vec3(0.0);
    #endif

    return staticStars + planetStars + shootingStars;
}