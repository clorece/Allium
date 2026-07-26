#ifndef UTIL_TIME_GLSL
#define UTIL_TIME_GLSL

struct TimeState {
    float sunUp;
    float moonUp;
    float sunActivity;
    float moonActivity;
    
    // Time-of-day continuous weights
    float timeSunrise;
    float timeSunset;
    float timeNoon;
    float timeMidnight;
    
    // Smooth transition mask for when the shadow map flips
    float shadowFade;
    
    // active light
    vec3 activeLightDir;
    vec3 lightColor;
    vec3 sunColor;
    vec3 moonColor;
};

TimeState getTimeState() {
    TimeState t;
    
    vec3 worldSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    vec3 worldMoonDir = -worldSunDir;
    
    t.sunUp = worldSunDir.y;
    t.moonUp = worldMoonDir.y;
    
    t.sunActivity  = smoothstep(-0.1, 0.16, t.sunUp);
    t.moonActivity = smoothstep(-0.1, 0.10, t.moonUp);

    // Golden-hour strength must stay local to the horizon. Preserve the existing
    // dawn/dusk curve, but taper its daytime tail: the old lobe did not reach zero
    // until sunUp~=0.77. With the much stronger sunrise/sunset VL multiplier,
    // that residual tail amplified warm Mie scatter around world times 3000 and
    // 9000 and read as two red spikes in otherwise broad daylight.
    float meFade = (t.sunUp < 0.18) ? (0.37 + 1.2 * max(0.0, -t.sunUp)) : 1.7;
    float meWeight = pow(clamp(1.0 - meFade * abs(t.sunUp - 0.18), 0.0, 1.0), 2.0);
    meWeight *= 1.0 - smoothstep(0.35, 0.55, t.sunUp);
    
    t.timeSunrise  = ((worldSunDir.x > 0.0) ? 1.0 : 0.0) * meWeight;
    t.timeSunset   = ((worldSunDir.x < 0.0) ? 1.0 : 0.0) * meWeight;
    t.timeNoon     = ((t.sunUp > 0.0) ? 1.0 : 0.0) * (1.0 - meWeight);
    t.timeMidnight = ((t.sunUp < 0.0) ? 1.0 : 0.0) * (1.0 - meWeight);
    
    t.shadowFade = 1.0 - (smoothstep(-0.02, -0.05, t.sunUp) * smoothstep(-0.08, -0.05, t.sunUp));

    // Match vectors.glsl exactly: every pass must follow the same shadow-map
    // light instead of choosing its own geometric horizon cutoff.
    t.activeLightDir = (worldTime < 12700 || worldTime > 23250)
                     ? worldSunDir : worldMoonDir;

    vec3 sunColorBase  = mix(vec3(1.0, 0.65, 0.35) * 0.15, vec3(1.0, 0.95, 0.9), max(t.sunUp, 0.0));
    t.sunColor      = sunColorBase * t.sunActivity;

    vec3 moonColorBase = vec3(0.65, 0.85, 1.0) * 0.02;
    t.moonColor     = moonColorBase * t.moonActivity;

    t.lightColor = t.sunColor + t.moonColor;
    
    return t;
}

#endif
