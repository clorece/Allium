#define CUMULONIMBUS 
#define CUMULUS
#define ALTOCUMULUS 

#define CLOUD_RENDER_DISTANCE 1536 //[1024 1536 2048]

#define CUMULONIMBUS_MULT 0.6 //[0.4 0.45 0.5 0.55 0.6 0.65 0.7]
    #define CUMULONIMBUS_SIZE_MULT 200.0 //[100.0 200.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0]
    #define CUMULONIMBUS_SIZE_MULT_M CUMULONIMBUS_SIZE_MULT * 0.01
    #define CUMULONIMBUS_GRANULARITY 0.6 //[0.1 0.2 0.3 0.4 0.475 0.5 0.6 0.7 0.8 0.9 1.0]
    #define CUMULONIMBUS_ALT 128  //[-96 -92 -88 -84 -80 -76 -72 -68 -64 -60 -56 -52 -48 -44 -40 -36 -32 -28 -24 -20 -16 -10 -8 -4 0 4 8 12 16 20 22 24 28 32 36 40 44 48 52 56 60 64 68 72 76 80 84 88 92 96 100 104 108 112 116 120 124 128 132 136 140 144 148 152 156 160 164 168 172 176 180 184 188 192 196 200 204 208 212 216 220 224 228 232 236 240 244 248 252 256 260 264 268 272 276 280 284 288 292 296 300 304 308 312 316 320 324 328 332 336 340 344 348 352 356 360 364 368 372 376 380 384 388 392 396 400 404 408 412 416 420 424 428 432 436 440 444 448 452 456 460 464 468 472 476 480 484 488 492 496 500 510 520 530 540 550 560 570 580 590 600 610 620 630 640 650 660 670 680 690 700 710 720 730 740 750 760 770 780 790 800]
    #define CUMULONIMBUS_HEIGHT 32.0 //[6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0 24.0 32.0 48.0 54.0 64.0]
    #define CUMULONIMBUS_COVERAGE 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define CUMULUS_MULT 0.5 //[0.4 0.45 0.5 0.55 0.6 0.65 0.7]
    #define CUMULUS_SIZE_MULT 200.0 //[100.0 200.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0]
    #define CUMULUS_SIZE_MULT_M CUMULUS_SIZE_MULT * 0.01
    #define CUMULUS_GRANULARITY 0.4 //[0.1 0.2 0.3 0.4 0.475 0.5 0.6 0.7 0.8 0.9 1.0]
    #define CUMULUS_ALT      212 //[-96 -92 -88 -84 -80 -76 -72 -68 -64 -60 -56 -52 -48 -44 -40 -36 -32 -28 -24 -20 -16 -10 -8 -4 0 4 8 12 16 20 22 24 28 32 36 40 44 48 52 56 60 64 68 72 76 80 84 88 92 96 100 104 108 112 116 120 124 128 132 136 140 144 148 152 156 160 164 168 172 176 180 184 188 192 196 200 204 208 212 216 220 224 228 232 236 240 244 248 252 256 260 264 268 272 276 280 284 288 292 296 300 304 308 312 316 320 324 328 332 336 340 344 348 352 356 360 364 368 372 376 380 384 388 392 396 400 404 408 412 416 420 424 428 432 436 440 444 448 452 456 460 464 468 472 476 480 484 488 492 496 500 510 520 530 540 550 560 570 580 590 600 610 620 630 640 650 660 670 680 690 700 710 720 730 740 750 760 770 780 790 800]
    #define CUMULUS_HEIGHT 20.0 //[6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0 24.0 32.0 48.0 54.0 64.0]
    #define CUMULUS_COVERAGE 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define ALTOCUMULUS_MULT 0.3 //[0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7]
    #define ALTOCUMULUS_SIZE_MULT 200.0 //[100.0 200.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0]
    #define ALTOCUMULUS_SIZE_MULT_M ALTOCUMULUS_SIZE_MULT * 0.01
    #define ALTOCUMULUS_GRANULARITY 0.6 //[0.1 0.2 0.3 0.4 0.5 0.55 0.6 0.7 0.8 0.9 1.0]
    #define ALTOCUMULUS_ALT  300 //[-96 -92 -88 -84 -80 -76 -72 -68 -64 -60 -56 -52 -48 -44 -40 -36 -32 -28 -24 -20 -16 -10 -8 -4 0 4 8 12 16 20 22 24 28 32 36 40 44 48 52 56 60 64 68 72 76 80 84 88 92 96 100 104 108 112 116 120 124 128 132 136 140 144 148 152 156 160 164 168 172 176 180 184 188 192 196 200 204 208 212 216 220 224 228 232 236 240 244 248 252 256 260 264 268 272 276 280 284 288 292 296 300 304 308 312 316 320 324 328 332 336 340 344 348 352 356 360 364 368 372 376 380 384 388 392 396 400 404 408 412 416 420 424 428 432 436 440 444 448 452 456 460 464 468 472 476 480 484 488 492 496 500 510 520 530 540 550 560 570 580 590 600 610 620 630 640 650 660 670 680 690 700 710 720 730 740 750 760 770 780 790 800]
    #define ALTOCUMULUS_HEIGHT 8.0 //[6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0 24.0 32.0 48.0 54.0 64.0]
    #define ALTOCUMULUS_COVERAGE 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#ifndef DISTANT_HORIZONS
    #define CLOUD_BASE_ADD 0.65
    #define CLOUD_FAR_ADD 0.01
    #define CLOUD_ABOVE_ADD 0.1
