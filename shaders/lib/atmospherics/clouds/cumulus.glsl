float GetCumulusDetail(vec3 pos, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float total = 0.0;
    float detail = 0.0;

    vec3 p = pos;
    const int detailSamples = 3;

    for (int i = 0; i < detailSamples; ++i) {
        vec3 windOffset = windDir * GetWind() * 0.1 * float(i);
        float n = Noise3D(p * (4.0 + float(i) * 1.5) + offset * 1.5 + windOffset);
        detail += n * amplitude;
        total += amplitude;
        amplitude *= persistence;
        p *= 3.0; // scale for next octave
    }

    return detail / total;
}

float GetCumulusCloud(vec3 tracePos, int steps, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY, float noisePersistence, float mult, float size) {
    vec3 tracePosM = tracePos * (0.00018 * size);
    tracePosM.y *= 0.5;

    // Apply shear matrix to simulate wind distortion
    tracePosM = shearMatrix * tracePosM;

    vec3 offset = Offset(GetWind() * size);
    offset *= 2.0;

    float base = Noise3D2(tracePosM * 4.0 + offset + windDir * GetWind() * 0.05) * 12.0;
    base += Noise3D2(tracePosM * 3.0 + offset + windDir * GetWind() * 0.05) * 6.0;
    base /= 4.0 / CUMULUS_COVERAGE;

    float detail = GetCumulusDetail(tracePosM, offset, noisePersistence);

    float combined = mix(base, base * detail, 0.6);
    combined = max(combined - 0.2, 0.0);
    combined = pow(combined, 1.35) * mult;

    float y = tracePos.y;
    float fadeTop    = smoothstep(0.0, cumulusCloudStretch, cloudAltitude + cumulusCloudStretch - y);
    float fadeBottom = smoothstep(cumulusCloudStretch * 0.5, cumulusCloudStretch, y - (cloudAltitude - cumulusCloudStretch));
    float verticalFade = fadeTop * fadeBottom;

    return combined * verticalFade;
}
