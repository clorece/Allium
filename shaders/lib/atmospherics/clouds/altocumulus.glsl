float CloudSizeMultiplier = CUMULUS_CLOUD_SIZE_MULT;

float GetCumulusCloud(vec3 position, int stepCount, int baseAltitude, float distXZ, float curvedY, float persistence, float densityMult, float sizeMod) {
    vec3 tracePosM = position * (0.00012 * sizeMod);
    
    float wind = 0.0006;
    #if CLOUD_SPEED_MULT == 100
        wind *= syncedTime;
    #else
        wind *= frameTimeCounter * CLOUD_SPEED_MULT * 0.01;
    #endif

    float noise = 0.0;
    float currentPersist = 1.0;
    float total = 0.0;
    
    #ifndef LQ_CLOUD
        const int sampleCount = 4;
        float noiseMult = 1.07;
    #else
        const int sampleCount = 2;
        float noiseMult = 0.95;
        tracePosM *= 0.5;
        wind *= 0.5;
    #endif
    
    for (int i = 0; i < sampleCount; i++) {
        noise += Noise3D(tracePosM + vec3(wind, 0.0, 0.0)) * currentPersist;
        total += currentPersist;
        
        tracePosM *= 3.0;
        wind *= 0.5;
        currentPersist *= persistence;
    }
    noise = pow2(noise / total);
    
    float cloudPlayerPosY = curvedY - float(baseAltitude);
    float cloudTallness = cumulusLayerStretch * 2.0;
    
    noiseMult *= 0.8 + 0.1 * clamp01(-cloudPlayerPosY / cloudTallness) + 0.4 * rainFactor;
    
    noise *= noiseMult * CUMULUS_CLOUD_COVERAGE;
    
    float threshold = clamp(abs(float(baseAltitude) - curvedY) / cumulusLayerStretch, 0.001, 0.999);
    threshold = pow2(pow2(pow2(threshold)));
    
    return max(noise - (threshold * 0.2 + 0.25), 0.0) * densityMult;
}