#else
    #define CLOUD_BASE_ADD 0.9
    #define CLOUD_FAR_ADD -0.005
    #define CLOUD_ABOVE_ADD 0.03
#endif




const int cumulonimbusAlt = int(CUMULONIMBUS_ALT);
const int cumulusAlt      = int(CUMULUS_ALT);
const int altocumulusAlt  = int(ALTOCUMULUS_ALT);

float cumulonimbusCloudStretch = CUMULONIMBUS_HEIGHT;
float cumulonimbusCloudHeight = cumulonimbusCloudStretch * 2.0;
float cumulusCloudStretch = CUMULUS_HEIGHT;
float cumulusCloudHeight = cumulusCloudStretch * 2.0;
float altocumulusCloudStretch = ALTOCUMULUS_HEIGHT;
float altocumulusCloudHeight = altocumulusCloudStretch * 2.0;

#include "/lib/colors/lightAndAmbientColors.glsl"
#include "/lib/colors/cloudColors.glsl"
#include "/lib/atmospherics/sky.glsl"

#if SHADOW_QUALITY > -1
    vec3 GetShadowOnCloudPosition(vec3 tracePos, vec3 cameraPos) {
        vec3 wpos = PlayerToShadow(tracePos - cameraPos);
        float distb = sqrt(wpos.x * wpos.x + wpos.y * wpos.y);
        float distortFactor = 1.0 - shadowMapBias + distb * shadowMapBias;
        vec3 shadowPosition = vec3(vec2(wpos.xy / distortFactor), wpos.z * 0.2);
        return shadowPosition * 0.5 + 0.5;
    }

    bool GetShadowOnCloud(vec3 tracePos, vec3 cameraPos, int cloudAltitude, float lowerPlaneAltitude, float higherPlaneAltitude) {
        const float cloudShadowOffset = 0.5;

        vec3 shadowPosition0 = GetShadowOnCloudPosition(tracePos, cameraPos);
        if (length(shadowPosition0.xy * 2.0 - 1.0) < 1.0) {
            float shadowsample0 = shadow2D(shadowtex0, shadowPosition0).z;

            if (shadowsample0 == 0.0) return true;
        }

        return false;
    }

#endif

// THIS Volumetric Cloud Code based off of VOLUMETRIC CLOUD by alro at Shadertoy: https://www.shadertoy.com/view/3sffzj

#if CLOUD_UNBOUND_SIZE_MULT != 100
    #define CLOUD_UNBOUND_SIZE_MULT_M CLOUD_UNBOUND_SIZE_MULT * 0.01
#endif

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

float remap(float x, float low1, float high1, float low2, float high2){
    return low2 + (x - low1) * (high2 - low2) / (high1 - low1);
}

#define SIZE 8.0

vec3 modulo(vec3 m, float n){
  return mod(mod(m, n) + n, n);
}

// https://www.shadertoy.com/view/4djSRW
vec3 hash(vec3 p3){
    p3 = modulo(p3, SIZE);
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return 2.0 * fract((p3.xxy + p3.yxx) * p3.zyx) - 1.0;
}

float Noise3D(vec3 p) {
    p.z = fract(p.z) * 128.0;
    float iz = floor(p.z);
    float fz = fract(p.z);
    vec2 a_off = vec2(23.0, 29.0) * (iz) / 128.0;
    vec2 b_off = vec2(23.0, 29.0) * (iz + 1.0) / 128.0;
    float a = texture2D(noisetex, p.xy + a_off).r;
    float b = texture2D(noisetex, p.xy + b_off).r;
    return mix(a, b, fz);
}

