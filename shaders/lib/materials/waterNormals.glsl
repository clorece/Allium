vec2 GetCombinedWaves(vec2 uv, vec2 wind) {
    uv *= 1.0;
    wind *= 0.9;
    vec2 nMed   = texture2D(gaux4, uv + 0.25 * wind).rg - 0.5;
        nMed   += texture2D(gaux4, uv * 1.25 + 0.25 * wind).rg - 0.5;
    vec2 nSmall = texture2D(gaux4, uv * 2.0 - 2.0 * wind).rg - 0.5;
        nSmall += texture2D(gaux4, uv * 3.0 - 2.0 * wind).rg - 0.5;
    vec2 nBig   = texture2D(gaux4, uv * 0.35 + 0.65 * wind).rg - 0.5;
        nBig   += texture2D(gaux4, uv * 0.55 + 0.75 * wind).rg - 0.5;

    return (nMed * WATER_BUMP_MED +
            nSmall * WATER_BUMP_SMALL +
            nBig * WATER_BUMP_BIG) * 0.3;
}