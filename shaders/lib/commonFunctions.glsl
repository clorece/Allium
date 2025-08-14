float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * farMinusNear);
}

float GetInverseLinearDepth(float linearDepth) {
    return (far + near - (2.0 * near) / linearDepth) / (far - near);
}