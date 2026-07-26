#ifndef TAA_GLSL
#define TAA_GLSL

#include "/lib/options.glsl"
#include "/lib/util/common.glsl"
#include "/lib/util/jitter.glsl"
#include "/lib/dh/dh.glsl"

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

float getLuminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 ReinhardTonemap(vec3 color) {
    return color / (1.0 + getLuminance(color));
}

vec3 ReinhardInverse(vec3 color) {
    return color / max(1.0 - getLuminance(color), 0.0001);
}

vec4 textureCatmullRom(sampler2D tex, vec2 uv, vec2 texSize) {
    vec2 texPixelSize = 1.0 / texSize;
    uv = uv * texSize;

    vec2 p = floor(uv - 0.5) + 0.5;
    vec2 f = uv - p;
    vec2 f2 = f * f;
    vec2 f3 = f * f2;

    const float c = 0.5; // Sharpness
    vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
    vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
    vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
    vec2 w3 =         c  * f3 -                c * f2;

    vec2 w12 = w1 + w2;
    vec2 tc12 = texPixelSize * (p + w2 / w12);
    vec2 tc0 = texPixelSize * (p - 1.0);
    vec2 tc3 = texPixelSize * (p + 2.0);

    vec4 color = textureLod(tex, vec2(tc12.x, tc0.y ), 0.0) * (w12.x * w0.y ) +
                 textureLod(tex, vec2(tc0.x,  tc12.y), 0.0) * (w0.x  * w12.y) +
                 textureLod(tex, vec2(tc12.x, tc12.y), 0.0) * (w12.x * w12.y) +
                 textureLod(tex, vec2(tc3.x,  tc12.y), 0.0) * (w3.x  * w12.y) +
                 textureLod(tex, vec2(tc12.x, tc3.y ), 0.0) * (w12.x * w3.y );
                 
    return color / max(w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y, 0.0001);
}


#if UPSCALE_MODE == 2
float lanczos2sq(float x2) {
    x2 = min(x2, 4.0);
    float a = (2.0 / 5.0) * x2 - 1.0;
    float b = (1.0 / 4.0) * x2 - 1.0;
    return ((25.0 / 16.0) * a * a - (25.0 / 16.0 - 1.0)) * (b * b);
}

vec3 sampleLanczos(sampler2D tex, vec2 uv, vec2 texSize) {
    vec2 invSize = 1.0 / texSize;
    vec2 p    = uv * texSize - 0.5;
    vec2 base = floor(p);
    vec2 f    = p - base;

    vec2 hi = vec2(renderScale) - 0.5 * invSize;
    vec2 lo = 0.5 * invSize;

    float kbias = min(1.25, (1.0 / renderScale - 1.0) + 1.0);

    vec3 acc = vec3(0.0); float wsum = 0.0;
    for (int j = 0; j < 4; j++) {
        for (int i = 0; i < 4; i++) {
            vec2 tc = clamp((base + vec2(float(i) - 1.0, float(j) - 1.0) + 0.5) * invSize, lo, hi);
            vec3 c  = textureLod(tex, tc, 0.0).rgb;
            vec2 off = (vec2(float(i) - 1.0, float(j) - 1.0) - f) * kbias; // FSR-biased offset
            float w  = lanczos2sq(dot(off, off));
            acc += c * w; wsum += w;
        }
    }
    return max(acc / max(wsum, 1e-4), 0.0);
}
#endif

void analyzeUpscale(sampler2D tex, vec2 cuv, vec2 screenSize, vec3 centerRGB,
                    out vec3 boxCenter, out vec3 boxHalf, out vec3 reconRGB) {
    vec2 px = 1.0 / screenSize;

    // Current-frame reconstruction.
    #if UPSCALE_MODE == 2
        reconRGB = sampleLanczos(tex, cuv, screenSize);  // sharp Lanczos-2 (texel-centre point taps)
    #else
        reconRGB = centerRGB;                             // modes 0/1 reconstruct in taa()
    #endif

    // 3x3 YCoCg neighbourhood (bilinear taps — shared by ALL modes).
    vec3 s0 = RGBtoYCoCg(textureLod(tex, cuv + vec2(-1, -1) * px, 0.0).rgb);
    vec3 s1 = RGBtoYCoCg(textureLod(tex, cuv + vec2( 0, -1) * px, 0.0).rgb);
    vec3 s2 = RGBtoYCoCg(textureLod(tex, cuv + vec2( 1, -1) * px, 0.0).rgb);
    vec3 s3 = RGBtoYCoCg(textureLod(tex, cuv + vec2(-1,  0) * px, 0.0).rgb);
    vec3 s4 = RGBtoYCoCg(centerRGB);
    vec3 s5 = RGBtoYCoCg(textureLod(tex, cuv + vec2( 1,  0) * px, 0.0).rgb);
    vec3 s6 = RGBtoYCoCg(textureLod(tex, cuv + vec2(-1,  1) * px, 0.0).rgb);
    vec3 s7 = RGBtoYCoCg(textureLod(tex, cuv + vec2( 0,  1) * px, 0.0).rgb);
    vec3 s8 = RGBtoYCoCg(textureLod(tex, cuv + vec2( 1,  1) * px, 0.0).rgb);

    #if UPSCALE_MODE == 0
        // Mode 0: mean ± stddev (variance) box — legacy behaviour.
        vec3 m1 = s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8;
        vec3 m2 = s0*s0 + s1*s1 + s2*s2 + s3*s3 + s4*s4 + s5*s5 + s6*s6 + s7*s7 + s8*s8;
        boxCenter = m1 / 9.0;
        boxHalf   = sqrt(max(m2 / 9.0 - boxCenter * boxCenter, 0.0));
    #else
        vec3 mnP = min(min(min(s1, s3), min(s5, s7)), s4);
        vec3 mxP = max(max(max(s1, s3), max(s5, s7)), s4);
        vec3 mnA = min(mnP, min(min(s0, s2), min(s6, s8)));
        vec3 mxA = max(mxP, max(max(s0, s2), max(s6, s8)));
        vec3 mn = (mnP + mnA) * 0.5;
        vec3 mx = (mxP + mxA) * 0.5;
        boxCenter = (mn + mx) * 0.5;
        boxHalf   = (mx - mn) * 0.5 * 1.1;
    #endif
}


