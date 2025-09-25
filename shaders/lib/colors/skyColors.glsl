#ifndef INCLUDE_SKY_COLORS
    #define INCLUDE_SKY_COLORS

    #ifdef OVERWORLD
        vec3 skyColorSqrt = sqrt(skyColor);

        float invRainStrength2 = (1.0 - rainStrength) * (1.0 - rainStrength);
        vec3  skyColorM  = mix(max(skyColorSqrt, vec3(0.58, 0.68, 0.98)),
                               skyColorSqrt, invRainStrength2);
        vec3  skyColorM2 = mix(max(skyColor,     sunFactor * vec3(0.24, 0.30, 0.39)),
                               skyColor, invRainStrength2);

        #ifdef SPECIAL_BIOME_WEATHER
            vec3 nmscSnowM = inSnowy * vec3(-0.28,  0.05,  0.22);
            vec3 nmscDryM  = inDry   * vec3(-0.28);
            vec3 ndscSnowM = inSnowy * vec3(-0.24, -0.01,  0.26);
            vec3 ndscDryM  = inDry   * vec3(-0.05, -0.09, -0.10);
        #else
            vec3 nmscSnowM = vec3(0.0), nmscDryM = vec3(0.0), ndscSnowM = vec3(0.0), ndscDryM = vec3(0.0);
        #endif

        #if RAIN_STYLE == 2
            vec3 nmscRainMP = vec3(-0.14,  0.025, 0.11);
            vec3 ndscRainMP = vec3(-0.12, -0.005, 0.13);
            #ifdef SPECIAL_BIOME_WEATHER
                vec3 nmscRainM = inRainy * nmscRainMP;
                vec3 ndscRainM = inRainy * ndscRainMP;
            #else
                vec3 nmscRainM = nmscRainMP;
                vec3 ndscRainM = ndscRainMP;
            #endif
        #else
            vec3 nmscRainM = vec3(0.0), ndscRainM = vec3(0.0);
        #endif

        vec3 nmscWeatherM = vec3(-0.10, -0.40, -0.60) + vec3(0.00, 0.07, 0.14) * noonFactor;
        vec3 ndscWeatherM = vec3(-0.15, -0.30, -0.42) + vec3(0.00, 0.03, 0.09) * noonFactor;

        vec3 noonUpSkyColor     = pow(skyColorM, vec3(2.6));

        vec3 noonMiddleSkyColor = skyColorM * (vec3(1.10, 1.18, 1.36)
                                   + rainFactor * (nmscWeatherM + nmscRainM + nmscSnowM + nmscDryM))
                                + noonUpSkyColor * 0.56; 

        vec3 noonDownSkyColor   = skyColorM * (vec3(0.94, 0.98, 1.06))
                                + noonUpSkyColor * 0.22;

        vec3 sunsetUpSkyColor     = skyColorM2 * (vec3(0.95, 0.60, 0.40)
                                              + vec3(0.10, 0.20, 0.35) * rainFactor2);

        vec3 sunsetMiddleSkyColor = skyColorM2 * (vec3(1.90, 1.12, 0.88) 
                                              + vec3(0.12, 0.20, -0.05) * rainFactor2);

        vec3 sunsetDownSkyColorP  = vec3(1.65, 0.78, 0.32) 
                                  - vec3(0.80, 0.30, 0.00) * rainFactor;
        vec3 sunsetDownSkyColor   = sunsetDownSkyColorP * 0.50
                                  + 0.24 * sunsetMiddleSkyColor;

        vec3 dayUpSkyColor     = mix(noonUpSkyColor,    sunsetUpSkyColor,    invNoonFactor2);
        vec3 dayMiddleSkyColor = mix(noonMiddleSkyColor,sunsetMiddleSkyColor,invNoonFactor2);
        vec3 dayDownSkyColor   = mix(noonDownSkyColor,  sunsetDownSkyColor,  invNoonFactor2);

        vec3 nightColFactor      = vec3(0.065, 0.125, 0.22) * (1.0 - 0.5 * rainFactor) + skyColor;
        vec3 nightUpSkyColor     = pow(nightColFactor, vec3(0.90)) * 0.40;
        vec3 nightMiddleSkyColor = sqrt(nightUpSkyColor) * 0.68;
        vec3 nightDownSkyColor   = nightMiddleSkyColor * vec3(0.82, 0.82, 0.88);
    #endif

#endif //INCLUDE_SKY_COLORS