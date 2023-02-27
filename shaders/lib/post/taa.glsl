const bool colortex5Clear = false;

// Function to clamp a color value to the neighborhood of the previous frame
vec3 clampToNeighborhood(vec3 color, vec3 prevColor, float threshold) {
    // chatgpt really saved me on this one lol
    vec3 delta = color - prevColor;
    vec3 clampedDelta = clamp(delta, -threshold, threshold);
    return prevColor + clampedDelta;
}

vec4 temporalAA(vec2 resolution) {
    vec4 currentColor = texture2D(colortex0, texCoord);
    vec4 previousColor = texture2D(colortex5, texCoord);

    vec4 reprojection = mix(currentColor, previousColor, blendWeight);
    vec4 filteredColor = vec4(0.0);

    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 offset = vec2(float(i), float(j)) * resolution;
            vec3 sampleColor = texture(colortex0, texCoord + offset).rgb;
            vec3 clampedColor = clampToNeighborhood(sampleColor, previousColor.rgb, 0.05);
            filteredColor.rgb += clampedColor;
        }
    }

    filteredColor.rgb /= 9.0;
    return mix(reprojection, filteredColor, blendWeight);
}