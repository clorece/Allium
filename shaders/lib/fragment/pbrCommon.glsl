#ifndef PBR_COMMON_GLSL
#define PBR_COMMON_GLSL

// Shared integrated-PBR material encoding for colortex7, used by gbuffers_terrain
// (write) and the d7b/d7c reflection passes (read).
//
//   .rgb = reflectance tint:  metal  -> raw albedo (= F0, tints the reflection)
//                             dielec -> F0 as grey (reflection stays untinted)
//   .a   = packed smoothness + metal flag:
//             0            -> non-PBR (no reflection)
//             [0.02, 0.48] -> dielectric, keep diffuse + add Fresnel reflection
//             [0.52, 0.98] -> metal, no diffuse, albedo-tinted reflection

float pbrLightness(vec3 c) {
    return 0.5 * (max(max(c.r, c.g), c.b) + min(min(c.r, c.g), c.b)); // HSL L
}

float pbrPackA(float smoothness, bool isMetal) {
    return (isMetal ? 0.52 : 0.02) + clamp(smoothness, 0.0, 1.0) * 0.46;
}
bool  pbrIsPBR(float a)      { return a > 0.01; }
bool  pbrIsMetal(float a)    { return a > 0.5; }
float pbrSmoothness(float a) { return clamp((a - (a > 0.5 ? 0.52 : 0.02)) / 0.46, 0.0, 1.0); }

vec3 pbrFresnel(float cosTheta, vec3 f0) {
    float m = clamp(1.0 - cosTheta, 0.0, 1.0);
    return f0 + (1.0 - f0) * (m * m * m * m * m);
}

// Cook-Torrance GGX specular highlight for a direct light (sun/moon). All vectors
// same space (view), normalized. Returns the highlight radiance (multiply by
// shadow outside). Shared by the integrated-PBR passes and water/glass.
vec3 ggxSpecular(vec3 N, vec3 V, vec3 L, float roughness, vec3 f0, vec3 lightColor) {
    float NoL = dot(N, L);
    if (NoL <= 0.0) return vec3(0.0);
    vec3  H   = normalize(V + L);
    float NoH = clamp(dot(N, H), 0.0, 1.0);
    float NoV = clamp(dot(N, V), 1e-4, 1.0);
    float VoH = clamp(dot(V, H), 0.0, 1.0);
    NoL = clamp(NoL, 0.0, 1.0);

    float a   = max(roughness * roughness, 2e-3); // floor widens the disc so the glint isn't a single aliased dot
    float a2  = a * a;
    float den = NoH * NoH * (a2 - 1.0) + 1.0;
    float D   = a2 / (PI * den * den);                                  // GGX NDF
    float gv  = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float gl  = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    float Vis = 0.5 / max(gv + gl, 1e-5);                               // height-correlated Smith
    vec3  F   = pbrFresnel(VoH, f0);
    return D * Vis * F * NoL * lightColor;
}

#endif
