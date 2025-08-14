float middleLayerCloudSizeMult = 1.0;

float GetCumulusDetail(vec3 pos, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float total = 0.0;
    float detail = 0.0;

    vec3 p = pos;
    const int detailSamples = 3;

    for (int i = 0; i < detailSamples; ++i) {
        vec3 windOffset = windDir * GetWind() * 0.1 * float(i);
        float n = Noise3D2(p * (6.5 + float(i) * 1.5) / middleLayerCloudSizeMult + offset * 1.5 + windOffset);
        detail += n * amplitude;
        total += amplitude;
        amplitude *= persistence;
        p *= 4.0; // scale for next octave
    }

    return detail / total;
}

float GetCumulusCloud(vec3 tracePos, int steps, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY,
                           float noisePersistence, float mult, float size) {
    vec3 tracePosM = shearMatrix * tracePos * (0.00018 * size);
    //tracePosM.y *= 1.0;
    float shearAmount = 0.6; // adjust to control wind distortion
    tracePosM.y *= shearAmount;
    tracePosM.x -= tracePosM.y * windDir.x * shearAmount;
    //tracePosM.z -= tracePosM.y * windDir.z * shearAmount;

    vec3 offset = Offset(GetWind() * size);
    offset *= 1.0;

    float base = Noise3D(tracePosM * 0.3 / middleLayerCloudSizeMult + offset + windDir * GetWind() * 0.05) * 12.0;
    //base += Noise3D(tracePosM * 1.0 / lowerLayerCloudSizeMult + offset + windDir * GetWind() * 0.05) * 5.0;
    base /= 4.0 / CUMULONIMBUS_COVERAGE;
    base -= nightFactor * 0.25;
    base += rainFactor * 0.7;

    float detail = GetCumulusDetail(tracePosM, offset, noisePersistence);

    float combined = mix(base, base * detail, 0.85);
    combined = max(combined - 0.2, 0.0);
    combined = pow(combined, 1.35) * mult * 1.5;

    float fadeTop    = smoothstep(0.0, cumulusCloudStretch, cloudAltitude + cumulusCloudStretch - tracePos.y);
    float fadeBottom = smoothstep(cumulusCloudStretch * 0.85, cumulusCloudStretch, tracePos.y - (cloudAltitude - cumulusCloudStretch));
    float verticalFade = fadeTop * fadeBottom;

    return combined * verticalFade;
}