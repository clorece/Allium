float GetAltocumulusDetail(vec3 pos, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float total = 0.0;
    float detail = 0.0;

    vec3 p = pos;
    const int detailSamples = 3;

    for (int i = 0; i < detailSamples; ++i) {
        float n = Noise3D(p * (2.0 ) + offset * 1.5);
        detail += n * amplitude;
        total += amplitude;
        amplitude *= persistence;
        p *= 6.0; // scale for next octave
    }

    return detail / total;
}

float GetAltocumulusCloud(vec3 tracePos, int steps, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY, float noisePersistence, float mult, float size) {
    vec3 tracePosM = tracePos * (0.00018 * size);
    tracePosM.y *= 0.25;

    vec3 offset = Offset(GetWind() * size);
    //    offset *= 2.0;

    tracePosM.x += sin(tracePosM.z * 1.2) * 0.35;

    float base = Noise3D(tracePosM * 0.15 + offset) * 12.0;
    //    base += Noise3D(tracePosM * 2.0 + offset) * 6.0;
        base /= 5.25 / ALTOCUMULUS_COVERAGE;
        base -= nightFactor * 0.25;
        //base += rainFactor * 1.75;

    float detail = GetAltocumulusDetail(tracePosM, offset, noisePersistence);

    float combined = mix(base, base * detail, 0.65) * 0.9;
    combined = max(combined - 0.2, 0.0);
    combined = pow(combined, 2.2) * mult * 1.3;
    //combined *= 2.0 * lTracePosXZ * 0.001;

    float fadeTop    = smoothstep(0.0, altocumulusCloudStretch, cloudAltitude + altocumulusCloudStretch - tracePos.y);
    float fadeBottom = smoothstep(altocumulusCloudStretch * 0.1, altocumulusCloudStretch, tracePos.y - (cloudAltitude - altocumulusCloudStretch));
    float verticalFade = fadeTop * fadeBottom;
    
    return combined * verticalFade;
}