uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

vec3 convertScreenSpaceToWorldSpace(vec2 co, float depth) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, depth) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;
    return fragposition.xyz;
}

vec4 getFragPosition() {
    vec4 fragPosition = gbufferProjectionInverse * vec4(clipSpace, 1.0);
    fragPosition.xyz /= fragPosition.w;

    return fragPosition;
}

vec4 getWorldPosition() {
    vec4 fragPosition = getFragPosition();
    vec4 worldPosition = gbufferModelViewInverse * vec4(fragPosition.xyz, 1.0);

    return worldPosition;
}

vec4 toShadowSpace() {

    vec4 worldPosition = getWorldPosition();
    worldPosition = shadowModelView * worldPosition;
    worldPosition = shadowProjection * worldPosition;
    worldPosition /= worldPosition.w;

    float distb = sqrt(worldPosition.x * worldPosition.x + worldPosition.y * worldPosition.y);
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;

    worldPosition.xy *= 1.0 / distortFactor; 
	worldPosition = worldPosition * 0.5 + 0.5;

    return worldPosition;
}