vec3 clipAABB(vec3 avgColor, vec3 variance, vec3 prevColor, float aggression) {
    vec3 clipMin = avgColor - variance * aggression;
    vec3 clipMax = avgColor + variance * aggression;
    
    vec3 diff = prevColor - avgColor;
    vec3 clipRatioMax = mix(vec3(1.0), (clipMax - avgColor) / diff, greaterThan(diff, clipMax - avgColor));
    vec3 clipRatioMin = mix(vec3(1.0), (clipMin - avgColor) / diff, lessThan(diff, clipMin - avgColor));
    
    diff *= clipRatioMax.x * clipRatioMax.y * clipRatioMax.z * clipRatioMin.x * clipRatioMin.y * clipRatioMin.z;
    return avgColor + diff;
}

float getClosestDepth(vec2 uv, vec2 screenSize) {
    float closestDepth = 2.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float d = textureLod(depthtex0, uv + vec2(x, y) / screenSize, 0.0).r;
            if (d < closestDepth) closestDepth = d;
        }
    }
    return closestDepth;
}

vec2 getPreviousUV(vec2 uv, vec2 screenSize, out vec3 velocityPixels) {
    vec2 currentJitter = getTaaJitter(frameCounter) / screenSize;
    vec2 sampleCoord   = clamp((uv + currentJitter) * renderScale,
                               2.0 / screenSize, vec2(renderScale) - 2.0 / screenSize);
    float depth0 = getClosestDepth(sampleCoord, screenSize);

    #ifdef DISTANT_HORIZONS
    // DH terrain and water need DH projection reprojection. Terrain has vanilla
    // sky depth; DH water may have a non-sky translucent depth, but the reliable
    // finite depth still lives in dhDepthTex0.
    float dhd = texture(dhDepthTex0, sampleCoord).r;
    float dhFlag = textureLod(colortex2, sampleCoord, 0.0).b;
    float dhNormalAlpha = textureLod(colortex1, sampleCoord, 0.0).a;
    bool dhReproject = isDhDepthValue(dhd)
                    && ((isVanillaSkyDepth(depth0) && isDhTerrainFlag(dhFlag))
                     || isDhWaterFlag(dhFlag, dhNormalAlpha));
    if (dhReproject) {
        vec3 viewPos  = dhViewPos(uv, dhd);
        vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 prevWorld = worldPos + (cameraPosition - previousCameraPosition);
        vec4 prevClip  = dhPreviousProjection * (gbufferPreviousModelView * vec4(prevWorld, 1.0));
        vec2 prevUV    = (prevClip.xy / prevClip.w) * 0.5 + 0.5;
        velocityPixels = vec3((uv - prevUV) * screenSize, 0.0);
        return prevUV;
    }
    #endif

    if (isVanillaSkyDepth(depth0)) {

        vec4 viewH    = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
        vec3 viewDir  = viewH.xyz / viewH.w;
        vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;
        vec3 prevView = mat3(gbufferPreviousModelView) * worldDir;
        vec4 prevClip = gbufferPreviousProjection * vec4(prevView, 1.0);
        vec2 prevUV   = (prevClip.xy / prevClip.w) * 0.5 + 0.5;

        velocityPixels = vec3((uv - prevUV) * screenSize, 0.0);
        return prevUV;
    }

    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);

    vec4 viewPosVal = gbufferProjectionInverse * clipPos;
    vec3 viewPos = viewPosVal.xyz / viewPosVal.w;
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    vec3 previousWorldPos = worldPos + (cameraPosition - previousCameraPosition);

    vec4 previousClipPos = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(previousWorldPos, 1.0));
    vec2 prevUV = (previousClipPos.xy / previousClipPos.w) * 0.5 + 0.5;

    velocityPixels = vec3((uv - prevUV) * screenSize, 0.0);
    return prevUV;
}

