float cumulusCloudSizeMult = CUMULUS_CLOUD_SIZE_MULT;

float GetCumulonimbusDetail(vec3 pos, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float total = 0.0;
    float detail = 0.0;

    vec3 p = pos;

    #ifndef LQ_CLOUD
    const int detailSamples = 3;
    #else
    const int detailSamples = 1;
    #endif


    for (int i = 0; i < detailSamples; ++i) {
        vec3 windOffset = windDir * GetWind() * 0.1 * float(i);
        float n = Noise3D(p * (4.5 + float(i) * 1.5) / cumulusCloudSizeMult + offset * 1.5 + windOffset);
        detail += n * amplitude;
        total += amplitude;
        amplitude *= persistence;
        p *= 3.0;
    }

    return detail / total;
}

float GetCumulusCloud(vec3 tracePos, int steps, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY,
                      float noisePersistence, float mult, float size) {
    vec3 tracePosM = shearMatrix * tracePos * (0.00018 * size);

    float shearAmount = 0.25;
    tracePosM.x += tracePosM.y * windDir.x * shearAmount;
    tracePosM.z += tracePosM.y * windDir.z * shearAmount;

    vec3 offset = Offset(GetWind() * size);
    offset *= 1.0;

    float base = Noise3D(tracePosM * 0.75 / cumulusCloudSizeMult + offset + windDir * GetWind() * 0.05) * 12.0;
    base += Noise3D(tracePosM * 1.0 / cumulusCloudSizeMult + offset + windDir * GetWind() * 0.05) * 6.0;
    base /= 12.0 / CUMULUS_CLOUD_COVERAGE;
    base += rainFactor * 0.7;

    float detail = GetCumulonimbusDetail(tracePosM, offset, noisePersistence);

    float combined = mix(base, base * detail, 0.55);
    combined = max(combined - 0.2, 0.0);
    combined = pow(combined, 1.35) * mult;

    float fadeTop = smoothstep(0.0, cumulusLayerStretch, cloudAltitude + cumulusLayerStretch - tracePos.y);
    float fadeBottom = smoothstep(cumulusLayerStretch * 0.7, cumulusLayerStretch, tracePos.y - (cloudAltitude - cumulusLayerStretch));
    float verticalFade = fadeTop * fadeBottom;

    return combined * verticalFade;
}