#ifndef CLOUD_SHADOWS_LIB
#define CLOUD_SHADOWS_LIB

#include "/lib/atmospherics/clouds/cloudCoord.glsl"
#include "/lib/atmospherics/clouds/mainClouds.glsl"


float GetNoiseCloudShadow(vec3 pos) {
    vec3 worldPos = pos + cameraPosition;
    
    // Use the same scale as GetCumulusCloud
    float sizeMod = CUMULUS_CLOUD_SIZE_MULT_M;
    vec3 tracePosM = worldPos * (0.00018 * sizeMod);
    
    // Fix Y to the cloud layer altitude to get a consistent 2D slice
    tracePosM.y = (float(cumulusLayerAlt) + cumulusLayerHeight * 0.5) * (0.00018 * sizeMod);

    float windSpeed = CalculateWindSpeed();
    vec3 offset = CalculateWindOffset(windSpeed * sizeMod);
    offset *= 1.0;

    // Base Noise (Two octaves of Noise3D, similar to cumulus.glsl)
    // We use CUMULUS_CLOUD_SIZE_MULT instead of CloudSizeMultiplier variable
    float baseNoise = Noise3D(tracePosM * 0.75 / CUMULUS_CLOUD_SIZE_MULT + offset + GlobalWindDirection * windSpeed * 0.05) * 12.0;
    baseNoise += Noise3D(tracePosM * 1.0 / CUMULUS_CLOUD_SIZE_MULT + offset + GlobalWindDirection * windSpeed * 0.05) * 6.0;
    
    baseNoise /= 5.0 / CUMULUS_CLOUD_COVERAGE;
    baseNoise -= rainFactor * 0.75;
    // baseNoise -= nightFactor * 0.2; // Optional: match cumulus.glsl if desired

    // Simplify detail noise: skip the loop, just use baseNoise
    // Or we could add a single simple detail sample if needed, but "no loops" preferred.
    // For shadows, base shape is usually sufficient.
    
    float combinedDensity = baseNoise; 
    
    // Apply density thresholding
    combinedDensity = max(combinedDensity - 0.2, 0.0);
    combinedDensity = pow(combinedDensity, 1.35) * CUMULUS_CLOUD_MULT;

    // Update weather coverage
    dayWeatherCycle();
    
    float coverageMap = SampleCloudMap(tracePosM * 5.0 + offset * 2.0) * dailyCoverage;
    coverageMap = smoothstep(0.1, 0.5, coverageMap);
    
    // Combine coverage
    // Note: verticalFade is omitted for 2D map
    float finalDensity = combinedDensity * coverageMap;
    
    // Invert density for shadow map (1.0 = lit, 0.0 = shadow)
    return clamp(finalDensity * 0.8, 0.0, 1.0);
}

float SampleCloudShadowMap(vec3 playerPos) {
    return GetNoiseCloudShadow(playerPos);
}

#endif
