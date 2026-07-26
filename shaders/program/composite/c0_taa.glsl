#ifdef VERTEX

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"

in vec2 texCoord;
   

#include "/lib/util/common.glsl"
#include "/lib/post/taa.glsl"

void main() {
    vec2 currentPos = texCoord / texelSize;

    #ifdef TAA
        vec4 finalColor = taa(currentPos, vec2(viewWidth, viewHeight), colortex0, colortex5);
    #else
        vec4 finalColor = texture(colortex0, min(texCoord * renderScale, vec2(renderScale) - 1.0 / vec2(viewWidth, viewHeight)));
    #endif

    #if TAA_DEBUG > 0
    {
        vec2 sUV  = min(texCoord * renderScale, vec2(renderScale) - 1.0 / vec2(viewWidth, viewHeight));
        vec3 src  = texture(colortex0, sUV).rgb;
        vec3 outc = finalColor.rgb;

        float srcMaxRB = max(src.r,  src.b);
        float outMaxRB = max(outc.r, outc.b);
        float srcDef = (srcMaxRB > 0.02) ? clamp(1.0 - src.g  / max(srcMaxRB, 1e-5), 0.0, 1.0) : 0.0;
        float outDef = (outMaxRB > 0.02) ? clamp(1.0 - outc.g / max(outMaxRB, 1e-5), 0.0, 1.0) : 0.0;
        bool srcBad = any(isnan(src))  || any(isinf(src));
        bool outBad = any(isnan(outc)) || any(isinf(outc));

        #if TAA_DEBUG == 1
            finalColor.rgb = src;                                         // raw source, as-is
        #elif TAA_DEBUG == 2
            if (srcBad)            finalColor.rgb = vec3(1.0, 0.0, 0.0);  // RED   = NaN/Inf in SOURCE
            else if (srcDef > 0.6) finalColor.rgb = vec3(0.0, 1.0, 0.0);  // GREEN = magenta in SOURCE
            else                   finalColor.rgb = src * 0.15;           // dim context
        #elif TAA_DEBUG == 3
            if (outBad)            finalColor.rgb = vec3(1.0, 0.0, 0.0);  // RED   = NaN/Inf in OUTPUT
            else if (outDef > 0.6) finalColor.rgb = vec3(0.0, 1.0, 0.0);  // GREEN = magenta in OUTPUT
            else                   finalColor.rgb = outc * 0.15;
        #elif TAA_DEBUG == 4
            finalColor.rgb = vec3(srcDef);                               // SOURCE green-deficit heatmap
        #endif
    }
    #endif

    float prevExposure = texelFetch(colortex5, ivec2(0), 0).a;
    if (prevExposure <= 0.001 || isnan(prevExposure) || isinf(prevExposure)) {
        prevExposure = 1.0;
    }
    
    float exposure = prevExposure;
    
    #ifdef AUTO_EXPOSURE
    if (ivec2(gl_FragCoord.xy) == ivec2(0)) {
        // Whole-screen weighted log-average luminance. The old meter sampled a 2%
        // spot at the crosshair, so exposure tracked whatever you pointed at — a
        // torch in a dark cave would crash exposure, and small camera moves made it
        // flicker. We now meter a coarse grid over the FULL frame (cheap: this runs
        // only on the (0,0) fragment) with an optional center bias, and guard NaN.
        float sumLuma = 0.0;
        float totalWeight = 0.0;

        const int N = 16; // 16x16 = 256 taps across the whole screen
        for (int xi = 0; xi < N; xi++) {
            for (int yi = 0; yi < N; yi++) {
                vec2 uv = (vec2(xi, yi) + 0.5) / float(N); // 0..1 across the frame
                // Meter the FULL-RES, TAA-RESOLVED scene (colortex5 = last frame's
                // upscaled output) at LOGICAL uv -- NOT the render-scale colortex0.
                // colortex0's rendered region is ALIASED: bright sub-pixel features
                // (sun glints, specular, emissive edges) are point-sampled, so at
                // low RENDER_SCALE each one covers a LARGER screen fraction (a
                // "fatter" bright pixel). That inflated the metered average and
                // dropped exposure -> the whole scene dimmed as render scale fell.
                // colortex5 is upscaled + temporally anti-aliased to full res, so
                // bright features sit at their true area and the metered luminance
                // (hence exposure) is resolution-invariant. (This is the image you
                // compared with auto-exposure OFF and found matched across scales.)
                vec3 rawColor = texture(colortex5, uv).rgb;
                float luma = dot(rawColor, vec3(0.2126, 0.7152, 0.0722));
                if (isnan(luma) || isinf(luma)) continue;     // skip bad pixels
                luma = clamp(luma, 0.0, 60.0);                // one emissive texel can't dominate

                // center weighting (AUTO_EXPOSURE_CENTER_WEIGHT): 0 = flat average,
                // 1 = fully center-biased gaussian. Default keeps a mild bias.
                vec2  d = uv - 0.5;
                float centerW = exp(-dot(d, d) * 8.0);
                float w = mix(1.0, centerW, AUTO_EXPOSURE_CENTER_WEIGHT);

                sumLuma += w * log2(max(luma, 0.0001));
                totalWeight += w;
            }
        }

        float avgLuma = exp2(sumLuma / max(totalWeight, 1e-5));
        avgLuma = clamp(avgLuma, 0.001, 10.0);

        float targetExposure = AUTO_EXPOSURE_TARGET / avgLuma;
        targetExposure = clamp(targetExposure, AUTO_EXPOSURE_MIN, AUTO_EXPOSURE_MAX);

        // Adapt fast when the scene gets brighter (stop down quickly to avoid
        // blinding), slower when it gets darker (open up gently), like an eye.
        float rate = targetExposure > prevExposure ? 1.0 : 2.0;
        rate *= AUTO_EXPOSURE_SPEED;
        float blend = clamp(1.0 - exp(-rate * max(frameTime, 1e-4)), 0.0, 1.0);
        exposure = mix(prevExposure, targetExposure, blend);
        if (isnan(exposure) || isinf(exposure)) exposure = prevExposure; // never propagate a bad value
    }
    #else
    exposure = EXPOSURE;
    #endif
    
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(finalColor.rgb, exposure);
}

#endif
