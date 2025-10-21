// ---------------------- LAYERS ---------------------- //
//#define CUMULONIMBUS // not yet implemented / broken
#define CUMULUS
//#define ALTOCUMULUS

#define CUMULONIMBUS_CLOUD_MULT 0.4
#define CUMULONIMBUS_CLOUD_SIZE_MULT 2.25
#define CUMULONIMBUS_CLOUD_SIZE_MULT_M (200.0 * 0.01)
#define CUMULONIMBUS_CLOUD_GRANULARITY 0.4
#define CUMULONIMBUS_CLOUD_ALT 180
#define CUMULONIMBUS_CLOUD_HEIGHT 128.0
#define CUMULONIMBUS_CLOUD_COVERAGE 1.5

#define CUMULUS_CLOUD_MULT 0.4
#define CUMULUS_CLOUD_SIZE_MULT 2.25
#define CUMULUS_CLOUD_SIZE_MULT_M (200.0 * 0.01)
#define CUMULUS_CLOUD_GRANULARITY 0.4
#define CUMULUS_CLOUD_ALT 180
#define CUMULUS_CLOUD_HEIGHT 128.0
#define CUMULUS_CLOUD_COVERAGE 1.5

#define ALTOCUMULUS_CLOUD_MULT 0.4
#define ALTOCUMULUS_CLOUD_SIZE_MULT 54.0
#define ALTOCUMULUS_CLOUD_SIZE_MULT_M (200.0 * 0.01)
#define ALTOCUMULUS_CLOUD_GRANULARITY 0.4
#define ALTOCUMULUS_CLOUD_ALT 320
#define ALTOCUMULUS_CLOUD_HEIGHT 92.0
#define ALTOCUMULUS_CLOUD_COVERAGE 1.5

// ---------------------- LIGHTING & QUALITY ---------------------- //

#define CUMULONIMBUS_STEP_QUALITY 2.5
#define CUMULUS_STEP_QUALITY 3.0
#define ALTOCUMULUS_STEP_QUALITY 3.0
#define CLOUD_SHADING_QUALITY 30
#define CLOUD_SHADING_STRENGTH 9.0
#define CLOUD_RENDER_DISTANCE 1024
#define CLOUD_AO_STRENGTH 0.6
#define CLOUD_AO_SAMPLES 6
#define CLOUD_MULTISCATTER 2.0
#define CLOUD_MULTISCATTER_OCTAVES 3

// ---------------------- CURVATURE ---------------------- //

#define CURVED_CLOUDS
#define PLANET_RADIUS 100000
#define CURVATURE_STRENGTH 2.0

const int cumulonimbusLayerAlt = int(CUMULONIMBUS_CLOUD_ALT);
const int cumulusLayerAlt = int(CUMULUS_CLOUD_ALT);
const int altocumulusLayerAlt = int(ALTOCUMULUS_CLOUD_ALT);

float cumulonimbusLayerStretch = CUMULONIMBUS_CLOUD_HEIGHT;
float cumulonimbusLayerHeight = cumulonimbusLayerStretch * 2.0;
float cumulusLayerStretch = CUMULUS_CLOUD_HEIGHT;
float cumulusLayerHeight = cumulusLayerStretch * 2.0;
float altocumulusLayerStretch = ALTOCUMULUS_CLOUD_HEIGHT;
float altocumulusLayerHeight = altocumulusLayerStretch * 2.0;

#ifdef LQ_CLOUD
    #define CLOUD_SHADING_STRENGTH_MULT ((CLOUD_SHADING_STRENGTH * 0.85) / CLOUD_SHADING_STRENGTH)
#else
    #define CLOUD_SHADING_STRENGTH_MULT CLOUD_SHADING_STRENGTH
#endif

#include "/lib/colors/lightAndAmbientColors.glsl"
#include "/lib/colors/cloudColors.glsl"
#include "/lib/atmospherics/sky.glsl"

#if SHADOW_QUALITY > -1 || VL_CLOUD_SHADOW
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

