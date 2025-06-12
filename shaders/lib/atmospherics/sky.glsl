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
        
        float skyGradient = 0.075;
        float rayleighScatteringStrength = 1.7;
        float sunlightInfluence = 0.5;
        float horizonBrightness = 1.0;
    

        // === Constants and parameters ===
        vec3 fogColor = vec3(0.2294, 0.3573, 0.9204);
            fogColor = mix(nightUpSkyColor, fogColor, (sunFactor + sunVisibility) * 0.5);
            fogColor = mix(fogColor, vec3(1.0, 1.0, 1.0), rainFactor * 0.5);
        float mieSharpness = 3.14 * 25.0;
        float sunSharpness = 3.14 * 700.0;

        // === Horizon-based sky color ===
        float horizon = 0.2 / max(VdotU, 0.0001); 
            horizon = clamp(horizon, 0.0, 10.0);
        vec3 color = fogColor * horizon;
        color = mix(nightUpSkyColor * 0.2, color, (sunFactor + sunVisibility) * 0.5);
        color = max(color, 0.0);

        
        // === Sun influence on color blending ===
        float sunDotUp = clamp(VdotS * 0.5 + 0.5, 0.2, 0.1);
        //float sunDotUp = clamp(VdotS * 0.5 + 0.5, 0.0, 1.0);
        vec3 mixedColor = mix(
            pow(color, sunlightInfluence - color),
            color / (rayleighScatteringStrength * color + skyGradient - color),
            sunDotUp + lightColor * horizonBrightness
        );
        color = max(mixedColor, 0.0);

        // === Fade toward zenith ===
        float zenithFalloff = pow(VdotU * 0.5 + 0.5, 1.0);
        color /= 1.0 + zenithFalloff;

        // === Mie scattering near sun ===
        float mieScatter = pow(VdotS * 0.5 + 0.5, mieSharpness);
        color += lightColor * (mieScatter * 0.5);

        //float underscatter = distance(VdotS * 0.5 + 0.5, 1.0);
        //color = mix(color, vec3(0.0), clamp(underscatter, 0.0, 1.0));

        // === Optional ground fade ===
        if (doGround) {
            float groundFade = smoothstep(0.0, 1.0, pow(1.0 + min(VdotU, 0.0), 2.0));
            color *= groundFade;
        }

        //color *= pow2(pow2(1.1 + min(VdotU, 0.0)));

        // === Optional dither to fix banding ===
        color += (dither - 0.5) / 128.0;

        //color = pow(color, vec3(2.2));
        color *= 1.2;

        return color;
    }
#endif //INCLUDE_SKY