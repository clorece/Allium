// d1_atrous_first : fused prefilter + first SVGF a-trous iteration (step 1).
// Reads the accumulated GI (colortex8.rgb) and the moment buffer
// (colortex9.g/.b) DIRECTLY, bootstraps variance from the real moments
// (+ spatial estimate for short histories), and runs the first 3×3 a-trous
// tap. Output: colortex3 = filtered GI (.rgb) + variance (.a).
//
// Geometry (normal + linear depth) comes from the packed colortex15 G-buffer
// written by d0_restir. The temporal history feedback is the RAW accumulated
// GI (colortex8, written by d0_accum), so no pass needs to write history back.

#ifdef VERTEX

#include "/lib/options.glsl"

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;

    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"
#include "/lib/util/common.glsl"

#include "/lib/pt/denoise.glsl"

in vec2 texCoord;

void main() {
    vec4 ngC = texelFetch(colortex15, ivec2(gl_FragCoord.xy), 0);
    float linDepth = ngC.z;
    vec2 depthGrad = vec2(dFdx(linDepth), dFdy(linDepth));

    // sky pixels store linDepth == far in the packed G-buffer
    if (linDepth >= far * 0.999) {
        /* RENDERTARGETS: 3 */
        gl_FragData[0] = vec4(0.0);
        return;
    }

    vec4 c8 = texture(colortex8, texCoord * renderScale);
    vec4 outv = vec4(c8.rgb, 0.0);
    #if defined(GI_DENOISE) && (defined(VOXEL_GI) || defined(VOXEL_AO) || defined(SSPT_GI))
        vec3 nrm = octDecodeNormal(ngC.xy);
        float pxWorld = 2.0 * gbufferProjectionInverse[1][1] * texelSize.y;
        outv = svgfAtrousFirst(texCoord * renderScale, linDepth, depthGrad, nrm, c8.a, pxWorld);
    #endif

    gl_FragData[0] = outv;
}

#endif
