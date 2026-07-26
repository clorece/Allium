// d_denoise_common : one SVGF a-trous iteration
// The including pass sets:
//     DENOISE_SRC         - colour+variance input from prev iteration
//     DENOISE_STEP        - kernel dilation for this iteration
//     DENOISE_LAST_ITER   - (optional) write to history (colortex8)
// and the .fsh wrapper picks the output via its DRAWBUFFERS comment.
// Output: .rgb = filtered irradiance, .a = filtered variance.

#ifndef DENOISE_SRC
    #error "d_denoise_common.glsl: define DENOISE_SRC"
#endif
#ifndef DENOISE_STEP
    #define DENOISE_STEP 1.0
#endif

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

in vec2 texCoord;


#ifdef DENOISE_LAST_ITER
#endif

void main() {
    vec4  ngC = texelFetch(colortex15, ivec2(gl_FragCoord.xy), 0);
    float linDepth = ngC.z;
    vec2  depthGrad = vec2(dFdx(linDepth), dFdy(linDepth));

    float pxWorld = 2.0 * gbufferProjectionInverse[1][1] * texelSize.y;

    vec4 outv = texture(DENOISE_SRC, texCoord * renderScale);
    #if defined(GI_DENOISE) && (defined(VOXEL_GI) || defined(VOXEL_AO) || defined(SSPT_GI))
        if (linDepth < far * 0.999
            #ifdef SVGF_EARLY_OUT
                && texture(colortex8, texCoord * renderScale).a <= 48.0
            #endif
        ) {
            vec3 nrm = octDecodeNormal(ngC.xy);
            #ifdef DENOISE_WIDE
                const bool centerVarOnly = true;
            #else
                const bool centerVarOnly = false;
            #endif
            outv = svgfAtrous(DENOISE_SRC, texCoord * renderScale, float(DENOISE_STEP),
                              linDepth, depthGrad, nrm, pxWorld, centerVarOnly);
        }
    #endif

    #ifdef DENOISE_LAST_ITER
        // colortex8 holds the RAW accumulated GI + history length from d0_accum.
        vec4  c8 = texture(colortex8, texCoord * renderScale);
        float histLen = c8.a;

        // Displayed result (colortex6 or colortex8 via DRAWBUFFERS)
        vec3 displayColor = outv.rgb;
        #ifdef SVGF_DETAIL_PRESERVE
            float preserve = clamp(histLen / float(SVGF_PRESERVE_FRAMES), 0.0, 1.0)
                           * (float(SVGF_PRESERVE_MAX) / 100.0);
            displayColor = mix(outv.rgb, c8.rgb, preserve);
        #endif
        gl_FragData[0] = vec4(displayColor, outv.a);

        // Temporal history feedback (colortex8)
        #ifdef SVGF_RAW_HISTORY
            // Keep the history as the RAW accumulated GI.
            gl_FragData[1] = vec4(c8.rgb, histLen);
        #else
            // Classic SVGF: spatially-filtered result is also the temporal history.
            gl_FragData[1] = vec4(outv.rgb, histLen);
        #endif
    #else
        gl_FragData[0] = outv;
    #endif
}

#endif
