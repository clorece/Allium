#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 ViewToScreen(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    vec3 ndc  = clip.xyz / clip.w;
    // ndc ∈ [-1,1] → uv ∈ [0,1], depth in ndc.z also remapped
    return ndc * 0.5 + 0.5;
}

vec3 toClipSpace(vec3 viewPos) {
    return projMAD(gbufferProjection, viewPos) / -viewPos.z * 0.5 + 0.5;
}

vec3 ScreenToView(vec3 pos) {
    vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x,
                          gbufferProjectionInverse[1].y,
                          gbufferProjectionInverse[2].zw);
    vec3 p3 = pos * 2.0 - 1.0;
    vec4 viewPos = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}

vec3 ViewToPlayer(vec3 pos) {
    return mat3(gbufferModelViewInverse) * pos + gbufferModelViewInverse[3].xyz;
}

vec3 PlayerToShadow(vec3 pos) {
    vec3 shadowpos = mat3(shadowModelView) * pos + shadowModelView[3].xyz;
    return projMAD(shadowProjection, shadowpos);
}

vec3 ShadowClipToShadowView(vec3 pos) {
    return mat3(shadowProjectionInverse) * pos;
}

vec3 ShadowViewToPlayer(vec3 pos) {
    return mat3(shadowModelViewInverse) * pos;
}