float Noise3D2(vec3 p) {
    p.z = fract(p.z) * 20.0;
    float iz = floor(p.z);
    float fz = fract(p.z);
    vec2 a_off = vec2(23.0, 29.0) * (iz) / 20.0;
    vec2 b_off = vec2(23.0, 29.0) * (iz + 1.0) / 20.0;
    float a = texture2D(colortex3, p.xy + a_off).r;
    float b = texture2D(colortex3, p.xy + b_off).b;
    return mix(a, b, fz);
}

float GetWind() {
    float wind = 0.00035;
    #if CLOUD_SPEED_MULT == 100
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        wind *= syncedTime;
    #else
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        wind *= frameTimeCounter * CLOUD_SPEED_MULT_M;
    #endif

    return wind;
}


vec3 Offset(float wind) {return vec3(wind * 0.7, wind * 0.5, wind * 0.2);}

float getCloudMap(vec3 p){
    vec2 uv = 0.5 + 0.5 * (p.xz/(1.8 * 100.0));
    return texture2D(noisetex, uv).x;
}

#include "/lib/atmospherics/clouds/cumulonimbus.glsl"
#include "/lib/atmospherics/clouds/cumulus.glsl"
#include "/lib/atmospherics/clouds/altocumulus.glsl"

float PhaseHG(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159 * pow(denom, 1.5));
}

float SampleCloudShadow(vec3 tracePos, vec3 lightDir, float dither, int steps, int cloudAltitude, float stretch, float size, int layer) {
    float shadow = 0.0;
    float density = 0.0;
    vec3 samplePos = tracePos;

    for (int i = 0; i < steps; ++i) {
        samplePos += lightDir * 2.5;
        if (abs(samplePos.y - cloudAltitude) > stretch * 2.0) break;

        if (layer == 2) {
            density = clamp(GetCumulusCloud(samplePos, steps, cloudAltitude, length(samplePos.xz), samplePos.y - cloudAltitude, 0.6, 1.0, size), 0.0, 1.0);
        } else if (layer == 1) {
            density = clamp(GetCumulonimbusCloud(samplePos, steps, cloudAltitude, length(samplePos.xz), samplePos.y - cloudAltitude, 0.6, 1.0, size), 0.0, 1.0);
        } else if (layer == 3) {
            density = clamp(GetAltocumulusCloud(samplePos, steps, cloudAltitude, length(samplePos.xz), samplePos.y - cloudAltitude, 0.6, 1.0, size), 0.0, 1.0);
        }



        shadow += density / float(i + 1);
        //if (shadow < 1e-5) break;
    }

    return clamp(shadow / float(steps), 0.0, 1.0);
}