bool inScreen(vec2 uv) {
    return all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)));
}

vec4 taa(vec2 currentPos, vec2 screenSize, sampler2D currentFrame, sampler2D historyFrame) {
    vec2 uv = currentPos / screenSize;

    vec2 currentJitter = getTaaJitter(frameCounter) / screenSize;
    vec2 cuv = clamp((uv + currentJitter) * renderScale,
                     2.0 / screenSize, vec2(renderScale) - 2.0 / screenSize);

    vec4 currentColorData = textureLod(currentFrame, cuv, 0.0);
    float exposureData = currentColorData.a;

    vec3 boxCenter, boxHalf, reconRGB;
    analyzeUpscale(currentFrame, cuv, screenSize, currentColorData.rgb, boxCenter, boxHalf, reconRGB);

    vec3 currentColor;
    #if UPSCALE_MODE == 1
        // Sharper current reconstruction to pair with the min/max clamp.
        currentColor = max(textureCatmullRom(currentFrame, cuv, screenSize).rgb, 0.0);
    #elif UPSCALE_MODE == 2
        currentColor = max(reconRGB, 0.0); // Lanczos-2
    #else
        currentColor = currentColorData.rgb; // bilinear
    #endif

    vec3 velocityPixels;
    vec2 prevUV = getPreviousUV(uv, screenSize, velocityPixels);

    if (!inScreen(prevUV)) {
        return vec4(currentColor, exposureData); // disocclusion / off-screen: take current
    }

    vec4 prevColorData = textureCatmullRom(historyFrame, prevUV, screenSize);

    vec3 prevRGB = prevColorData.rgb;
    if (any(isnan(prevRGB)) || any(isinf(prevRGB))) prevRGB = currentColor;
    vec3 prevColorYCoCg = RGBtoYCoCg(max(prevRGB, 0.0));

    bool isWater = textureLod(colortex2, cuv, 0.0).b > 0.5;
    bool isSky   = isVanillaSkyDepth(textureLod(depthtex0, cuv, 0.0).r);
    #ifdef DISTANT_HORIZONS
        // DH LODs are vanilla-sky depth but real geometry — don't give them the
        // sky's sticky 0.97 blend / loose clamp, or moving the camera smears them.
        if (isSky) {
            float dhd = textureLod(dhDepthTex0, cuv, 0.0).r;
            float dhFlag = textureLod(colortex2, cuv, 0.0).b;
            if (isDhDepthValue(dhd) && isDhTerrainFlag(dhFlag)) isSky = false;
        }
    #endif

    float aggression = (isWater || isSky) ? 3.0 : 1.0;

    prevColorYCoCg = clipAABB(boxCenter, boxHalf, prevColorYCoCg, aggression);

    float yY = max(prevColorYCoCg.x, 0.0);
    prevColorYCoCg.z = clamp(prevColorYCoCg.z, -yY, yY);
    float coLim = max(yY - prevColorYCoCg.z, 0.0);
    prevColorYCoCg.y = clamp(prevColorYCoCg.y, -coLim, coLim);
    vec3 prevColor = max(YCoCgtoRGB(prevColorYCoCg), 0.0);

    float blendWeight = TAA_BLEND_WEIGHT;
    if (isSky) blendWeight = max(blendWeight, 0.97);

    float velocityReject = clamp(pow(dot(velocityPixels.xy, velocityPixels.xy), 0.25) * 0.1, 0.0, 1.0);
    if (isWater) velocityReject *= 0.25; // stable history for water during camera movement
    if (isSky)   velocityReject *= 0.5;  // reprojection handles rotation; trim residual ghosting
    blendWeight *= (1.0 - velocityReject);

    #if TAA_DEBUG == 5
        return vec4(currentColor, exposureData);                     // reconstruction only (no history)
    #elif TAA_DEBUG == 6
        return vec4(prevColor, exposureData);                        // clipped history only
    #elif TAA_DEBUG == 7
        return vec4(abs(currentColor - prevColor) * 6.0, exposureData); // recon vs history disagreement
    #endif

    vec3 tonemappedHistory = ReinhardTonemap(prevColor);
    vec3 tonemappedCurrent = ReinhardTonemap(currentColor);
    vec3 blended = mix(tonemappedCurrent, tonemappedHistory, blendWeight);

    vec3 outColor = ReinhardInverse(blended);
    if (any(isnan(outColor)) || any(isinf(outColor))) outColor = currentColor;
    return vec4(outColor, exposureData);
}

#endif
