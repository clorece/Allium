float CloudSizeMultiplier = CUMULUS_CLOUD_SIZE_MULT;

float CalculateCloudDetail(vec3 position, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float totalAmplitude = 0.0;
    float detailAccumulator = 0.0;

    vec3 currentPos = position;

    #ifndef LQ_CLOUD
        const int detailSamples = 3;
    #else
        const int detailSamples = 1;
    #endif

    for (int i = 0; i < detailSamples; ++i) {
        vec3 windOffset = GlobalWindDirection * CalculateWindSpeed() * 0.1 * float(i);
        float noiseValue = Noise3D(currentPos * (4.5 + float(i) * 1.5) / CloudSizeMultiplier + offset * 1.5 + windOffset);
        detailAccumulator += noiseValue * amplitude;
        totalAmplitude += amplitude;
        amplitude *= persistence;
        currentPos *= 3.0;
    }

    return detailAccumulator / totalAmplitude;
}

float GetCumulusCloud(vec3 position, int stepCount, int baseAltitude, float distXZ, float curvedY, float persistence, float densityMult, float sizeMod) {
    vec3 tracePosM = position * (0.00018 * sizeMod);

    vec3 offset = CalculateWindOffset(CalculateWindSpeed() * sizeMod);
    offset *= 1.0;

    float baseNoise = Noise3D(tracePosM * 0.75 / CloudSizeMultiplier + offset + GlobalWindDirection * CalculateWindSpeed() * 0.05) * 12.0;
    baseNoise += Noise3D(tracePosM * 1.0 / CloudSizeMultiplier + offset + GlobalWindDirection * CalculateWindSpeed() * 0.05) * 6.0;
    baseNoise /= 12.0 / CUMULUS_CLOUD_COVERAGE;
    baseNoise += rainFactor * 0.75;
    baseNoise -= nightFactor * 0.2;

    float detailNoise = CalculateCloudDetail(tracePosM, offset, persistence);

    float combinedDensity = mix(baseNoise, baseNoise * detailNoise, 0.4);
    combinedDensity = max(combinedDensity - 0.2, 0.0);
    combinedDensity = pow(combinedDensity, 1.35) * densityMult;

    dayWeatherCycle();
    float coverageMap = SampleCloudMap(tracePosM * 5.0 + offset * 2.0) * dailyCoverage;
    coverageMap = smoothstep(0.1, 0.5, coverageMap);

    float fadeTop = smoothstep(0.0, cumulusLayerStretch, (float(baseAltitude) + cumulusLayerStretch) - curvedY);
    float fadeBottom = smoothstep(cumulusLayerStretch * 0.85, cumulusLayerStretch, curvedY - (float(baseAltitude) - cumulusLayerStretch));
    
    float verticalFade = fadeTop * fadeBottom;

    return combinedDensity * verticalFade;
}