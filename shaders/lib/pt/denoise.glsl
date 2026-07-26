#ifndef DENOISE_GLSL
#define DENOISE_GLSL

#ifndef FRAME_COUNTER_DECLARE
#define FRAME_COUNTER_DECLARE
#endif

#include "/lib/util/common.glsl"
#include "/lib/options.glsl"

#ifndef LUMA_FN
#define LUMA_FN
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
#endif

vec3 RGBtoYCoCg(vec3 c) {
    return vec3(
         0.25 * c.r + 0.5 * c.g + 0.25 * c.b,
         0.5  * c.r - 0.5 * c.b,
        -0.25 * c.r + 0.5 * c.g - 0.25 * c.b
    );
}
vec3 YCoCgtoRGB(vec3 c) {
    float tmp = c.x - c.z;
    return vec3(tmp + c.y, c.x + c.z, tmp - c.y);
}

vec3 clipHistoryMoments(vec3 history, vec3 m1, vec3 m2) {
    vec3 std = sqrt(max(m2 - m1 * m1, 0.0));
    // m1/m2/std are in YCoCg space: only Y (luma) is non-negative, so the
    // "cap std at 2x the mean" anti-overshoot heuristic is valid for Y alone.
    // The Co/Cg chroma means are SIGNED (warm colors have Cg < 0); capping their
    // std against m1*2 gives a negative std, which inverts the clamp window below
    // and forces chroma to the wrong side -> warm emitters (torch/lava) shift to
    // purple and white emitters skew blue as the history converges.
    std.x = min(std.x, m1.x * 2.0);

    // Box clamp history to [mean - k*std, mean + k*std]
    vec3 h = RGBtoYCoCg(history);
    return YCoCgtoRGB(clamp(h, m1 - std * 1.5, m1 + std * 1.5));
}