vec4 GetVolumetricClouds(int cloudAltitude, 
    float distanceThreshold, 
    inout float cloudLinearDepth, 
    float skyFade, 
    float skyMult0, 
    vec3 cameraPos, 
    vec3 nPlayerPos, 
    float lViewPosM, 
    float VdotS, 
    float VdotU, 
    float dither, 
    float noisePersistance, 
    float mult, 
    float size,
    int layer
    ) {
    vec4 volumetricClouds = vec4(0.0);

    #if CLOUD_QUALITY <= 1
        return volumetricClouds;
    #else
        float higherPlaneAltitude = 0.0;
        float lowerPlaneAltitude = 0.0;

        if (layer == 1) {
            higherPlaneAltitude = cloudAltitude + cumulonimbusCloudStretch;
            lowerPlaneAltitude  = cloudAltitude - cumulonimbusCloudStretch;
        } else if (layer == 2) {
            higherPlaneAltitude = cloudAltitude + cumulusCloudStretch;
            lowerPlaneAltitude  = cloudAltitude - cumulusCloudStretch;
        } else if (layer == 3) {
            higherPlaneAltitude = cloudAltitude + altocumulusCloudStretch;
            lowerPlaneAltitude  = cloudAltitude - altocumulusCloudStretch;
        }
        

        float lowerPlaneDistance  = (lowerPlaneAltitude - cameraPos.y) / nPlayerPos.y;
        float higherPlaneDistance = (higherPlaneAltitude - cameraPos.y) / nPlayerPos.y;
        float minPlaneDistance = min(lowerPlaneDistance, higherPlaneDistance);
            minPlaneDistance = max(minPlaneDistance, 0.0);
        float maxPlaneDistance = max(lowerPlaneDistance, higherPlaneDistance);
        if (maxPlaneDistance < 0.0) return vec4(0.0);
        float planeDistanceDif = maxPlaneDistance - minPlaneDistance;

        #ifndef DEFERRED1
            float stepMult = 32.0;
        #elif CLOUD_QUALITY == 1
            float stepMult = 16.0;
        #elif CLOUD_QUALITY == 2
            float stepMult = 24.0;
        #elif CLOUD_QUALITY == 3
            float stepMult = 16.0;
        #endif
        
        stepMult = stepMult / sqrt(float(size));

        int sampleCount = int(planeDistanceDif / stepMult + dither + 1);
        int cloudSteps =  6;

        float wind = GetWind();
        
        vec3 traceAdd = nPlayerPos;
        if (layer == 1) traceAdd *= 8.0;
        if (layer == 2) traceAdd *= 8.0;
        if (layer == 3) traceAdd *= 14.0;

        vec3 tracePos = cameraPos + minPlaneDistance * nPlayerPos;
        tracePos += traceAdd * dither;

        float firstHitPos = 0.0;
        float VdotSM1 = max0(sunVisibility > 0.5 ? VdotS : - VdotS);
        float VdotSM1M = VdotSM1 * invRainFactor;
        float VdotSM2 = pow2(VdotSM1) * abs(sunVisibility - 0.5) * 2.0;
        float VdotSM3 = VdotSM2 * (2.5 + rainFactor) + 1.5 * rainFactor;

        #ifdef FIX_AMD_REFLECTION_CRASH
            sampleCount = min(sampleCount, 30); //BFARC
        #endif

        vec3 worldSunVec = normalize(mat3(gbufferModelViewInverse) * lightVec);
        float cosTheta = dot(worldSunVec, nPlayerPos);

        float sss = PhaseHG(cosTheta, 0.1) * 10.0;

        vec3 sunContribution = cloudLightColor;
        vec3 skyColor = GetSky(VdotU, VdotS, dither, true, false);

        float cloudNoise = 0.0;

        for (int i = 0; i < sampleCount; i++) {
            tracePos += traceAdd;

            if (layer == 1 && abs(tracePos.y - cloudAltitude) > cumulonimbusCloudStretch * 1.0) break;
            if (layer == 2 && abs(tracePos.y - cloudAltitude) > cumulusCloudStretch * 1.0) break;
            if (layer == 3 && abs(tracePos.y - cloudAltitude) > cumulusCloudStretch * 1.0) break;

            vec3 cloudPlayerPos = tracePos - cameraPos;
            float lTracePos = length(cloudPlayerPos);
            float lTracePosXZ = length(cloudPlayerPos.xz);
            float cloudMult = 16;

            if (lTracePosXZ > distanceThreshold) break;
            if (lTracePos > lViewPosM) {
                cloudMult = mix(cloudMult, skyMult0, step(0.7, skyFade));
                if (skyFade < 0.7 && lTracePos > lViewPosM) continue;
            }

            if (layer == 3) {
                cloudNoise = GetAltocumulusCloud(tracePos, cloudSteps, cloudAltitude, lTracePosXZ, cloudPlayerPos.y, noisePersistance, mult, size);
            } else if (layer == 2) {
                cloudNoise = GetCumulusCloud(tracePos, cloudSteps, cloudAltitude, lTracePosXZ, cloudPlayerPos.y, noisePersistance, mult, size);
            } else if (layer == 1) {
                cloudNoise = GetCumulonimbusCloud(tracePos, cloudSteps, cloudAltitude, lTracePosXZ, cloudPlayerPos.y, noisePersistance, mult, size);
            }


            if (cloudNoise > 0.3) {
                #if defined CLOUD_CLOSED_AREA_CHECK && SHADOW_QUALITY > -1
                    float shadowLength = min(shadowDistance, far) * 0.9166667;
                    if (shadowLength < lTracePos)
                    if (GetShadowOnCloud(tracePos, cameraPos, cloudAltitude, lowerPlaneAltitude, higherPlaneAltitude)) {
                        if (eyeBrightness.y <= 240) continue;
                    }
                #endif

                if (firstHitPos < 0.5) {
                    firstHitPos = lTracePos;
                    #if CLOUD_QUALITY == 1 && defined DEFERRED1
                        tracePos.y += 4.0 * (texture2D(noisetex, tracePos.xz * 0.001).r - 0.5);
                    #endif
                }

        
                float opacityFactor = min1(cloudNoise * 32.0);
                float ambientShadow = 0.0;
                float shadow = 0.0;

                if (layer == 1) {
                    ambientShadow = 1.0 - clamp(exp((tracePos.y - (cloudAltitude + cumulonimbusCloudStretch - 3.0)) / 100.0), 0.0, 1.0);
                } else if (layer == 2) {
                    ambientShadow = 1.1 - clamp(exp((tracePos.y - (cloudAltitude + cumulusCloudStretch - 3.0)) / 100.0), 0.0, 1.0);
                } else if (layer == 3) {
                    ambientShadow = 1.1 - clamp(exp((tracePos.y - (cloudAltitude + altocumulusCloudStretch - 3.0)) / 100.0), 0.0, 1.0);
                }

                if (layer == 1) {
                    shadow = SampleCloudShadow(tracePos, worldSunVec, dither, cloudSteps, cloudAltitude, cumulonimbusCloudStretch, size, 1) * 0.75;
                } else if (layer == 2) {
                    shadow = SampleCloudShadow(tracePos, worldSunVec, dither, cloudSteps, cloudAltitude, cumulusCloudStretch, size, 2) * 0.5;
                } else if (layer == 3) {
                    shadow = SampleCloudShadow(tracePos, worldSunVec, dither, cloudSteps, cloudAltitude, altocumulusCloudStretch, size, 3) * 0.4;
                }

                float stableDensity = clamp(cloudNoise, 0.7, 0.75);

                float powder      = 1.0 - exp(stableDensity * coeff * 0.33);
                float lessPowder  = mix(0.6, 1.0, powder);
                float skyAttenuation = exp(coeff * 0.5 * stableDensity * ambientShadow);

                vec3 colorSample = skyColor * skyAttenuation * lessPowder;

                float sunTerm1 = exp(coeff * shadow + powder);
                float sunTerm2 = exp(coeff * 0.3 * shadow + 1.0 * powder);

                vec3 directLight = sunContribution * (sunTerm1 + sunTerm2);
                colorSample += directLight;

                float distanceRatio = (distanceThreshold - lTracePosXZ) / distanceThreshold;
                float cloudDistanceFactor = clamp(distanceRatio, 0.0, 1.0) * 1.0;
                #ifndef DISTANT_HORIZONS
                    float cloudFogFactor = cloudDistanceFactor;
                #else
                    float cloudFogFactor = clamp(distanceRatio, 0.0, 1.0);
                #endif

                float skyMult1 = 1.0 - 0.2 * max(sunVisibility2, nightFactor);
                float skyMult2 = 1.0 - 0.33333;

                if (layer == 2) {
                    colorSample = mix(skyColor, colorSample * skyMult1, cloudFogFactor * skyMult2 * 0.6);
                } else if (layer == 1) {
                    colorSample = mix(skyColor, colorSample * skyMult1, cloudFogFactor * skyMult2 * 0.7);
                } else if (layer == 3) {
                    colorSample = mix(skyColor, colorSample * skyMult1, cloudFogFactor * skyMult2 * 0.5);
                }

                colorSample *= pow2(1.0 - maxBlindnessDarkness);

                volumetricClouds.rgb = mix(volumetricClouds.rgb, colorSample, 1.0 - min1(volumetricClouds.a));
                volumetricClouds.a += opacityFactor * pow((distanceThreshold - lTracePosXZ) / distanceThreshold, 0.5 + 10.0 * pow(abs(VdotSM1M), 90.0)) * cloudMult;

                if (volumetricClouds.a > 0.9) {
                    volumetricClouds.a = 1.0;
                    break;
                }
            }
        }

        if (volumetricClouds.a > 0.5) cloudLinearDepth = sqrt(firstHitPos / renderDistance);
        return volumetricClouds;
    #endif
}