#if CLOUD_UNBOUND_SIZE_MULT != 100
    #define CLOUD_UNBOUND_SIZE_MULT_M CLOUD_UNBOUND_SIZE_MULT * 0.01
#endif

#include "/lib/atmospherics/clouds/cloudHelpers.glsl"
#include "/lib/atmospherics/clouds/cumulus.glsl"
#include "/lib/atmospherics/clouds/altocumulus.glsl"
#include "/lib/atmospherics/clouds/cloudLighting.glsl"

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
    int layer)
{
    vec4 volumetricClouds = vec4(0.0);

    #if CLOUD_QUALITY <= 1
        return volumetricClouds;
    #else
        float higherPlaneAltitude, lowerPlaneAltitude;

        //float higherPlaneAltitude = cloudAltitude + cumulusLayerStretch;
        //float lowerPlaneAltitude = cloudAltitude - cumulusLayerStretch;

        if (layer == 1) {
            higherPlaneAltitude = cloudAltitude + cumulonimbusLayerStretch;
            lowerPlaneAltitude  = cloudAltitude - cumulonimbusLayerStretch;
        } else if (layer == 2) {
            higherPlaneAltitude = cloudAltitude + cumulusLayerStretch;
            lowerPlaneAltitude  = cloudAltitude - cumulusLayerStretch;
        } else if (layer == 3) {
            higherPlaneAltitude = cloudAltitude + altocumulusLayerStretch;
            lowerPlaneAltitude  = cloudAltitude - altocumulusLayerStretch;
        }

        float lowerPlaneDistance = (lowerPlaneAltitude - cameraPos.y) / nPlayerPos.y;
        float higherPlaneDistance = (higherPlaneAltitude - cameraPos.y) / nPlayerPos.y;
        float minPlaneDistance = max(min(lowerPlaneDistance, higherPlaneDistance), 0.0);
        float maxPlaneDistance = max(lowerPlaneDistance, higherPlaneDistance);
        if (maxPlaneDistance < 0.0) return vec4(0.0);
        float planeDistanceDif = maxPlaneDistance - minPlaneDistance;

        float baseStep = 16.0 / sqrt(300.0);
        int sampleCount = int(planeDistanceDif / baseStep + dither + 1);

        #ifndef LQ_CLOUD
            int cloudSteps = CLOUD_SHADING_QUALITY;
        #else
            int cloudSteps = 2;
        #endif

        #ifdef FIX_AMD_REFLECTION_CRASH
            sampleCount = min(sampleCount, 30);
        #endif

        vec3 rayStep;

        if (layer == 1) {
            rayStep = nPlayerPos * (int(CUMULONIMBUS_CLOUD_HEIGHT) / CUMULONIMBUS_STEP_QUALITY);
            #ifdef LQ_CLOUD || DISTANT_HORIZONS
                rayStep = nPlayerPos * (int(CUMULONIMBUS_CLOUD_HEIGHT) / 1.0);
            #endif
        } else if (layer == 2) {
            rayStep = nPlayerPos * (int(CUMULUS_CLOUD_HEIGHT) / CUMULUS_STEP_QUALITY);
            #ifdef LQ_CLOUD || DISTANT_HORIZONS
                rayStep = nPlayerPos * (int(CUMULUS_CLOUD_HEIGHT) / 1.0);
            #endif
        } else if (layer == 3) {
            rayStep = nPlayerPos * (int(ALTOCUMULUS_CLOUD_HEIGHT) / ALTOCUMULUS_STEP_QUALITY);
            #ifdef LQ_CLOUD || DISTANT_HORIZONS
                rayStep = nPlayerPos * (int(ALTOCUMULUS_CLOUD_HEIGHT) / 1.0);
            #endif
        }

        float stepLen = length(rayStep);
        vec3 tracePos = cameraPos + minPlaneDistance * nPlayerPos + rayStep * dither;

        vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * lightVec);
        float mu = dot(sunDir, -nPlayerPos);
        float phaseHG = PhaseHG(mu, 0.85);

        const float BREAK_THRESHOLD = 0.08;
        float sigma_s = 0.2 * mult;
        float sigma_t = 0.1 * mult;

        float transmittance = 1.0;
        float firstHitPos = 0.0;
        float lastLxz = 0.0;
        float prevDens = 0.0;
        vec2 scatter = vec2(0.0);
        vec3 multiScatter = vec3(0.0);

        for (int i = 0; i < sampleCount; i++) {
            if (transmittance < BREAK_THRESHOLD) break;

            tracePos += rayStep;

            
            float yCurved = tracePos.y;
            if (layer == 1 && abs(yCurved - float(cloudAltitude)) > cumulonimbusLayerStretch * 3.0) break;
            if (layer == 2 && abs(yCurved - float(cloudAltitude)) > cumulusLayerStretch * 3.0) break;
            if (layer == 3 && abs(yCurved - float(cloudAltitude)) > altocumulusLayerStretch * 3.0) break;
            //if (layer == 1 && abs(tracePos.y - cloudAltitude) > cumulonimbusLayerStretch * 1.0) break;
            //if (layer == 2 && abs(tracePos.y - cloudAltitude) > cumulusLayerStretch * 1.0) break;
            //if (layer == 3 && abs(tracePos.y - cloudAltitude) > altocumulusLayerStretch * 1.0) break;

            vec3 toPos = tracePos - cameraPos;
            float lTracePos = length(toPos);
            float lTracePosXZ = length(toPos.xz);
            lastLxz = lTracePosXZ;

            if (lTracePosXZ > distanceThreshold) break;
            if (lTracePos > lViewPosM && skyFade < 0.7) continue;

            float density;

            if (layer == 1) {
                // nothing yet...
            } else if (layer == 2) {
                density = GetCumulusCloud(tracePos, cloudSteps, cloudAltitude,
                                           lTracePosXZ, toPos.y,
                                           noisePersistance, 1.0, size);
            } else if (layer == 3) {
                density = GetAltocumulusCloud(tracePos, cloudSteps, cloudAltitude,
                                           lTracePosXZ, toPos.y,
                                           noisePersistance, 1.0, size);
            }

            if (density <= 0.5) continue;

            if (firstHitPos <= 0.0) firstHitPos = lTracePos;

            float shadow, ao;

            if (layer == 1) {
                // nothing yet...
            } else if (layer == 2) {
                shadow = SampleCloudShadow(tracePos, sunDir, dither, cloudSteps,
                                            cloudAltitude, cumulusLayerStretch, size, 2);
                
                ao = SampleCloudAO(tracePos, cloudAltitude, cumulusLayerStretch, size, dither, 2);
            } else if (layer == 3) {
                shadow = SampleCloudShadow(tracePos, sunDir, dither, cloudSteps,
                                            cloudAltitude, altocumulusLayerStretch, size, 3) * 0.65;
                
                ao = SampleCloudAO(tracePos, cloudAltitude, altocumulusLayerStretch, size, dither, 3);
            }

            float lightTrans = 1.0 - clamp(shadow * CLOUD_SHADING_STRENGTH_MULT + noonFactor * 0.2, 0.0, 1.0);

            float skylight = clamp((yCurved - lowerPlaneAltitude) /
                      max(higherPlaneAltitude - lowerPlaneAltitude, 1e-3), 0.0, 1.0);

            float extinction = density * sigma_t;
            float stepT = exp2(-extinction * stepLen * 1.442695041);
            float integral = (sigma_t > 1e-5) ? (1.0 - stepT) / sigma_t : stepLen;

            vec2 powderMul = GetPowder(density);
            float powderSun = powderMul.x;
            float powderSky = powderMul.y;

            float directStep = sigma_s * phaseHG * lightTrans * powderSun;
            float skyStep = sigma_s * 0.0795775 * (0.4 + 0.6 * skylight) * powderSky;

            scatter.x += transmittance * integral * directStep * 1.15 * ao;
            scatter.y += transmittance * integral * skyStep * 1.15 * ao;

            scatter.y += transmittance * (1.0 - stepT) * (0.3 + 0.7 * skylight) * 0.06 * ao;

            vec3 multiScatterStep = GetMultiscatter(density, lightTrans, lightColor, mu);
            multiScatter += transmittance * integral * multiScatterStep * ao;

            transmittance *= stepT;
            float stepFactor = mix(1.6, 0.8, smoothstep(0.06, 0.35, max(density, prevDens)));
            tracePos += rayStep * (stepFactor - 1.0);
            prevDens = density;
        }

        vec3 skyColor = GetSky(VdotU, VdotS, dither, true, false);
        vec3 directSun = (lightColor * 128.4) * (scatter.x);
        vec3 ambSky = (skyColor * 2.0) * scatter.y;
        vec3 cloudCol = directSun + ambSky + multiScatter;

        float cloudFogFactor = 0.0;
        
        if (firstHitPos > 0.0) {
            float fadeDistance = distanceThreshold * 0.9;
            float distF = clamp((fadeDistance - lastLxz) / fadeDistance, 0.0, 1.0);
            cloudFogFactor = pow(distF, 4.0) ;
        }

        float skyMult1 = 1.0 - 0.2 * max(sunVisibility2, nightFactor);
        float skyMult2 = 1.0 - 0.33333;
        vec3 finalColor;
        //finalColor = mix(skyColor, cloudCol * skyMult1, cloudFogFactor * skyMult2 * 0.75);

        if (layer == 1) {
            // nothing yet...
        } else if (layer == 2) {
            finalColor = mix(skyColor, cloudCol * skyMult1, cloudFogFactor * skyMult2 * 0.6);
        } else if (layer == 3) {
            finalColor = mix(skyColor, cloudCol * skyMult1, cloudFogFactor * skyMult2 * 0.35);
        }

        finalColor *= pow2(1.0 - maxBlindnessDarkness);

        volumetricClouds.rgb = finalColor;
        volumetricClouds.a = 1.0 - transmittance;

        if (volumetricClouds.a < 0.9) return vec4(0.0);

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
        thresholdF = max(thresholdF, renderDistance * 0.75);
    #endif

    #if CLOUD_QUALITY == 3
        //cumulus
        #ifdef CUMULUS
        clouds = GetVolumetricClouds(cumulusLayerAlt, thresholdF * 1.25, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                            CUMULUS_CLOUD_GRANULARITY, CUMULUS_CLOUD_MULT, CUMULUS_CLOUD_SIZE_MULT_M, 2);
        #endif

        #ifdef CUMULONIMBUS
            if (clouds.a == 0.0) {
                // cumulonimbus
                clouds = GetVolumetricClouds(cumulusLayerAlt, thresholdF * 1.25, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                            CUMULUS_CLOUD_GRANULARITY, CUMULUS_CLOUD_MULT, CUMULUS_CLOUD_SIZE_MULT_M, 1);
            }
        #endif

        #ifdef ALTOCUMULUS
            if (clouds.a == 0.0) {
                //altocumulus
                clouds = GetVolumetricClouds(altocumulusLayerAlt, thresholdF * 1.25, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                            ALTOCUMULUS_CLOUD_GRANULARITY, ALTOCUMULUS_CLOUD_MULT, ALTOCUMULUS_CLOUD_SIZE_MULT_M, 3);
            }
        #endif
    #else
        // cumulus
        clouds = GetVolumetricClouds(cumulusLayerAlt, thresholdF * 1.25, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                            CUMULUS_CLOUD_GRANULARITY, CUMULUS_CLOUD_MULT, CUMULUS_CLOUD_SIZE_MULT_M, 2);

    #endif

    #ifdef ATM_COLOR_MULTS
        clouds.rgb *= sqrtAtmColorMult;
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

    clouds += (dither - 0.5) / 64;
    
    return clouds;
}