#define AUTO_EXPOSURE_SPEED 0.5      
#define AUTO_EXPOSURE_MIN 0.4      
#define AUTO_EXPOSURE_MAX 4.0        
#define AUTO_EXPOSURE_TARGET 0.25    // default is 0.25
#define AUTO_EXPOSURE_BIAS 0.0       // [-1.0, 1.0]
#define AUTO_EXPOSURE_THRESHOLD 0.1 

// Metering modes
#define METERING_MODE 0              // [0 1 2] 0=Average, 1=Center-Weighted, 2=Spot
/*
float GetSceneLuminance(sampler2D colorTex) {
    #if METERING_MODE == 0
        float totalLuminance = 0.0;
        int sampleCount = 0;
        
        for (int x = 0; x < 4; x++) {
            for (int y = 0; y < 4; y++) {
                vec2 sampleCoord = (vec2(float(x), float(y)) + 0.5) / 4.0;
                vec3 sampleColor = textureLod(colorTex, sampleCoord, 5.0).rgb;
                float lum = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));
                totalLuminance += lum;
                sampleCount++;
            }
        }
        
        float avgLuminance = totalLuminance / float(sampleCount);
        
    #elif METERING_MODE == 1
        vec3 centerColor = textureLod(colorTex, vec2(0.5), 4.0).rgb;
        float centerLum = dot(centerColor, vec3(0.2126, 0.7152, 0.0722));
        
        float edgeLuminance = 0.0;
        int edgeSamples = 0;
        for (int x = 0; x < 3; x++) {
            for (int y = 0; y < 3; y++) {
                if (x == 1 && y == 1) continue; // Skip center
                vec2 sampleCoord = (vec2(float(x), float(y)) + 0.5) / 3.0;
                vec3 sampleColor = textureLod(colorTex, sampleCoord, 5.0).rgb;
                edgeLuminance += dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));
                edgeSamples++;
            }
        }
        edgeLuminance /= float(edgeSamples);
        
        float avgLuminance = mix(edgeLuminance, centerLum, 0.7);
        
    #elif METERING_MODE == 2
        vec3 avgColor = textureLod(colorTex, vec2(0.5), 3.0).rgb;
        float avgLuminance = dot(avgColor, vec3(0.2126, 0.7152, 0.0722));
    #endif

    avgLuminance = max(avgLuminance, 0.001);
    
    return avgLuminance;
}
*/
// Calculate exposure value from luminance
float CalculateExposure(float avgLuminance) {
    // Use the standard photographic exposure formula
    // EV = log2(avgLuminance / targetLuminance)
    float exposure = AUTO_EXPOSURE_TARGET / avgLuminance;
    
    // Apply bias
    exposure *= exp2(AUTO_EXPOSURE_BIAS);
    
    // Clamp to min/max range
    exposure = clamp(exposure, AUTO_EXPOSURE_MIN, AUTO_EXPOSURE_MAX);
    
    return exposure;
}

float GetSceneLuminanceHistogram(sampler2D colorTex, float dither) {
    #if METERING_MODE == 0
        float totalLuminance = 0.0;
        int sampleCount = 0;
        
        const int samples = 6;
        for (int x = 0; x < samples; x++) {
            for (int y = 0; y < samples; y++) {
                vec2 offset = (vec2(float(x), float(y)) + 0.5) / float(samples);
                offset += (dither - 0.5) / float(samples * 2); // Small jitter
                
                vec3 sampleColor = textureLod(colorTex, offset, 2.0).rgb;
                float sampleLum = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));
                
                totalLuminance += log(sampleLum + 0.001);
                sampleCount++;
            }
        }
        
        return exp(totalLuminance / float(sampleCount));
        
    #elif METERING_MODE == 1
        float totalLuminance = 0.0;
        float totalWeight = 0.0;
        
        const int samples = 6;
        for (int x = 0; x < samples; x++) {
            for (int y = 0; y < samples; y++) {
                vec2 offset = (vec2(float(x), float(y)) + 0.5) / float(samples);
                offset += (dither - 0.5) / float(samples * 2);
                
                vec3 sampleColor = textureLod(colorTex, offset, 2.0).rgb;
                float sampleLum = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));
                
                vec2 centerDist = abs(offset - 0.5) * 2.0;
                float weight = 1.0 - length(centerDist) * 0.6;
                weight = max(weight, 0.1);
                
                totalLuminance += log(sampleLum + 0.001) * weight;
                totalWeight += weight;
            }
        }
        
        return exp(totalLuminance / totalWeight);
        
    #elif METERING_MODE == 2
        vec3 centerColor = textureLod(colorTex, vec2(0.5), 3.0).rgb;
        return dot(centerColor, vec3(0.2126, 0.7152, 0.0722));
    #endif
}

float GetAutoExposure(sampler2D colorTex, float dither) {
    float currentLuminance = GetSceneLuminanceHistogram(colorTex, dither);
    
    float targetExposure = CalculateExposure(currentLuminance);

    ivec2 historyCoord = ivec2(0, 0);
    float previousExposure = texelFetch(colortex4, historyCoord, 0).g;

    if (previousExposure <= 0.0 || isnan(previousExposure)) {
        previousExposure = targetExposure;
    }
    
    float exposureDiff = abs(targetExposure - previousExposure);

    float thresholdFactor = smoothstep(AUTO_EXPOSURE_THRESHOLD * 0.5, AUTO_EXPOSURE_THRESHOLD, exposureDiff);

    if (thresholdFactor < 0.01) {
        return previousExposure;
    }

    float adaptationSpeed = AUTO_EXPOSURE_SPEED * thresholdFactor;
    if (targetExposure > previousExposure) {
        adaptationSpeed *= 0.5;
    }
    
    float blendFactor = clamp(adaptationSpeed * 0.1, 0.0, 1.0);
    float smoothedExposure = mix(previousExposure, targetExposure, blendFactor);
    
    return smoothedExposure;
}

vec3 ApplyExposure(vec3 color, float exposure) {
    return color * exposure;
}