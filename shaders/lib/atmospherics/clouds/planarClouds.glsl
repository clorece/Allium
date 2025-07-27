/*#include "/lib/colors/skyColors.glsl"

// 4-layer FBM for soft, cloudy appearance
float GetCloudNoise(vec2 pos) {
    vec2 uv = fract(pos); // wrap to [0,1] for tiling
    return texture(noisetex, uv).r; // assumes grayscale in red channel
}

// Uses sphereness for a flat-projected but curved layer
vec2 GetCloudCoord(vec3 viewPos, float sphereness) {
    vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos * 1000.0, 1.0)).xyz);
    vec3 flatCoord = wpos / (wpos.y + length(wpos.xz) * sphereness);
    flatCoord.x += 0.001 * syncedTime;
    return flatCoord.xz;
}

// Final cloud layer function (replaces GetStars)
vec3 GetPlanarClouds(vec2 cloudCoord, float VdotU, float VdotS) {
    if (VdotU < 0.0) return vec3(0.0); // skip when view is below horizon

    vec2 uv = cloudCoord * 0.1;
    uv.x += 0.0001 * syncedTime; // scrolling

    float noise = GetCloudNoise(uv);
    noise += GetCloudNoise(uv * 2.2) * 0.66;
    noise += GetCloudNoise(uv * 4.4) * 0.33;
    noise += GetCloudNoise(uv * 8.8) * 0.1;
    noise *= 0.5;
    noise = smoothstep(0.4, 0.75, noise); // smooth edges

    float fade = clamp(VdotU * 1.5, 0.0, 1.0);
    float alpha = noise * fade;

    vec3 baseColor = mix(vec3(0.7, 0.75, 0.8), vec3(1.0), noise);
    alpha *= invRainFactor;
    alpha *= 0.5 + 0.5 * pow(invNoonFactor2, 0.3); // brighten at dawn/dusk

    return baseColor * alpha * 2.5;
}*/