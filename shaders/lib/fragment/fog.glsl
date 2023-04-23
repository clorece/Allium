vec3 getFog(vec3 fragpos, vec3 color) {
    const float density = 1.0;
    const float fogStart = 100.0;
    const float fogEnd = 300.0;
    float distance = length(fragpos);
    float fogDensity = density * distance;  // increase density with distance

    vec3 fogColor = getSky(fragpos);

    vec3 pos = normalize(fragpos);

    float fogFactor = clamp((distance - fogEnd) / (fogStart - fogEnd), 0.0, 1.0) / density;
    fogFactor = fogFactor * fogFactor * (3.0 - 2.0 * fogFactor);

    return mix(fogColor, color, fogFactor);
}