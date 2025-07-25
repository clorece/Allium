#ifndef INCLUDE_LIGHT_AND_AMBIENT_COLORS
    #define INCLUDE_LIGHT_AND_AMBIENT_COLORS

    #if defined OVERWORLD

        #ifndef COMPOSITE //ground and cloud color
            vec3 noonClearLightColor = vec3(0.75, 0.7, 0.6);



        #else //light shaft color
            vec3 noonClearLightColor = vec3(0.55, 0.53, 0.5);
        #endif


        // noonAmbientColor
        //vec3 noonClearAmbientColor = pow(skyColor, vec3(0.65)) * 0.85;
        vec3 noonClearAmbientColor = vec3(0.51, 0.545, 0.52);



        #ifndef COMPOSITE //ground and cloud color
            vec3 sunsetClearLightColor = pow(vec3(0.58, 0.43, 0.22), vec3(1.5 + invNoonFactor)) * 3.0;



        #else //light shaft color
            vec3 sunsetClearLightColor = pow(vec3(0.51, 0.43, 0.32), vec3(1.5 + invNoonFactor)) * 6.8;
        #endif



        // sunset ambient
        vec3 sunsetClearAmbientColor   = vec3(0.51, 0.545, 0.52);


        #if !defined COMPOSITE && !defined DEFERRED1 //ground color
            vec3 nightClearLightColor = vec3(0.15, 0.14, 0.20) * (0.4 + vsBrightness * 0.4);
        #elif defined DEFERRED1
            vec3 nightClearLightColor = vec3(0.11, 0.14, 0.20); //cloud color
        #else
            vec3 nightClearLightColor = vec3(0.07, 0.12, 0.27); //light shaft color
        #endif
        vec3 nightClearAmbientColor   = vec3(0.09, 0.12, 0.17) * (1.55 + vsBrightness * 0.77);

        #ifdef SPECIAL_BIOME_WEATHER
            vec3 drlcSnowM = inSnowy * vec3(-0.06, 0.0, 0.04);
            vec3 drlcDryM = inDry * vec3(0.0, -0.03, -0.05);
        #else
            vec3 drlcSnowM = vec3(0.0), drlcDryM = vec3(0.0);
        #endif
        #if RAIN_STYLE == 2
            vec3 drlcRainMP = vec3(-0.03, 0.0, 0.02);
            #ifdef SPECIAL_BIOME_WEATHER
                vec3 drlcRainM = inRainy * drlcRainMP;
            #else
                vec3 drlcRainM = drlcRainMP;
            #endif
        #else
            vec3 drlcRainM = vec3(0.0);
        #endif

        // day rain colors
        vec3 dayRainLightColor   = vec3(0.7, 0.7, 0.6) * 0.3 + noonFactor * vec3(0.0, 0.02, 0.06)
                                + rainFactor * (drlcRainM + drlcSnowM + drlcDryM);
        vec3 dayRainAmbientColor = vec3(0.2, 0.2, 0.25) * (1.8 + 0.5 * vsBrightness);

        // night rain colors
        vec3 nightRainLightColor   = vec3(0.01, 0.02, 0.03) * (0.5 + 0.5 * vsBrightness);
        vec3 nightRainAmbientColor = vec3(0.051, 0.0545, 0.052) * (0.75 + 0.6 * vsBrightness);

        #ifndef COMPOSITE
            float noonFactorDM = noonFactor; //ground and cloud factor
        #else
            float noonFactorDM = noonFactor * noonFactor; //light shaft factor
        #endif


        // mixing
        vec3 dayLightColor   = mix(sunsetClearLightColor, noonClearLightColor, noonFactorDM);
        vec3 dayAmbientColor = mix(sunsetClearAmbientColor, noonClearAmbientColor, noonFactorDM);

        vec3 clearLightColor   = mix(nightClearLightColor, dayLightColor, sunVisibility2);
        vec3 clearAmbientColor = mix(nightClearAmbientColor, dayAmbientColor, sunVisibility2);

        vec3 rainLightColor   = mix(nightRainLightColor, dayRainLightColor, sunVisibility2) * 1.5;
        vec3 rainAmbientColor = mix(nightRainAmbientColor, dayRainAmbientColor, sunVisibility2);

        vec3 lightColor   = mix(clearLightColor, rainLightColor, rainFactor) * 0.7;
        vec3 ambientColor = mix(clearAmbientColor, rainAmbientColor, rainFactor) * 1.5;
    #elif defined NETHER
        vec3 lightColor   = vec3(0.0);
        vec3 ambientColor = (netherColor + 2.5 * lavaLightColor) * (0.9 + 0.45 * vsBrightness);
    #elif defined END
        vec3 endLightColor = vec3(0.68, 0.51, 1.07) * 1.5;
        float endLightBalancer = 0.2 * vsBrightness;
        vec3 lightColor    = endLightColor * (0.35 - endLightBalancer);
        vec3 ambientColor  = endLightColor * (0.2 + endLightBalancer);
    #endif

#endif //INCLUDE_LIGHT_AND_AMBIENT_COLORS