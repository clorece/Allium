float GetAltocumulusDetail(vec3 pos, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float total = 0.0;
    float detail = 0.0;

    vec3 p = pos;
    const int detailSamples = 3;

    for (int i = 0; i < detailSamples; ++i) {
        vec3 windOffset = windDir * GetWind() * 0.1 * float(i);
        float n = Noise3D(p * (4.5 + float(i) * 1.5) / 2.7 + offset * 1.5 + windOffset);
        detail += n * amplitude;
        total  += amplitude;
        amplitude *= persistence;
        p *= 3.0;
    }

    return detail / total;
}

float GetAltocumulusCloud(vec3 tracePos, int steps, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY,
                          float noisePersistence, float mult, float size)
{
    vec3 tracePosM = shearMatrix * tracePos * (0.00018 * size);
    vec3 offset = Offset(GetWind() * size);
    offset *= 1.0;

    float shearAmount = 0.3;
    tracePosM.x += tracePosM.y * windDir.x * shearAmount;
    tracePosM.z += tracePosM.y * windDir.z * shearAmount;

    float base  = Noise3D(tracePosM * 0.75 / cumulusCloudSizeMult + offset + windDir * GetWind() * 0.05) * 12.0;
    base       += Noise3D(tracePosM * 2.0  / cumulusCloudSizeMult + offset + windDir * GetWind() * 0.05) * 6.0;
    base       /= 7.0 / ALTOCUMULUS_CLOUD_COVERAGE;
    base       += rainFactor * 0.7;

    float detail = GetAltocumulusDetail(tracePosM, offset, noisePersistence);

    float combined = mix(base, base * detail, 0.55);
    combined = max(combined - 0.2, 0.0);
    combined = pow(combined, 1.35) * mult;

    if (combined < 0.9) return 0.0;

    float fadeTop    = smoothstep(0.0, altocumulusLayerStretch, cloudAltitude + altocumulusLayerStretch - tracePos.y);
    float fadeBottom = smoothstep(altocumulusLayerStretch * 0.95, altocumulusLayerStretch, tracePos.y - (cloudAltitude - altocumulusLayerStretch));
    float verticalFade = fadeTop * fadeBottom;

    float groupMask = getCloudMap(tracePos * 0.0058);

    return combined * verticalFade * groupMask;
}