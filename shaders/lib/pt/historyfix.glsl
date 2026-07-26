#ifndef HISTORYFIX_GLSL
#define HISTORYFIX_GLSL

// Edge / disocclusion history reconstruction.
// ---------------------------------------------------------------------------
// Pixels that never build temporal history -- silhouette edges, convex corners,
// freshly disoccluded regions -- sit at giHist ~= 1 in the accumulated GI buffer
// and therefore display the raw 1-spp ReSTIR radiance, which reads as edge
// fireflies. A pure a-trous can't rescue them because its edge-stopping refuses
// to blur across the very edge that traps them.
//
// This is a spatial PREFILTER (run before the a-trous chain) in the general
// ReLAX/ReBLUR "history-fix" family: for a low-history pixel we pool the
// already-accumulated GI of geometrically-similar neighbours, biasing toward
// higher-confidence (longer-history) taps and damping bright outliers with a
// Karis luminance weight, then blend the pooled estimate in proportional to how
// little history the pixel has. The reconstructed value is written back to the
// history so the temporal filter and the a-trous chain both inherit it.
//
// Original implementation; the technique is the published disocclusion-fix idea
// (NVIDIA ReLAX/ReBLUR), not copied code.

#include "/lib/util/common.glsl"
#include "/lib/options.glsl"
// denoise.glsl brings luma(), getJitterRotation(); octDecodeNormal via common
#include "/lib/pt/denoise.glsl"

// 16-tap Vogel disk (unit radius), rotated per pixel/frame so residual structure
// decorrelates and the temporal + a-trous stages mop it up.
const vec2 HF_DISK[16] = vec2[16](
    vec2( 0.17678,  0.00000), vec2(-0.22584,  0.20678),
    vec2( 0.03482, -0.39374), vec2( 0.28473,  0.37107),
    vec2(-0.52130, -0.09744), vec2( 0.49330, -0.31693),
    vec2(-0.16482,  0.61570), vec2(-0.31351, -0.60866),
    vec2( 0.68458,  0.25019), vec2(-0.71252,  0.29343),
    vec2( 0.34494, -0.73299), vec2( 0.25494,  0.80854),
    vec2(-0.76627, -0.44056), vec2( 0.89859, -0.19052),
    vec2(-0.54639,  0.77955), vec2(-0.12784, -0.97591)
);

// pixCenter / pixMax are in BUFFER pixels (already inside the renderScale region).
// Returns the reconstructed GI; outFix reports the blend amount (debug/tuning).
vec3 historyFixGI(
    ivec2 pixCenter, ivec2 pixMax,
    vec3 accumGI, float histLen,
    vec3 nrm, float linDepth,
    out float outFix
) {
    // 1 when the pixel has little/no history, fading to 0 once it has converged
    // (>= HISTORYFIX_MAX_FRAMES) so settled detail is left completely untouched.
    float fixAmount = 1.0 - smoothstep(float(HISTORYFIX_MIN_FRAMES),
                                       float(HISTORYFIX_MAX_FRAMES), histLen);
    outFix = fixAmount;
    if (fixAmount < 0.02) return accumGI; // cheap path for the converged majority

    // fresher pixels reach further to find clean, settled neighbours
    float radius = mix(2.0, float(HISTORYFIX_RADIUS), fixAmount);
    float ang = getJitterRotation(vec2(pixCenter) * texelSize, frameCounter);
    mat2 rot = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));

    float depthTol = max(linDepth, 1.0) * HISTORYFIX_DEPTH_TOL;

    // seed with a small self-weight (Karis) so a lone valid pixel keeps itself
    float wSelf = (1.0 / (1.0 + luma(accumGI))) * 0.5;
    vec3  sum  = accumGI * wSelf;
    float wsum = wSelf;

    for (int i = 0; i < HISTORYFIX_SAMPLES; i++) {
        vec2  off = rot * (HF_DISK[i] * radius);
        ivec2 q   = clamp(pixCenter + ivec2(round(off)), ivec2(0), pixMax);

        vec4  n15    = texelFetch(colortex15, q, 0);
        float nDepth = n15.z;
        if (nDepth >= far * 0.999) continue; // skip sky taps

        vec3  nN = octDecodeNormal(n15.xy);
        vec4  n8 = texelFetch(colortex8, q, 0);

        float wN = pow(max(dot(nrm, nN), 0.0), float(HISTORYFIX_SIGMA_N)); // same surface
        float wZ = exp(-abs(nDepth - linDepth) / depthTol);                // same plane
        float wH = n8.a + 1.0;                  // borrow from converged neighbours
        float wF = 1.0 / (1.0 + luma(n8.rgb));  // Karis: damp bright outliers
        float w  = wN * wZ * wH * wF;

        sum  += n8.rgb * w;
        wsum += w;
    }

    if (wsum < 1e-5) return accumGI;
    vec3 pooled = sum / wsum;
    return mix(accumGI, pooled, fixAmount);
}

#endif
