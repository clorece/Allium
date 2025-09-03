#ifndef INCLUDE_SKY_COLORS
    #define INCLUDE_SKY_COLORS

    #ifdef OVERWORLD
        vec3 skyColorSqrt = sqrt(skyColor);

        // a1-aligned floors:
        // - Raise blue bias a bit for Rayleigh daytime (more like a1's coeffs ratio ~ (0.21, 0.44, 1.0))
        // - Keep a guard during storms but let zenith stay blue.
        float invRainStrength2 = (1.0 - rainStrength) * (1.0 - rainStrength);
        vec3  skyColorM  = mix(max(skyColorSqrt, vec3(0.58, 0.68, 0.98)),  // was (0.63, 0.67, 0.93)
                               skyColorSqrt, invRainStrength2);
        vec3  skyColorM2 = mix(max(skyColor,     sunFactor * vec3(0.24, 0.30, 0.39)), // was (0.265, 0.295, 0.35)
                               skyColor, invRainStrength2);

        #ifdef SPECIAL_BIOME_WEATHER
            vec3 nmscSnowM = inSnowy * vec3(-0.28,  0.05,  0.22);   // tiny blue lift in snow
            vec3 nmscDryM  = inDry   * vec3(-0.28);                 // keep desat in dry biomes
            vec3 ndscSnowM = inSnowy * vec3(-0.24, -0.01,  0.26);
            vec3 ndscDryM  = inDry   * vec3(-0.05, -0.09, -0.10);
        #else
            vec3 nmscSnowM = vec3(0.0), nmscDryM = vec3(0.0), ndscSnowM = vec3(0.0), ndscDryM = vec3(0.0);
        #endif

        #if RAIN_STYLE == 2
            // small cool shift with rain; keep consistent with a1’s stronger blue scatter
            vec3 nmscRainMP = vec3(-0.14,  0.025, 0.11);  // was (-0.15, 0.025, 0.10)
            vec3 ndscRainMP = vec3(-0.12, -0.005, 0.13);  // was (-0.125,-0.005, 0.125)
            #ifdef SPECIAL_BIOME_WEATHER
                vec3 nmscRainM = inRainy * nmscRainMP;    // (fixed source; was ndscRainMP)
                vec3 ndscRainM = inRainy * ndscRainMP;
            #else
                vec3 nmscRainM = nmscRainMP;
                vec3 ndscRainM = ndscRainMP;
            #endif
        #else
            vec3 nmscRainM = vec3(0.0), ndscRainM = vec3(0.0);
        #endif

        // Weather mixes lean slightly bluer at noon (a1 Rayleigh tilt)
        vec3 nmscWeatherM = vec3(-0.10, -0.40, -0.60) + vec3(0.00, 0.07, 0.14) * noonFactor; // was (0.06,0.12)
        vec3 ndscWeatherM = vec3(-0.15, -0.30, -0.42) + vec3(0.00, 0.03, 0.09) * noonFactor; // was (0.02,0.08)

        // --- NOON (daytime, Rayleigh-dominant) ---
        // Slightly softer exponent (2.6) to avoid over-deepening blue; matches a1’s broader zenith.
        vec3 noonUpSkyColor     = pow(skyColorM, vec3(2.6));              // was 2.9

        // Boost blue channel a touch more vs. G, consistent with a1’s coeff ratios
        vec3 noonMiddleSkyColor = skyColorM * (vec3(1.10, 1.18, 1.36)     // was (1.15) scalar + add
                                   + rainFactor * (nmscWeatherM + nmscRainM + nmscSnowM + nmscDryM))
                                + noonUpSkyColor * 0.56;                  // was 0.6

        // Horizon is paler and slightly cooler than before
        vec3 noonDownSkyColor   = skyColorM * (vec3(0.94, 0.98, 1.06))    // was vec3(0.9)
                                + noonUpSkyColor * 0.22;                  // was 0.25

        // --- SUNSET (ozone + Mie warm) ---
        // Stronger G/B suppression to let R push through (a1 ozone cross-section is higher in B/G)
        vec3 sunsetUpSkyColor     = skyColorM2 * (vec3(0.95, 0.60, 0.40)   // was (0.8, 0.58, 0.58)
                                              + vec3(0.10, 0.20, 0.35) * rainFactor2);

        vec3 sunsetMiddleSkyColor = skyColorM2 * (vec3(1.90, 1.12, 0.88)  // was (1.8, 1.3, 1.2)
                                              + vec3(0.12, 0.20, -0.05) * rainFactor2);

        vec3 sunsetDownSkyColorP  = vec3(1.65, 0.78, 0.32)                // was (1.45, 0.86, 0.5)
                                  - vec3(0.80, 0.30, 0.00) * rainFactor;
        vec3 sunsetDownSkyColor   = sunsetDownSkyColorP * 0.50
                                  + 0.24 * sunsetMiddleSkyColor;          // was 0.25

        // Blends (unchanged structure)
        vec3 dayUpSkyColor     = mix(noonUpSkyColor,    sunsetUpSkyColor,    invNoonFactor2);
        vec3 dayMiddleSkyColor = mix(noonMiddleSkyColor,sunsetMiddleSkyColor,invNoonFactor2);
        vec3 dayDownSkyColor   = mix(noonDownSkyColor,  sunsetDownSkyColor,  invNoonFactor2);

        // --- NIGHT (keep neutral, a1 doesn’t impose strong night color) ---
        vec3 nightColFactor      = vec3(0.065, 0.125, 0.22) * (1.0 - 0.5 * rainFactor) + skyColor; // was (0.07,0.14,0.24)
        vec3 nightUpSkyColor     = pow(nightColFactor, vec3(0.90)) * 0.40;
        vec3 nightMiddleSkyColor = sqrt(nightUpSkyColor) * 0.68;
        vec3 nightDownSkyColor   = nightMiddleSkyColor * vec3(0.82, 0.82, 0.88);
    #endif

#endif //INCLUDE_SKY_COLORS