vec4 GetClouds(inout float cloudLinearDepth, float skyFade, vec3 cameraPos, vec3 playerPos,
            float lViewPos, float VdotS, float VdotU, float dither, vec3 auroraBorealis, vec3 nightNebula) {

    vec4 clouds = vec4(0.0);

    vec3 nPlayerPos = normalize(playerPos);
    float lViewPosM = lViewPos < renderDistance * 1.5 ? lViewPos - 1.0 : 1000000000.0;
    float skyMult0 = pow2(skyFade * 3.333333 - 2.333333);

    float thresholdMix = pow2(clamp01(VdotU * 5.0));
    float thresholdF = mix(far, float(CLOUD_RENDER_DISTANCE), thresholdMix * 0.5 + 0.5);
    #ifdef DISTANT_HORIZONS
        thresholdF = max(thresholdF, renderDistance);
    #endif

    vec3 cloudColorMult = vec3(1.0);
    #if CLOUD_R != 100 || CLOUD_G != 100 || CLOUD_B != 100
        cloudColorMult *= vec3(CLOUD_R, CLOUD_G, CLOUD_B) * 0.01;
    #endif
    cloudAmbientColor *= cloudColorMult + rainFactor;
    cloudLightColor *= cloudColorMult * 0.5 + rainFactor;

    #if CLOUD_QUALITY == 3
        //cumulonimbus
        #ifdef CUMULONIMBUS
        clouds = GetVolumetricClouds(cumulonimbusAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                    cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                    CUMULONIMBUS_GRANULARITY, CUMULONIMBUS_MULT, CUMULONIMBUS_SIZE_MULT_M, 1);
        #endif

        #ifdef CUMULUS
            if (clouds.a == 0.0) {
                // cumulus
                clouds = GetVolumetricClouds(cumulusAlt, thresholdF * 1.25, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                            CUMULUS_GRANULARITY, CUMULUS_MULT, CUMULUS_SIZE_MULT_M, 2);
            }
        #endif

        #ifdef ALTOCUMULUS
            if (clouds.a == 0.0) {
                //altocumulus
                clouds = GetVolumetricClouds(altocumulusAlt, thresholdF * 1.5, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                            ALTOCUMULUS_GRANULARITY, ALTOCUMULUS_MULT, ALTOCUMULUS_SIZE_MULT_M, 3);
            }
        #endif
    #else
        // cumulus
        clouds = GetVolumetricClouds(cumulonimbusAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                    cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                    CUMULONIMBUS_GRANULARITY, CUMULONIMBUS_MULT, CUMULONIMBUS_SIZE_MULT_M, 1);

    #endif

    #ifdef ATM_COLOR_MULTS
        clouds.rgb *= sqrtAtmColorMult; // C72380KD - Reduced atmColorMult impact on some things
    #endif
    #ifdef MOON_PHASE_INF_ATMOSPHERE
        clouds.rgb *= moonPhaseInfluence;
    #endif

    #if AURORA_STYLE > 0
        clouds.rgb += auroraBorealis * 0.1;
    #endif
    #ifdef NIGHT_NEBULA
        clouds.rgb += nightNebula * 0.2;
    #endif

    return clouds;
}

