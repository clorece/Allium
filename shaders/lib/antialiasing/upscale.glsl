// Lanczos-2 Upscaling Function
float lanczos2(float x) {
    if (x == 0.0) return 1.0;
    return 2.0 * sin(3.14159 * x) * sin(3.14159 * x / 2.0) / (3.14159 * 3.14159 * x * x);
}

vec3 textureEASU(sampler2D colortex, vec2 texcoord, vec2 valRes) {
    vec2 position = texcoord * valRes;
    vec2 centerPosition = floor(position - 0.5) + 0.5;
    vec2 f = position - centerPosition;

    vec3 color = vec3(0.0);
    float totalWeight = 0.0;
    
    vec3 minColor = vec3(1000.0);
    vec3 maxColor = vec3(-1000.0);

    for(int x = -1; x <= 2; x++) {
        for(int y = -1; y <= 2; y++) {
            vec3 sampleColor = texture2D(colortex, (centerPosition + vec2(x, y)) / valRes).rgb;
            
            // Accumulate min/max for anti-ringing
            minColor = min(minColor, sampleColor);
            maxColor = max(maxColor, sampleColor);
            
            float dist = distance(vec2(x, y), f);
            float weight = lanczos2(dist);
            color += sampleColor * weight;
            totalWeight += weight;
        }
    }
    vec3 finalColor = color / totalWeight;
    
    // Anti-ringing clamp
    return clamp(finalColor, minColor, maxColor);
}
