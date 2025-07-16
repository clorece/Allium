#ifndef INCLUDE_SKY
    #define INCLUDE_SKY

    #include "/lib/colors/lightAndAmbientColors.glsl"
    #include "/lib/colors/skyColors.glsl"

    #ifdef CAVE_FOG
        #include "/lib/atmospherics/fog/caveFactor.glsl"
    #endif
    
    // Henyey-Greenstein phase for Mie scattering
    float PhaseHGSky(float cosTheta, float g) {
        float g2 = g * g;
        float denom = 1.0 + g2 - 2.0 * g * cosTheta;
        return (1.0 - g2) / (4.0 * 3.14159 * pow(denom, 1.5));
    }

    // Rayleigh phase function (simple)
    float PhaseRayleigh(float cosTheta) {
        // Rayleigh phase: (3/16π) * (1 + cos²θ)
        return (3.0 / (16.0 * 3.14159)) * (1.0 + cosTheta * cosTheta);
    }

    
    vec3 GetSky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
        // Constants for atmospheric scattering
        float mieSharpness = 16.0;
        float mieStrength = 0.5;
        float skyGradient = 0.05;
        float lightScatter = 1.7;
        float sunlightInfluence = 0.5;
        float horizonBrightness = 1.0;

        float VdotSML = sunVisibility > 0.5 ? VdotS : -VdotS;

        vec3 daySkyColor = vec3(0.2294, 0.3573, 0.9204);
        vec3 baseSkyColor = mix(nightUpSkyColor, daySkyColor, (sunFactor + sunVisibility) * 0.5);
        baseSkyColor = mix(baseSkyColor, vec3(1.0), rainFactor * 0.5);

        float horizonFactor = clamp(0.1 / max(VdotU, 0.001), 0.0, 0.5);
        vec3 horizonColor = baseSkyColor * horizonFactor;

        vec3 color = mix(nightUpSkyColor * 0.5, horizonColor, (sunFactor + sunVisibility) * 0.5);
        color = max(color, 0.0);

        float sunDotUp = clamp(VdotS * 0.5 + 0.5, 0.0, 1.0); 
        vec3 scatterBlend = mix(
            pow(color, vec3(sunlightInfluence) - color),
            color / (lightScatter * color + skyGradient - color),
            sunDotUp + horizonBrightness * lightColor
        );
        color = max(scatterBlend, 0.0);

        float zenithFalloff = pow(clamp(VdotU * 0.5 + 0.5, 0.0, 1.0), 1.0);
        color /= (1.0 + zenithFalloff);

        float miePhase = pow(clamp(VdotS * 0.5 + 0.5, 0.0, 1.0), mieSharpness);
        color += lightColor * (miePhase * mieStrength);

        // Fade to black or night color below horizon
        if (doGround) {
            float groundFade = smoothstep(0.0, 1.0, pow(1.0 + min(VdotU, 0.0), 2.0));
            color *= groundFade;
        }

        if (doGlare) {
            if (0.0 < VdotSML) {
                float glareScatter = 4.0 * (2.0 - clamp01(VdotS * 1000.0));
                float VdotSM4 = pow(abs(VdotS), glareScatter);

                float visfactor = 0.075;
                float glare = visfactor / (1.0 - (1.0 - visfactor) * VdotSM4) - visfactor;

                glare *= 0.5 + pow2(noonFactor) * 1.0;
                glare *= 1.0 - rainFactor * 0.5;

                float glareWaterFactor = isEyeInWater * sunVisibility;
                vec3 glareColor = mix(vec3(0.38, 0.4, 0.5) * 0.7, vec3(0.5), sunVisibility);
                     glareColor = glareColor + glareWaterFactor * vec3(7.0);

                color += glare * shadowTime * glareColor;
            }
        }

        color += (dither - 0.5) / 128.0;

        color *= 1.1;

        return color;
    }
#endif //INCLUDE_SKY