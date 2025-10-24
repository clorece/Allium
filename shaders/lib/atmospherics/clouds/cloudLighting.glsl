vec2 GetPowder(float density) {
    float powder = 1.0 - exp2(-density * 2.0 * 1.442695041);
    return vec2(0.6 + 0.4 * powder, 0.5 + 0.5 * powder);
}

float SampleCloudAO(vec3 tracePos, int cloudAltitude, float stretch, float size, float dither, int layer) {
    #ifdef LQ_CLOUD
        return 1.0;
    #endif
    
    float ao = 0.0;
    const vec3 aoDirections[6] = vec3[6](
        vec3(1.0, 0.0, 0.0),
        vec3(-1.0, 0.0, 0.0),
        vec3(0.0, 1.0, 0.0),
        vec3(0.0, -1.0, 0.0),
        vec3(0.0, 0.0, 1.0),
        vec3(0.0, 0.0, -1.0)
    );
    
    float aoRadius = stretch;
    int samples = CLOUD_AO_SAMPLES;
    
    for (int i = 0; i < samples; ++i) {
        vec3 sampleDir = aoDirections[i % 6];
        vec3 samplePos = tracePos + sampleDir * aoRadius * (1.0 + dither * 0.5);
        
        float dxAO = length((samplePos - cameraPosition).xz);
        float yAO = samplePos.y + curvatureDrop(dxAO);
        
        if (abs(yAO - float(cloudAltitude)) > stretch * 2.0) continue;

        float density;

        if (layer == 1) {
            // nothing yet...
        } else if (layer == 2) {
            density = GetCumulusCloud(samplePos, 1, cloudAltitude,
                                        dxAO, yAO - float(cloudAltitude),
                                        CUMULUS_CLOUD_GRANULARITY, 1.0, size);
        } else if (layer == 3) {
            density = GetAltocumulusCloud(samplePos, 1, cloudAltitude,
                                        dxAO, yAO - float(cloudAltitude),
                                        ALTOCUMULUS_CLOUD_GRANULARITY, 1.0, size);
        }
        if (density < 0.005) break;
        ao += density;
    }
    
    ao = ao / float(samples);
    return 1.0 - (ao * CLOUD_AO_STRENGTH);
}

vec3 GetMultiscatter(float density, float lightTrans, vec3 lightColor, float mu) {
    #ifdef LQ_CLOUD
        return vec3(0.0);
    #endif
    
    vec3 multiScatter = vec3(0.0);
    float scatterStrength = CLOUD_MULTISCATTER;
    
    for (int i = 0; i < CLOUD_MULTISCATTER_OCTAVES; ++i) {
        float octaveFactor = pow(0.5, float(i + 1));
        float phaseMod = mix(0.3, 0.8, float(i) / float(CLOUD_MULTISCATTER_OCTAVES));
        
        float scatter = density * lightTrans * octaveFactor;
        scatter *= (1.0 - abs(mu) * 0.3);
        
        multiScatter += lightColor * scatter * scatterStrength * phaseMod;
    }
    
    return multiScatter;
}

float SampleCloudShadow(vec3 tracePos, vec3 lightDir, float dither, int steps, int cloudAltitude, float stretch, float size, int layer) {
    float shadow = 0.0;
    float density = 0.0;
    vec3 samplePos = tracePos;

    const float shadowDensityScale = 1.0;

    for (int i = 0; i < steps; ++i) {
        samplePos += lightDir * 24.0 + dither * i;
        
        float dxShadow = length((samplePos - cameraPosition).xz);
        float yCurvedS = samplePos.y + curvatureDrop(dxShadow);
        if (abs(yCurvedS - float(cloudAltitude)) > stretch * 3.0) break;

        float density;

        if (layer == 1) {
            // nothing yet...
        } else if (layer == 2) {
            density = clamp(GetCumulusCloud(samplePos, steps, cloudAltitude,
                                              dxShadow, yCurvedS - float(cloudAltitude),
                                              CUMULUS_CLOUD_GRANULARITY, 1.0, size), 0.0, 1.0);
        } else if (layer == 3) {
            density = clamp(GetAltocumulusCloud(samplePos, steps, cloudAltitude,
                                              dxShadow, yCurvedS - float(cloudAltitude),
                                              ALTOCUMULUS_CLOUD_GRANULARITY, 1.0, size), 0.0, 1.0);
        }
        if (density < 0.1) break;

        density *= shadowDensityScale;
        shadow += density / float(i + 1);
    }

    return clamp(shadow / float(steps), 0.0, 1.0);
}