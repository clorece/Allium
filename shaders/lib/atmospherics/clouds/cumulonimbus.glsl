float GetCumulonimbusDetail(vec3 pos, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float total = 0.0;
    float detail = 0.0;

    vec3 p = pos;
    const int detailSamples = 3;

    for (int i = 0; i < detailSamples; ++i) {
        float n = Noise3D(p * (4.0 + float(i) * 1.5) + offset * 1.5);
        detail += n * amplitude;
        total += amplitude;
        amplitude *= persistence;
        p *= 3.0; // scale for next octave
    }

    return detail / total;
}

float GetCumulonimbusCloud(vec3 tracePos, int steps, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY, float noisePersistence, float mult, float size) {
    vec3 tracePosM = tracePos * (0.00018 * size);
    tracePosM.y *= 0.5;

    vec3 offset = Offset(GetWind() * size);
        offset *= 0.1;

    float base = Noise3D(tracePosM * 1.0 + offset) * 12.0;
        base += Noise3D(tracePosM * 3.0 + offset) * 6.0;
        base /= 9.0;
        base += rainFactor * 0.4;
    float detail = GetCumulonimbusDetail(tracePosM, offset, noisePersistence);

    float combined = mix(base, base * detail, 0.5);
    combined = max(combined - 0.2, 0.0);
    combined = pow(combined, 1.35) * mult;

    float fadeTop    = smoothstep(0.0, cumulonimbusCloudStretch, cloudAltitude + cumulonimbusCloudStretch - tracePos.y);
    float fadeBottom = smoothstep(cumulonimbusCloudStretch * 0.86, cumulonimbusCloudStretch, tracePos.y - (cloudAltitude - cumulonimbusCloudStretch)); // reposition lower boundary to cut off bottom of cloud to make it flatter
    float verticalFade = fadeTop * fadeBottom;
    
    return combined * verticalFade;
}