#ifndef INCLUDE_SKY
    #define INCLUDE_SKY

    #include "/lib/colors/lightAndAmbientColors.glsl"
    #include "/lib/colors/skyColors.glsl"

    #ifdef CAVE_FOG
        #include "/lib/atmospherics/fog/caveFactor.glsl"
    #endif

    vec3 GetLowQualitySky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
        // Prepare variables
        float VdotUmax0 = max(VdotU, 0.0);
        float VdotUmax0M = 1.0 - pow2(VdotUmax0);

        // Prepare colors
        vec3 upColor = mix(nightUpSkyColor, dayUpSkyColor, sunFactor);
        vec3 middleColor = mix(nightMiddleSkyColor, dayMiddleSkyColor, sunFactor);

        // Mix the colors
            // Set sky gradient
            float VdotUM1 = pow2(1.0 - VdotUmax0);
                  VdotUM1 = mix(VdotUM1, 1.0, rainFactor2 * 0.2);
            vec3 finalSky = mix(upColor, middleColor, VdotUM1);

            // Add sunset color
            float VdotUM2 = pow2(1.0 - abs(VdotU));
                  VdotUM2 *= invNoonFactor * sunFactor * (0.8 + 0.2 * VdotS);
            finalSky = mix(finalSky, sunsetDownSkyColorP * (shadowTime * 0.6 + 0.2), VdotUM2 * invRainFactor);
        //

        // Sky Ground
        finalSky *= pow2(pow2(1.0 + min(VdotU, 0.0)));

        // Apply Underwater Fog
        if (isEyeInWater == 1)
            finalSky = mix(finalSky, waterFogColor, VdotUmax0M);

        // Sun/Moon Glare
        finalSky *= 1.0 + mix(nightFactor, 0.5 + 0.7 * noonFactor, VdotS * 0.5 + 0.5) * pow2(pow2(pow2(VdotS)));

        #ifdef CAVE_FOG
            // Apply Cave Fog
            finalSky = mix(finalSky, caveFogColor, GetCaveFactor() * VdotUmax0M);
        #endif

        return finalSky;
    }
    
    vec3 GetSky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
        float mieSharpness = 16.0;
        float mieStrength = 0.5;
        float skyGradient = 0.135;
        float lightScatter = 1.4;
        float sunlightInfluence = 0.5;
        float horizonBrightness = 7.0;
        float R_earth = 6360000.0;
        float H_atmos = 80000.0;

        float upness = clamp(VdotU * 0.5 + 0.5, 0.0, 1.0);
        float sunDotUp = clamp(VdotS * 0.5 + 0.5, 0.0, 1.0);
        float nightFactor = clamp(1.0 - (sunFactor + sunVisibility), 0.0, 1.0);
        float dayFactor = 1.0 - nightFactor;

        vec3 daySkyColor = vec3(0.2294, 0.3573, 0.9204);
        float horizonFactor = clamp(0.1 / max(VdotU, 0.0001), 0.0, 0.5);
        vec3 daySky = daySkyColor * horizonFactor * 2.0;

        vec3 dayColorScatter = pow(daySky, vec3(sunlightInfluence) - daySky);
        dayColorScatter = mix(
            dayColorScatter,
            daySky / (lightScatter * daySky + skyGradient - daySky),
            sunDotUp + horizonBrightness * lightColor
        ) + rainFactor;
        dayColorScatter = max(dayColorScatter, 0.0);

        float zenithFalloff = pow(upness, 1.0);
        dayColorScatter /= (1.0 + zenithFalloff);

        float h_view = H_atmos * (1.0 - VdotS);
        float horizonAngle = acos(R_earth / (R_earth + h_view));
        float opticalLength = sqrt((R_earth + H_atmos) * (R_earth + H_atmos) - R_earth * R_earth * (VdotS * VdotS));
        opticalLength = clamp(opticalLength / H_atmos, 0.0, 10.0);

        vec3 rayleighColor = vec3(0.5, 0.7, 1.0);
        float rayleighStrength = 4.0 - exp(-opticalLength);
        float visibility = exp(-pow(max(-sunDotUp, 0.5) * 2.0, 1.0)); // fades out behind horizon
        float rayleighPhase = (1.0 + sunDotUp * sunDotUp) * visibility;
        vec3 rayleigh = rayleighColor * rayleighPhase * rayleighStrength * lightColor;

        dayColorScatter += rayleigh;

        float miePhase = pow(sunDotUp, mieSharpness);
        dayColorScatter += lightColor * (miePhase * mieStrength);

        vec3 nightZenithColor = nightClearLightColor * 1.25;
        vec3 nightHorizonColor = vec3(0.6, 0.54, 0.4) * 1.15;
        vec3 nightSky = mix(nightHorizonColor, nightZenithColor, pow(upness, 0.4));

        vec3 color = mix(dayColorScatter, nightSky, nightFactor);

        if (doGround) {
            float groundFade = smoothstep(0.0, 1.0, pow(1.0 + min(VdotU, 0.0), 2.0));
            color *= groundFade;
        }

        if (doGlare) {
            float sunGlare = pow(max(VdotS, 0.0), 100.0);
            color += lightColor * sunGlare * 1.0;

            float moonIntensity = 0.2;
            float moonGlare = pow(max(-VdotS, 0.0), 25.0);
            vec3 moonColor = vec3(1.0, 0.85, 0.65);
            color += moonColor * moonGlare * moonIntensity * nightFactor;
        }

        color += (dither - 0.5) / 64;
        color *= 0.55;

        return color;
    }


#endif //INCLUDE_SKY