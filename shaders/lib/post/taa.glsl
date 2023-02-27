const bool colortex5Clear = false;

vec3 clampToNeighborhood(vec3 color, vec3 prevColor) {
    // chatgpt really saved me on this one lol
    vec3 delta = color - prevColor;
    vec3 clampedDelta = clamp(delta, -TAA_NEIGHBORHOOD_THRESHOLD, TAA_NEIGHBORHOOD_RADIUS);
    return (prevColor) + clampedDelta;
}

vec4 temporalAA(vec2 resolution) {
    vec4 currentColor = texture2D(colortex0, texCoord);
    vec4 previousColor = texture2D(colortex5, texCoord);

    vec4 reprojection = mix(currentColor, previousColor, blendWeight);
    vec4 filteredColor = vec4(0.0);

    
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 offset = vec2(float(i), float(j)) * resolution / TAA_OFFSET_WEIGHT;
            vec3 sampleColor = texture2D(colortex0, texCoord + offset).rgb;
            vec3 clampedColor = clampToNeighborhood(sampleColor.rgb, previousColor.rgb);
            filteredColor.rgb += clampedColor;
        }
    }
    filteredColor /= 9.0;

    float sharpness = 1.0;
    float strength = TAA_SHARPNESS;
    vec3 edge = currentColor.rgb - filteredColor.rgb;
    filteredColor.rgb += edge * 1.0 * strength;
    return mix(reprojection, filteredColor, blendWeight);
}