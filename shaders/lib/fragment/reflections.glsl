#ifndef REFLECTIONS_GLSL
#define REFLECTIONS_GLSL

// Specular reflection helpers for the integrated-PBR pass (d7b_reflections).
// Architecture:
// VNDF importance-sampled rays, screen-space march, reflecting the PREVIOUS
// frame (colortex5) reprojected so the source is already clean.

// ---- BRDF -----------------------------------------------------------------

vec3 fresnelSchlick(float cosTheta, vec3 f0) {
    float m = clamp(1.0 - cosTheta, 0.0, 1.0);
    return f0 + (1.0 - f0) * (m * m * m * m * m);
}

// Height-correlated Smith GGX visibility terms.
float smithGGX_v1(float NoV, float alphaSq) {
    return 1.0 / (NoV + sqrt((NoV - NoV * alphaSq) * NoV + alphaSq));
}
float smithGGX_v2(float NoL, float NoV, float alphaSq) {
    float ggxV = NoL * sqrt((NoV - NoV * alphaSq) * NoV + alphaSq);
    float ggxL = NoV * sqrt((NoL - NoL * alphaSq) * NoL + alphaSq);
    return 0.5 / max(ggxV + ggxL, 1e-6);
}

// GGX VNDF importance sampling (zombye 2023). viewDir and the
// returned microfacet normal are in TANGENT space. roughness = alpha.
vec3 sampleGGXVNDF(vec3 viewDir, float alpha, vec2 hash) {
    viewDir = normalize(vec3(alpha * viewDir.xy, viewDir.z));

    const float tau = 6.2831853;
    float phi = tau * hash.x;
    float cosTheta = (1.0 - hash.y) * (1.0 + viewDir.z) - viewDir.z;
    float sinTheta = sqrt(clamp(1.0 - cosTheta * cosTheta, 0.0, 1.0));
    vec3 reflected = vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);

    vec3 halfway = reflected + viewDir;
    return normalize(vec3(alpha * halfway.xy, halfway.z));
}

// Arbitrary orthonormal tangent frame from a normal (columns T, B, N).
mat3 tbnFromNormal(vec3 N) {
    vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(up, N));
    vec3 B = cross(N, T);
    return mat3(T, B, N);
}

// ---- Screen-space march ---------------------------------------------------

vec3 refl_viewToScreen(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    return (clip.xyz / clip.w) * 0.5 + 0.5; // xy = screen uv, z = window depth
}

// Marches the opaque depth buffer in LOGICAL screen uv (renderScale-aware, same
// convention as c_water's waterReflectSSR). On hit returns the hit's logical uv.
bool traceReflectionSSR(vec3 viewOrigin, vec3 viewDir, float dither, out vec2 hitUV) {
    if (viewDir.z > 0.0 && viewDir.z >= -viewOrigin.z) return false;

    vec3 screenPos = refl_viewToScreen(viewOrigin);
    vec3 screenDir = normalize(refl_viewToScreen(viewOrigin + viewDir) - screenPos);

    vec2 tEdge;
    tEdge.x = (screenDir.x > 0.0) ? (1.0 - screenPos.x) : screenPos.x;
    tEdge.y = (screenDir.y > 0.0) ? (1.0 - screenPos.y) : screenPos.y;
    tEdge /= max(abs(screenDir.xy), vec2(1e-6));
    float rayLen = min(tEdge.x, tEdge.y);

    vec3  rayStep  = screenDir * (rayLen / float(REFLECTION_STEPS));
    vec2  viewSize = vec2(viewWidth, viewHeight) * renderScale;
    float depthTol = max(abs(rayStep.z) * 3.0, 0.02 / max(1.0, viewOrigin.z * viewOrigin.z));

    vec3 rayPos = screenPos + rayStep * (1.0 + dither);

    for (int i = 0; i < REFLECTION_STEPS; i++, rayPos += rayStep) {
        if (clamp(rayPos.xy, 0.0, 1.0) != rayPos.xy) break;

        float sceneDepth = texelFetch(depthtex1, ivec2(rayPos.xy * viewSize), 0).r;
        if (sceneDepth < rayPos.z && (rayPos.z - sceneDepth) < depthTol) {
            if (sceneDepth >= 1.0) break; // hit sky -> caller uses sky fallback

            vec3 p = rayPos, st = rayStep;
            for (int j = 0; j < REFLECTION_REFINE_STEPS; j++) {
                st *= 0.5;
                float d = texelFetch(depthtex1, ivec2(p.xy * viewSize), 0).r;
                p += (d < p.z) ? -st : st;
            }
            hitUV = p.xy;
            return true;
        }
    }
    return false;
}

#endif
