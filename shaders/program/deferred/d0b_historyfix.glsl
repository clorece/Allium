// d0b_historyfix : edge / disocclusion reconstruction (spatial prefilter).
// Runs after d0_accum (temporal) and before the a-trous chain. Reads the freshly
// accumulated GI (colortex8) and, for pixels with little temporal history (edges,
// disocclusions), replaces the raw 1-spp value with a confidence- and firefly-
// weighted pool of geometrically-similar neighbours (see lib/pt/historyfix.glsl).
// The result is written back to colortex8 so the next frame's temporal filter and
// this frame's a-trous chain both inherit the reconstructed estimate. Converged
// pixels and sky pass through unchanged.
//
// Output: colortex8 = reconstructed GI (.rgb) + history length (.a, preserved)

#ifdef VERTEX

#include "/lib/options.glsl"

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;

    // TAAU: render into the bottom-left renderScale region (no-op at 1.0).
    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"
#include "/lib/util/common.glsl"
#include "/lib/pt/denoise.glsl"
#include "/lib/pt/historyfix.glsl"

in vec2 texCoord;

void main() {
    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec4  c8  = texelFetch(colortex8, pix, 0);
    vec4  ng  = texelFetch(colortex15, pix, 0);
    float linDepth = ng.z;

    vec3 outGI = c8.rgb;

    #if defined(GI_DENOISE) && (defined(VOXEL_GI) || defined(VOXEL_AO)) && defined(HISTORY_FIX)
        if (linDepth < far * 0.999 && c8.a > 0.5) {
            ivec2 pixMax = ivec2(vec2(viewWidth, viewHeight) * renderScale) - 1;
            vec3  nrm = octDecodeNormal(ng.xy);
            float fix;
            outGI = historyFixGI(pix, pixMax, c8.rgb, c8.a, nrm, linDepth, fix);
        }
    #endif

    /* RENDERTARGETS: 8 */
    gl_FragData[0] = vec4(outGI, c8.a);
}

#endif
