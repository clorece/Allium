vec2 CalculatePowderEffect(float density) {
    float powderFactor = 1.0 - exp2(-density * 2.88539008);
    return vec2(0.6 + 0.4 * powderFactor, 0.5 + 0.5 * powderFactor);
}

float CalculateCloudAO(vec3 position, int baseAltitude, float layerThickness, float cloudSize, float dither, int layerID) {
    #ifdef LQ_CLOUD
        return 1.0;
    #endif
    
    float ambientOcclusion = 0.0;
    const vec3 aoOffsetDirections[6] = vec3[6](
        vec3(1.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0),
        vec3(0.0, 1.0, 0.0), vec3(0.0, -1.0, 0.0),
        vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0)
    );
    
    float aoRadius = layerThickness; 
    int sampleCount = CLOUD_AO_SAMPLES;
    
    for (int i = 0; i < sampleCount; ++i) {
        vec3 sampleDir = aoOffsetDirections[i % 6];
        vec3 samplePos = position + sampleDir * aoRadius * (1.0 + dither * 0.5);
        
        float distXZ = length((samplePos - cameraPosition).xz);
        float curvedY = samplePos.y + curvatureDrop(distXZ);
        
        if (abs(curvedY - float(baseAltitude)) > layerThickness * 2.0) continue;

        float density = 0.0;

        if (layerID == 2) {
            density = GetCumulusCloud(samplePos, 1, baseAltitude,
                                        distXZ, curvedY,
                                        CUMULUS_CLOUD_GRANULARITY, 1.0, cloudSize);
        }

        ambientOcclusion += density * 0.2;
    }
    
    ambientOcclusion = ambientOcclusion / float(sampleCount);
    return 1.0 - (ambientOcclusion * CLOUD_AO_STRENGTH);
}

vec3 CalculateMultiScattering(float density, float lightTransmittance, vec3 lightColor, float sunDotView) {
    #ifdef LQ_CLOUD
        return vec3(0.0);
    #endif
    
    vec3 multiScatterResult = vec3(0.0);
    float scatterStrength = CLOUD_MULTISCATTER;
    
    for (int i = 0; i < CLOUD_MULTISCATTER_OCTAVES; ++i) {
        float octaveFactor = pow(0.5, float(i + 1));
        float phaseMod = mix(0.3, 0.8, float(i) / float(CLOUD_MULTISCATTER_OCTAVES));
        
        float scatter = density * lightTransmittance * octaveFactor;
        scatter *= (1.0 - abs(sunDotView) * 0.3);
        
        multiScatterResult += lightColor * scatter * scatterStrength * phaseMod;
    }
    
    return multiScatterResult;
}

float CalculateCloudShadow(vec3 startPos, vec3 lightDirection, float dither, int stepCount, int baseAltitude, float layerThickness, float cloudSize, int layerID) {
    float totalShadow = 0.0;
    vec3 currentPos = startPos;
    const float shadowDensityScale = 1.0; 

    for (int i = 0; i < stepCount; ++i) {
        currentPos += lightDirection * 24.0 + dither * i;
        
        float distXZ = length((currentPos - cameraPosition).xz);
        float curvedY = currentPos.y + curvatureDrop(distXZ);
        
        if (abs(curvedY - float(baseAltitude)) > layerThickness * 3.0) break;

        float density = 0.0;

        if (layerID == 2) {
            density = clamp(GetCumulusCloud(currentPos, stepCount, baseAltitude,
                                              distXZ, curvedY, 
                                              CUMULUS_CLOUD_GRANULARITY, 1.0, cloudSize), 0.0, 1.0);
        }
        
        if (density < 0.1) break; 

        density *= shadowDensityScale;
        totalShadow += density / float(i + 1);
    }

    return clamp(totalShadow / float(stepCount), 0.0, 1.0);
}