vec4 GetCloudReflection(inout float cloudLinearDepth, float skyFade, vec3 cameraPos, vec3 playerPos,
            float lViewPos, float VdotS, float VdotU, float dither, vec3 auroraBorealis, vec3 nightNebula) {

    vec4 clouds = vec4(0.0);

    vec3 nPlayerPos = normalize(playerPos);
    float lViewPosM = lViewPos < renderDistance * 1.5 ? lViewPos - 1.0 : 1000000000.0;
    float skyMult0 = pow2(skyFade * 3.333333 - 2.333333);

    float thresholdMix = pow2(clamp01(VdotU * 5.0));
    float thresholdF = mix(far, float(CLOUD_RENDER_DISTANCE), thresholdMix * 0.5 + 0.5);
    #ifdef DISTANT_HORIZONS
        thresholdF = max(thresholdF, renderDistance);
    #endif

    vec3 cloudColorMult = vec3(1.0);
    #if CLOUD_R != 100 || CLOUD_G != 100 || CLOUD_B != 100
        cloudColorMult *= vec3(CLOUD_R, CLOUD_G, CLOUD_B) * 0.01;
    #endif
    cloudAmbientColor *= cloudColorMult * 0.5;
    cloudLightColor *= cloudColorMult * 0.5;

    // only do 1 layer for the reflections
    clouds = GetVolumetricClouds(cumulonimbusAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                    cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                    CUMULONIMBUS_GRANULARITY, CUMULONIMBUS_MULT, CUMULONIMBUS_SIZE_MULT_M, 1);

    #ifdef ATM_COLOR_MULTS
        clouds.rgb *= sqrtAtmColorMult; // C72380KD - Reduced atmColorMult impact on some things
    #endif

    #ifdef MOON_PHASE_INF_ATMOSPHERE
        clouds.rgb *= moonPhaseInfluence;
    #endif

    #if AURORA_STYLE > 0
        clouds.rgb += auroraBorealis * 0.1;
    #endif
    #ifdef NIGHT_NEBULA
        clouds.rgb += nightNebula * 0.2;
    #endif

    return clouds;
}