bool fetchBilateralHistory(
    vec2 uv, float expectedClipZ, vec3 expectedNormalWorld,
    sampler2D hist8, sampler2D hist9, sampler2D hist15,
    out vec4 outHistory8, out vec4 outHistory9
) {
    vec2 pos = uv * vec2(viewWidth, viewHeight) - 0.5;
    vec2 pos00 = floor(pos);
    vec2 f = pos - pos00;

    ivec2 i00 = ivec2(pos00);
    ivec2 i10 = i00 + ivec2(1, 0);
    ivec2 i01 = i00 + ivec2(0, 1);
    ivec2 i11 = i00 + ivec2(1, 1);

    vec4 w = vec4(
        (1.0 - f.x) * (1.0 - f.y),
        f.x * (1.0 - f.y),
        (1.0 - f.x) * f.y,
        f.x * f.y
    );

    vec4 c9_00 = texelFetch(hist9, i00, 0);
    vec4 c9_10 = texelFetch(hist9, i10, 0);
    vec4 c9_01 = texelFetch(hist9, i01, 0);
    vec4 c9_11 = texelFetch(hist9, i11, 0);

    float expectedLinDepth = getDepth(expectedClipZ * 0.5 + 0.5);
    bool isHand = (expectedLinDepth < 0.76); // hand depth threshold
    
    vec4 validW;
    if (isHand) {
        // for the hand, use relative linear depth check to accommodate bobbing/sway
        vec4 linDepths = vec4(
            getDepth(c9_00.r),
            getDepth(c9_10.r),
            getDepth(c9_01.r),
            getDepth(c9_11.r)
        );
        vec4 relErr = abs(linDepths - vec4(expectedLinDepth)) / max(vec4(expectedLinDepth), vec4(1e-3));
        validW = step(relErr, vec4(0.15)); // change 0.15 (15%) relative threshold for the hand
    } else {
        vec4 clipZ = vec4(c9_00.r, c9_10.r, c9_01.r, c9_11.r) * 2.0 - 1.0;
        validW = step(abs(clipZ - expectedClipZ), vec4(0.005));
    }

    vec3 n00 = octDecodeNormal(texelFetch(hist15, i00, 0).xy);
    vec3 n10 = octDecodeNormal(texelFetch(hist15, i10, 0).xy);
    vec3 n01 = octDecodeNormal(texelFetch(hist15, i01, 0).xy);
    vec3 n11 = octDecodeNormal(texelFetch(hist15, i11, 0).xy);
    
    vec4 normalW = vec4(
        max(dot(n00, expectedNormalWorld), 0.0),
        max(dot(n10, expectedNormalWorld), 0.0),
        max(dot(n01, expectedNormalWorld), 0.0),
        max(dot(n11, expectedNormalWorld), 0.0)
    );

    validW *= pow(normalW, vec4(16.0));

    #ifdef ACCUM_NO_EDGE_REJECT
        // Drop the NORMAL/edge gate (it rejected convex-corner & footprint-straddle
        // edges, stopping them from accumulating -> the edge fireflies) but keep a
        // LOOSE relative-depth DISOCCLUSION gate: a genuine depth jump (new geometry)
        // still flushes stale history, so disocclusion stays clean without bringing
        // the edge fireflies back. Tune ACCUM_DISOCC_DEPTH (relative depth tolerance).
        #ifndef ACCUM_DISOCC_DEPTH
            #define ACCUM_DISOCC_DEPTH 0.1
        #endif
        // Evaluate the relative-linear gate in WINDOW-DEPTH space. c9.r is fp16
        // *window* depth; running it through getDepth() amplified a single fp16 step
        // (~5e-4 near the far plane) into hundreds of blocks of linear error, so the
        // test failed in concentric depth bands -> strips of un-blended GI. Instead,
        // map the +/-tol LINEAR band to window bounds (inverse getDepth) and range-
        // check the stored window depth, widened by a small floor so fp16 quantisation
        // (and thus distant, indistinguishable surfaces) doesn't spuriously reject.
        float kA = (far + near) / (far - near);
        float kB = 2.0 * near * far / (far - near);
        float loLin = expectedLinDepth * (1.0 - ACCUM_DISOCC_DEPTH);
        float hiLin = expectedLinDepth * (1.0 + ACCUM_DISOCC_DEPTH);
        float wLo = 0.5 + 0.5 * (kA - kB / max(loLin, 1e-3)) - 0.002; // smaller lin -> smaller window
        float wHi = 0.5 + 0.5 * (kA - kB / max(hiLin, 1e-3)) + 0.002;
        vec4 histW = vec4(c9_00.r, c9_10.r, c9_01.r, c9_11.r);
        validW = step(vec4(wLo), histW) * step(histW, vec4(wHi));
    #endif

    w *= validW;

    float wSum = dot(w, vec4(1.0));
    if (wSum > 1e-5) {
        vec4 c8_00 = texelFetch(hist8, i00, 0);
        vec4 c8_10 = texelFetch(hist8, i10, 0);
        vec4 c8_01 = texelFetch(hist8, i01, 0);
        vec4 c8_11 = texelFetch(hist8, i11, 0);

        outHistory8 = (c8_00 * w.x + c8_10 * w.y + c8_01 * w.z + c8_11 * w.w) / wSum;
        outHistory9 = (c9_00 * w.x + c9_10 * w.y + c9_01 * w.z + c9_11 * w.w) / wSum;
        return true;
    }
    return false;
}

float atrousW(int i) {
    return (i == 0) ? (6.0 / 16.0) : (i == 1) ? (4.0 / 16.0) : (1.0 / 16.0);
}

float atrousW3(int i) {
    return (i == 0) ? 0.5 : 0.25;
}

float varFromMoments(float m1, float m2) {
    return max(m2 - m1 * m1, 0.0);
}

float svgfVarianceFloor(float centerLuma) {
    float lowLightBoost = mix(3.0, 1.0, smoothstep(0.02, 0.18, abs(centerLuma)));
    float sigma = max(abs(centerLuma) * SVGF_MIN_LUMA_SIGMA * lowLightBoost, 0.006);
    return sigma * sigma;
}

float spatialLumaVariance(sampler2D colorTex, vec2 uv) {
    float s1 = 0.0, s2 = 0.0, count = 0.0;
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            float l = luma(textureLod(colorTex, uv + vec2(x, y) * texelSize, 0.0).rgb);
            s1 += l; s2 += l * l; count += 1.0;
        }
    }
    s1 /= count; s2 /= count;
    return max(s2 - s1 * s1, 0.0);
}

