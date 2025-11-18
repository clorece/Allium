float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * farMinusNear);
}

float GetInverseLinearDepth(float linearDepth) {
    return (far + near - (2.0 * near) / linearDepth) / (far - near);
}

vec3 toLinear(vec3 sRGB) {
    return mix(
        sRGB / 12.92,
        pow((sRGB + 0.055) / 1.055, vec3(2.4)),
        step(0.04045, sRGB)
    );
}

// Convert from linear to sRGB space
vec3 toSRGB(vec3 linear) {
    return mix(
        linear * 12.92,
        1.055 * pow(linear, vec3(1.0 / 2.4)) - 0.055,
        step(0.0031308, linear)
    );
}
