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

vec4 toShadowSpace(float nDotL) {
    // shadowSpace from shaderLabs shadow tutorial
    vec4 worldPosition = getWorldPosition();
    vec4 shadowSpace = shadowProjection * shadowModelView * worldPosition;
    float distortFactor = getDistortFactor(shadowSpace.xy);
	shadowSpace.xyz = distort(shadowSpace.xyz, distortFactor); //apply shadow distortion
	shadowSpace.xyz = shadowSpace.xyz * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
	shadowSpace.z -= SHADOW_BIAS * (distortFactor * distortFactor);

    return shadowSpace;
}