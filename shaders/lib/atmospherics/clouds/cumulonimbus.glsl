float lowerLayerCloudSizeMult = 2.0;

float GetCumulonimbusDetail(vec3 pos, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float total = 0.0;
    float detail = 0.0;

    vec3 p = pos;
    const int detailSamples = 4;

    for (int i = 0; i < detailSamples; ++i) {
        vec3 windOffset = windDir * GetWind() * 0.1 * float(i);
        float n = Noise3D(p * (6.5 + float(i) * 1.5) / lowerLayerCloudSizeMult + offset * 1.5 + windOffset);
        detail += n * amplitude;
        total += amplitude;
        amplitude *= persistence;
        p *= 4.0; // scale for next octave
    }

    return detail / total;
}

float GetCumulonimbusCloud(vec3 tracePos, int steps, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY,
                           float noisePersistence, float mult, float size) {
    vec3 tracePosM = shearMatrix * tracePos * (0.00018 * size);

    float shearAmount = 0.6; // adjust to control wind distortion
    //tracePosM.y *= shearAmount;
    tracePosM.x += tracePosM.y * windDir.x * shearAmount;
    //tracePosM.z += tracePosM.y * windDir.z * shearAmount;

    vec3 offset = Offset(GetWind() * size);
    offset *= 1.0;

    float base = Noise3D(tracePosM * 0.75 / lowerLayerCloudSizeMult + offset) * 12.0;
    base += Noise3D(tracePosM * 1.75  / lowerLayerCloudSizeMult + offset) * 6.0;
    base /= 9.0 / CUMULONIMBUS_COVERAGE;
    base += rainFactor * 0.7;
    base -= nightFactor * 0.15;

    float detail = GetCumulonimbusDetail(tracePosM, offset, noisePersistence);

    float combined = mix(base, base * detail, 0.45);
    combined = max(combined - 0.2, 0.0);
    combined = pow(combined, 1.35) * mult;

    float fadeTop    = smoothstep(0.0, cumulonimbusCloudStretch, cloudAltitude + cumulonimbusCloudStretch - tracePos.y);
    float fadeBottom = smoothstep(cumulonimbusCloudStretch * 0.65, cumulonimbusCloudStretch, tracePos.y - (cloudAltitude - cumulonimbusCloudStretch));
    float verticalFade = fadeTop * fadeBottom;

    return combined * verticalFade;
}