float gauss3Var(sampler2D src, vec2 uv) {
    float v = 0.0, wsum = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            float w = ((x == 0) ? 2.0 : 1.0) * ((y == 0) ? 2.0 : 1.0);
            v += textureLod(src, uv + vec2(x, y) * texelSize, 0.0).a * w;
            wsum += w;
        }
    }
    return v / wsum;
}

float getJitterRotation(vec2 uv, int frame) {
    vec2 p = uv * vec2(viewWidth, viewHeight);
    float perPixel = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))) * 6.2831853;
    float taaPhase = float(frame % 8) * (6.2831853 / 8.0); // locked to the TAA jitter period
    return perPixel + taaPhase;
}

vec4 svgfAtrousFirst(
    vec2 uv, float centerDepth, vec2 depthGrad, vec3 centerN, float histLen,
    float pxWorld
) {
    vec3 cColor = textureLod(colortex8, uv, 0.0).rgb;
    float cLuma = luma(cColor);
    vec4 cm = textureLod(colortex9, uv, 0.0);
    float cVar = varFromMoments(cm.g, cm.b);

    #ifdef SVGF_VAR_HISTNORM
        float varNorm = 1.0 / max(histLen, 1.0);
    #else
        const float varNorm = 1.0;
    #endif
    cVar = max(cVar * varNorm, svgfVarianceFloor(cLuma));

    if (histLen < float(SVGF_VAR_BOOST)) {
        float s1 = 0.0;
        float s2 = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                float l = luma(textureLod(colortex8, uv + vec2(x, y) * texelSize, 0.0).rgb);
                s1 += l;
                s2 += l * l;
            }
        }
        s1 /= 9.0;
        s2 /= 9.0;
        cVar = max(cVar, max(s2 - s1 * s1, 0.0)) * (1.0 + (float(SVGF_VAR_BOOST) - histLen));
    }

    float darkGate = mix(2.5, 1.0, smoothstep(0.02, 0.18, cLuma));
    float invSigmaL = 1.0 / (SVGF_SIGMA_L * sqrt(max(cVar, 0.0)) * darkGate + 0.05);
    float invSigmaZ = 1.0 / (SVGF_SIGMA_Z * abs(centerDepth) * 0.02 + 1e-3);
    float sigmaN = min(float(SVGF_SIGMA_N), 16.0);
    float stepSize = 1.0 + clamp(1.0 - histLen / max(float(SVGF_VAR_BOOST), 1.0), 0.0, 1.0);

    vec3 sumC = vec3(0.0);
    float sumV = 0.0;
    float wsum = 0.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 off = vec2(x, y) * stepSize;
            // Clamp taps into the rendered region instead of skipping them. Skipping
            // left screen-border pixels with a truncated kernel -> under-denoised edge
            // disocclusion noise. Clamping samples the nearest valid pixel (a 1D blur
            // along the edge); the edge-stopping weights below still reject true
            // geometry mismatches. off is recomputed from the clamped position so the
            // depth-gradient term stays correct. Interior pixels: clamp is a no-op.
            vec2 nUV = clamp(uv + off * texelSize, vec2(0.0), vec2(renderScale) - texelSize);
            off = (nUV - uv) / texelSize;

            vec3 nColor = textureLod(colortex8, nUV, 0.0).rgb;
            vec4 nm = textureLod(colortex9, nUV, 0.0);
            vec4 ng = textureLod(colortex15, nUV, 0.0);

            float w = atrousW3(abs(x)) * atrousW3(abs(y));
            if (x != 0 || y != 0) {
                float expectedD = centerDepth + dot(depthGrad, off);
                #ifdef DENOISE_NO_EDGE_REJECT
                    float wz = 1.0; // EXPERIMENT: geometric edge rejection OFF -> kernel crosses block edges so trapped edge fireflies get blurred (cost: GI bleeds across edges)
                    float wn = 1.0;
                #else
                    float wz = exp(-abs(ng.z - expectedD) * invSigmaZ);
                    float wn = pow(max(dot(octDecodeNormal(ng.xy), centerN), 0.0), sigmaN);
                #endif
                float wl = exp(-abs(cLuma - luma(nColor)) * invSigmaL);
                w *= wz * wn * wl;

                #ifdef SVGF_WORLD_RADIUS
                    float tangential = length(off) * pxWorld * abs(centerDepth);
                    float worldDist = sqrt(tangential * tangential +
                                           (ng.z - expectedD) * (ng.z - expectedD));
                    w *= exp(-worldDist / SVGF_SIGMA_WORLD);
                #endif
            }

            sumC += nColor * w;
            sumV += max(varFromMoments(nm.g, nm.b) * varNorm, svgfVarianceFloor(luma(nColor))) * w * w;
            wsum += w;
        }
    }

    return vec4(sumC / max(wsum, 1e-5), sumV / max(wsum * wsum, 1e-5));
}

