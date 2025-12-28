#ifdef OVERWORLD
    vec3 cloudRainColor = mix(nightMiddleSkyColor, dayMiddleSkyColor, sunFactor);
    vec3 cloudAmbientColor = mix(ambientColor * (sunVisibility2 * (0.55 + 0.1 * noonFactor) + 0.35), cloudRainColor * 0.5, rainFactor);
    vec3 cloudLightColor   = mix(lightColor * (1.5 + 0.5 * noonFactor), cloudRainColor * 0.25, noonFactor * rainFactor);
#endif