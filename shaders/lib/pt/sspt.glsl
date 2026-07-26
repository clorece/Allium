#ifndef SSPT_GLSL
#define SSPT_GLSL

// Screen-space path tracing core (Phase 1).
//
// Provides the ray-march + hemisphere sampling primitives used by the SSPT GI
// producer (and by the SSPT_DEBUG visualiser in d7_composite). Everything works
// in VIEW space for the ray, projecting to screen with the UNJITTERED
// gbufferProjection. The opaque geometry in the depth buffer is stored JITTERED
// (gbuffers add getTaaJitter() in clip space), so depth taps are offset by the
// per-frame jitter delta `cj` (= jitteredTexCoord - unjitteredTexCoord). Hit UVs
// are returned in UNJITTERED logical space; the caller re-applies `cj` when it
// samples the (jitter-stored) radiance buffer colortex5.

#include "/lib/options.glsl"
#include "/lib/pt/rand.glsl"

// View position -> screen. Returns xy = logical uv [0,1], z = window depth [0,1].
vec3 sspt_project(mat4 proj, vec3 viewPos) {
    vec4 clip = proj * vec4(viewPos, 1.0);
    return (clip.xyz / clip.w) * 0.5 + 0.5;
}

// Orthonormal tangent frame (columns T, B, N) around a view-space normal.
mat3 sspt_tbn(vec3 N) {
    vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(up, N));
    vec3 B = cross(N, T);
    return mat3(T, B, N);
}

// Cosine-weighted hemisphere sample around view-space normal N (Malley's method).
// White-noise driver — used for the SSPT_DEBUG view and as the SSPT_BLUE_NOISE
// fallback.
vec3 sspt_dbgHemisphere(vec3 N, float u1, float u2) {
    float r   = sqrt(u1);
    float phi = 6.2831853 * u2;
    vec3  local = vec3(r * cos(phi), r * sin(phi), sqrt(max(0.0, 1.0 - u1)));
    return normalize(sspt_tbn(N) * local);
}

#ifdef SSPT_BLUE_NOISE
// NVIDIA spatiotemporal blue noise (cosine hemisphere): 128x128 spatial tile x 64
// temporal slices, RGB = a cosine-weighted direction in the +Z hemisphere. Much
// less 1-spp boiling than white noise. `slice` advances per sample+frame so a
// multi-sample pixel keeps walking the STBN sequence instead of reusing one dir.
uniform sampler3D blueNoise;

vec3 sspt_stbnHemisphere(vec3 N, ivec2 pixel, int slice) {
    ivec3 c = ivec3(pixel & 127, slice & 63);
    vec3  local = texelFetch(blueNoise, c, 0).rgb * 2.0 - 1.0;
    return normalize(sspt_tbn(N) * local);
}
#endif

// Window depth [0,1] -> view-space Z (negative, in front of camera) using the two
// projection constants. Linearising the compare is what keeps occluder thickness
// consistent from near to far (a raw window-depth band is razor-thin at range and
// huge up close -> the warped, distance-dependent shadows).
float sspt_viewZ(float windowDepth, float P22, float P32) {
    return P32 / (-(windowDepth * 2.0 - 1.0) - P22);
}

// Dense DDA: see the function body comments. Marches a view-space ray against
// `depthtex` at a fixed fine pixel stride (SSPT_STRIDE) so nothing between samples is
// skipped (kills the stepping/stripe banding), tests occlusion in view-space Z on a
// genuine front->behind crossing, and binary-refines the hit. Depth is tapped at the
// jittered texel (uv + cj); returns the unjittered hit uv + scene window depth, or
// false on an off-screen / all-sky miss.
bool traceScreenSpace(
    sampler2D depthtex,
    mat4 proj,
    vec3 originV,
    vec3 dirV,
    float maxDist,
    int steps,
    float thickness,
    float dither,
    vec2 cj,
    out vec2 hitUV,
    out float rawDepth
) {
    hitUV = vec2(0.0);
    rawDepth = 1.0;

    dirV = normalize(dirV);

    vec2  viewSize = vec2(viewWidth, viewHeight) * renderScale;
    float P22 = proj[2][2];
    float P32 = proj[3][2];

    // March in VIEW space (the proven getInfiniteShadows pattern), projecting each step
    // to screen. rayPos.z is the exact ray view-Z; the scene view-Z is reconstructed
    // from the sampled depth. A hit = the ray is BEHIND a sampled surface within an
    // occluder thickness (scaled to the step length so a surface crossed within a single
    // step still registers). Simple, robust — matches the pack's working contact-shadow
    // marcher instead of a screen-space DDA that fought the projection.
    float stepLen    = maxDist / float(steps);
    vec3  stepVec    = dirV * stepLen;
    float thickWorld = max(thickness, stepLen * 2.0);

    vec3 rayPos = originV + stepVec * (0.5 + dither);

    for (int i = 0; i < steps; i++, rayPos += stepVec) {
        if (rayPos.z > -0.05) return false; // reached the near plane

        vec4 clip = proj * vec4(rayPos, 1.0);
        vec2 uv   = (clip.xy / clip.w) * 0.5 + 0.5;
        if (clamp(uv, 0.0, 1.0) != uv) return false; // left the screen

        float scene = texelFetch(depthtex, ivec2((uv + cj) * viewSize), 0).r;
        if (scene >= 1.0) continue; // sky texel: keep marching

        float sceneZ = sspt_viewZ(scene, P22, P32);
        float zDiff  = sceneZ - rayPos.z; // > 0 when the ray is BEHIND the surface

        if (zDiff > 0.02 && zDiff < thickWorld) {
            // Refine the crossing in view space between the last two positions.
            vec3 rp = rayPos, sv = stepVec;
            for (int j = 0; j < SSPT_REFINE; j++) {
                sv *= 0.5;
                vec4  c  = proj * vec4(rp, 1.0);
                vec2  u  = (c.xy / c.w) * 0.5 + 0.5;
                float d  = texelFetch(depthtex, ivec2((u + cj) * viewSize), 0).r;
                float dz = sspt_viewZ(d, P22, P32) - rp.z;
                rp += (dz > 0.0) ? -sv : sv; // behind -> step back toward the surface
            }
            vec4 hc = proj * vec4(rp, 1.0);
            hitUV    = (hc.xy / hc.w) * 0.5 + 0.5;
            rawDepth = texelFetch(depthtex, ivec2((hitUV + cj) * viewSize), 0).r;
            return true;
        }
    }
    return false;
}

#endif