vec4 svgfAtrous(
    sampler2D src, vec2 uv, float stepSize,
    float centerDepth, vec2 depthGrad, vec3 centerN, float pxWorld,
    bool centerVarOnly
) {
    vec4 c = textureLod(src, uv, 0.0);
    float cLuma = luma(c.rgb);
    float varG = centerVarOnly ? c.a : gauss3Var(src, uv);
    varG = max(varG, svgfVarianceFloor(cLuma));

    float darkGate = mix(2.5, 1.0, smoothstep(0.02, 0.18, cLuma));
    float invSigmaL = 1.0 / (SVGF_SIGMA_L * sqrt(max(varG, 0.0)) * darkGate + 0.05);
    float invSigmaZ = 1.0 / (SVGF_SIGMA_Z * abs(centerDepth) * 0.02 + 1e-3);
    float sigmaN = min(float(SVGF_SIGMA_N), 16.0);

    vec3 sumC = vec3(0.0);
    float sumV = 0.0;
    float wsum = 0.0;

    mat2 rot = mat2(1.0, 0.0, 0.0, 1.0);
    if (stepSize > 2.0) {
        float rotAngle = getJitterRotation(uv, frameCounter);
        rot = mat2(cos(rotAngle), -sin(rotAngle), sin(rotAngle), cos(rotAngle));
    }

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 off = rot * (vec2(x, y) * stepSize);
            // Clamp taps into the rendered region instead of skipping (see svgfAtrousFirst):
            // fixes under-denoised screen-border disocclusion. off recomputed from the
            // clamped position to keep the depth-gradient term correct. No-op interior.
            vec2 nUV = clamp(uv + off * texelSize, vec2(0.0), vec2(renderScale) - texelSize);
            off = (nUV - uv) / texelSize;

            vec4 n = textureLod(src, nUV, 0.0);
            vec4 ng = textureLod(colortex15, nUV, 0.0);

            float w = atrousW3(abs(x)) * atrousW3(abs(y));
            if (x != 0 || y != 0) {
                float expectedD = centerDepth + dot(depthGrad, off);
                #ifdef DENOISE_NO_EDGE_REJECT
                    float wz = 1.0; // EXPERIMENT: geometric edge rejection OFF (see svgfAtrousFirst)
                    float wn = 1.0;
                #else
                    float wz = exp(-abs(ng.z - expectedD) * invSigmaZ);
                    float wn = pow(max(dot(octDecodeNormal(ng.xy), centerN), 0.0), sigmaN);
                #endif
                float wl = exp(-abs(cLuma - luma(n.rgb)) * invSigmaL);
                w *= wz * wn * wl;

                #ifdef SVGF_WORLD_RADIUS
                    float tangential = length(off) * pxWorld * abs(centerDepth);
                    float worldDist = sqrt(tangential * tangential +
                                           (ng.z - expectedD) * (ng.z - expectedD));
                    w *= exp(-worldDist / SVGF_SIGMA_WORLD);
                #endif
            }

            sumC += n.rgb * w;
            sumV += n.a * w * w;
            wsum += w;
        }
    }

    return vec4(sumC / max(wsum, 1e-5), sumV / max(wsum * wsum, 1e-5));
}

#endif
