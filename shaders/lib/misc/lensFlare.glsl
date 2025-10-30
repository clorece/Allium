float fovmult = gbufferProjection[1][1] / 1.37373871;

vec2 lensFlareCheckOffsets[4] = vec2[4](
    vec2( 1.0, 0.0),
    vec2(-1.0, 1.0),
    vec2( 0.0, 1.0),
    vec2( 1.0, 1.0)
);

//---------------------------------------------------------//
// Circle & Polygon Lens Flare by: Yusef28
// https://www.shadertoy.com/view/Xlc3D2
//---------------------------------------------------------//

float randVec2(vec2 v) {
    return fract(sin(dot(v, vec2(12.1234, 72.8392)) * 45123.2));
}

float randFloat(float v) {
    return fract(sin(v) * 1000.0);
}

float polygonMask(vec2 p, int sides) {
    float angle     = atan(p.x, p.y) + 0.2;
    float sector    = 6.28319 / float(sides);
    float diffAngle = floor(0.5 + angle / sector) * sector - angle;
    return smoothstep(0.5, 1.0, cos(diffAngle) * length(p));
}

vec3 circlePulseLens(vec2 uvOffset, float pulseSize, vec3 baseColor, vec3 highlightColor, float pulseDist, vec2 sunDirection) {
    vec2 shiftedUV = (uvOffset + sunDirection * 1.5 * pulseDist) * 2.0;
    float ringCoord = length(shiftedUV * (pulseDist * 4.0)) + pulseSize / 2.0;
    float core      = max(0.01 - pow(length(shiftedUV * pulseDist), pulseSize * 1.4), 0.0) * 50.0;
    float ring      = max(0.001 - pow(ringCoord - 0.3, 1.0/40.0) + sin(ringCoord * 30.0), 0.0) * 3.0;
    float spark     = max(0.04 / pow(length(shiftedUV), 1.25), 0.0) / 20.0;
    float petal     = max(0.01 - pow(polygonMask(shiftedUV * 8.0 + 0.9, 6), 1.0), 0.0) * 50.0;
    baseColor       = 0.5 + 0.5 * sin(baseColor);
    baseColor       = cos(vec3(0.44, 0.24, 0.2) * 8.0 + pulseDist * 4.0) * 0.5 + 0.5;
    return (core + ring + spark + petal) * baseColor;
}

void DoLensFlare(inout vec3 color, vec3 viewPos, float dither) {
    vec4  clipPos   = gbufferProjection * vec4(sunVec + 0.001, 1.0);
    vec3  sunNDC    = clipPos.xyz / clipPos.w * 0.5;
    vec2  sunDirN   = sunNDC.xy;
    vec2  sunUV     = sunNDC.xy + 0.5;
    vec2  screenUV  = texCoord;

    float occlusionFactor = 1.0;
    vec2  sampleScale     = 40.0 / vec2(viewWidth, viewHeight);
    for (int i = 0; i < 4; i++) {
        vec2  offset    = (lensFlareCheckOffsets[i] - dither) * sampleScale;
        float sceneZ1   = texture2D(depthtex0, sunUV + offset).r;
        float sceneZ2   = texture2D(depthtex0, sunUV - offset).r;
        #ifdef VL_CLOUDS_ACTIVE
            float cloudZ1 = texture2D(colortex4, sunUV + offset).r;
            float cloudZ2 = texture2D(colortex4, sunUV - offset).r;
            sceneZ1       = min(sceneZ1, cloudZ1);
            sceneZ2       = min(sceneZ2, cloudZ2);
        #endif
        if (sceneZ1 < 1.0) occlusionFactor -= 0.125;
        if (sceneZ2 < 1.0) occlusionFactor -= 0.125;
    }

    float edgeDist = length(sunDirN * vec2(aspectRatio, 1.0));
    float edgeFall = pow(clamp(edgeDist * 8.0, 0.0, 1.0), 2.0)
                   - clamp(edgeDist * 3.0 - 1.5, 0.0, 1.0);
    occlusionFactor *= edgeFall;

    #ifdef SUN_MOON_DURING_RAIN
        occlusionFactor *= 0.65 - 0.4 * rainFactor;
    #else
        occlusionFactor *= 1.0 - rainFactor;
    #endif

    vec3 circleAccum = vec3(0.0);
    for (int i = 0; i < 10; i++) {
        float idx     = float(i);
        float size    = pow(randFloat(idx * 2000.0) * 1.8, 2.0) + 1.41;
        float distVal = randFloat(idx * 20.0) * 3.0 - 0.3;
        vec3 colA     = vec3(1.0) * (0.2 + 0.1 * idx);
        vec3 colB     = vec3(1.0) * (0.8 - 0.05 * idx);
        circleAccum  += circlePulseLens(screenUV - sunUV + sunDirN, size * 0.75, colA, colB, distVal, sunDirN);
    }
    circleAccum *= LENSFLARE_I * 0.25;
    circleAccum *= clamp01((SdotU + 0.1) * 5.0);

    float flareFactor = 1.0;
    vec3 flare = circleAccum * occlusionFactor;

    #if LENSFLARE_MODE == 2
        if (sunVec.z > 0.0) {
            flare = flare * 0.2 + GetLuminance(flare) * vec3(0.3, 0.4, 0.6);
            flare *= clamp01(1.0 - (SdotU + 0.1) * 5.0);
            flareFactor *= LENSFLARE_I > 1.001 ? sqrt(LENSFLARE_I) : LENSFLARE_I;
        } else
    #endif
    {
        flareFactor *= LENSFLARE_I;
        flare *= clamp01((SdotU + 0.1) * 5.0);
    }

    //color += flareFactor;
    flare *= flareFactor;

    color += flare;
}