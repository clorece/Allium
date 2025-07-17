#ifndef INCLUDE_SKY
    #define INCLUDE_SKY

    #include "/lib/colors/lightAndAmbientColors.glsl"
    #include "/lib/colors/skyColors.glsl"

    #ifdef CAVE_FOG
        #include "/lib/atmospherics/fog/caveFactor.glsl"
    #endif

    float starNoise(vec2 uv) {
        // Simple hash function for star brightness
        float n = fract(sin(dot(uv * 1000.0, vec2(12.9898,78.233))) * 43758.5453);
        return n;
    }

    float starfield(vec3 dir) {
        // Convert direction to spherical coords (theta, phi)
        float theta = acos(dir.y);             // vertical angle 0..pi
        float phi = atan(dir.z, dir.x);        // horizontal angle -pi..pi

        // Map angles to [0,1]
        vec2 uv = vec2(phi / (2.0 * 3.14159) + 0.5, theta / 3.14159);

        // Sample star noise
        float n = starNoise(uv * 1000.0);  // scale to get high freq

        // Threshold to create sparse stars
        float stars = step(0.995, n) * smoothstep(0.995, 1.0, n);

        return stars;
    }

    float milkyWayBand(vec3 dir) {
        // Define the axis of the band (you can tweak this)
        vec3 bandAxis = normalize(vec3(0.0, 0.3, 1.0)); 

        // Angle between view direction and band axis
        float angle = dot(dir, bandAxis);

        // Create a narrow band around angle ~1 (aligned with band axis)
        float band = smoothstep(0.2, 0.0, abs(angle - 1.0));

        // Modulate brightness of the band
        return band * 0.15; // tweak brightness as needed
    }
    
    vec3 GetSky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
        float mieSharpness = 16.0;
        float mieStrength = 0.5;
        float skyGradient = 0.05;
        float lightScatter = 1.7;
        float sunlightInfluence = 0.5;
        float horizonBrightness = 1.0;

        float upness = clamp(VdotU * 0.5 + 0.5, 0.0, 1.0);
        float nightFactor = clamp(1.0 - (sunFactor + sunVisibility), 0.0, 1.0);
        float dayFactor = 1.0 - nightFactor;
        
        vec3 daySkyColor = vec3(0.2294, 0.3573, 0.9204);
        float horizonFactor = clamp(0.1 / max(VdotU, 0.001), 0.0, 0.5);
        vec3 daySky = daySkyColor * horizonFactor;

        float sunDotUp = clamp(VdotS * 0.5 + 0.5, 0.0, 1.0);
        vec3 dayColorScatter = pow(daySky, vec3(sunlightInfluence) - daySky);
        dayColorScatter = mix(
            dayColorScatter,
            daySky / (lightScatter * daySky + skyGradient - daySky),
            sunDotUp + horizonBrightness * lightColor
        );
        dayColorScatter = max(dayColorScatter, 0.0);

        float zenithFalloff = pow(upness, 1.0);
        dayColorScatter /= (1.0 + zenithFalloff);

        float miePhase = pow(sunDotUp, mieSharpness);
        dayColorScatter += lightColor * (miePhase * mieStrength);

        vec3 nightZenithColor = vec3(0.06, 0.09, 0.15) * 1.1;
        vec3 nightHorizonColor = vec3(0.5, 0.5, 0.4) * 1.0; 

        vec3 nightSky = mix(nightHorizonColor, nightZenithColor, pow(upness, 0.4));

        float starIntensity = smoothstep(0.995, 1.0, fract(sin(dot(vec2(dither, dither * 1.37), vec2(12.9898,78.233))) * 43758.5453));
        nightSky += vec3(starIntensity * 0.1);

        vec3 color = mix(dayColorScatter, nightSky, nightFactor);

        if (doGround) {
            float groundFade = smoothstep(0.0, 1.0, pow(1.0 + min(VdotU, 0.0), 2.0));
            color *= groundFade;
        }

        color *= 1.1;

        return color;
    }
#endif //INCLUDE_SKY