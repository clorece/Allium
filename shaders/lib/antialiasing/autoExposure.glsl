#define AUTO_EXPOSURE_SPEED 0.5      
#define AUTO_EXPOSURE_MIN 0.4      
#define AUTO_EXPOSURE_MAX 6.0        
#define AUTO_EXPOSURE_TARGET 0.18    // default is 0.25
#define AUTO_EXPOSURE_BIAS 0.0       // [-1.0, 1.0]
#define AUTO_EXPOSURE_THRESHOLD 50.0 

// Metering modes
#define METERING_MODE 1              // [0 1 2] 0=Average, 1=Center-Weighted, 2=Spot

float CalculateExposure(float avgLuminance) {
    float exposure = AUTO_EXPOSURE_TARGET / avgLuminance;
    exposure *= exp2(AUTO_EXPOSURE_BIAS);
    exposure = clamp(exposure, AUTO_EXPOSURE_MIN, AUTO_EXPOSURE_MAX);
    
    return exposure;
}

float GetSceneLuminanceHistogram(sampler2D colorTex, float dither) {
        float totalLuminance = 0.0;
        float totalWeight = 0.0;
        
        const int samples = 6;
        for (int x = 0; x < samples; x++) {
            for (int y = 0; y < samples; y++) {
                vec2 offset = (vec2(float(x), float(y)) + 0.5) / float(samples);
                offset += (dither - 0.5) / float(samples);
                
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