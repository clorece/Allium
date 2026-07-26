#ifndef SHARPEN_GLSL
#define SHARPEN_GLSL

#include "/lib/util/common.glsl"

float sharpenLuma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}
vec3 sharpenTonemap(vec3 c)  { return c / (1.0 + sharpenLuma(c)); }
vec3 sharpenInverse(vec3 c)  { return c / max(1.0 - sharpenLuma(c), 1e-4); }

vec3 casSharpen(sampler2D tex, vec2 uv, vec2 texSize, float sharpness) {
    sharpness = clamp(sharpness, 0.0, 1.0);
    if (sharpness <= 0.0) return texture(tex, uv).rgb;

    vec2 px = 1.0 / texSize;

    // Cross neighbourhood (b=up, g=down, d=left, f=right) + centre e, tonemapped.
    vec3 e = sharpenTonemap(texture(tex, uv).rgb);
    vec3 b = sharpenTonemap(texture(tex, uv + vec2(0.0, -px.y)).rgb);
    vec3 g = sharpenTonemap(texture(tex, uv + vec2(0.0,  px.y)).rgb);
    vec3 d = sharpenTonemap(texture(tex, uv + vec2(-px.x, 0.0)).rgb);
    vec3 f = sharpenTonemap(texture(tex, uv + vec2( px.x, 0.0)).rgb);

    vec3 mn = min(min(min(b, g), min(d, f)), e);
    vec3 mx = max(max(max(b, g), max(d, f)), e);

    vec3 amp = sqrt(clamp(min(mn, 1.0 - mx) / max(mx, 1e-4), 0.0, 1.0));

    float peak = mix(8.0, 5.0, sharpness);
    vec3 w = amp * (-1.0 / peak);

    vec3 res = (e + w * (b + g + d + f)) / (1.0 + 4.0 * w);
        res = clamp(res, mn, mx);

    return sharpenInverse(max(res, 0.0));
}

#endif
