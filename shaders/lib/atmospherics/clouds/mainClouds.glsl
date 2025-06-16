#include "/lib/colors/lightAndAmbientColors.glsl"
#include "/lib/colors/cloudColors.glsl"
#include "/lib/atmospherics/sky.glsl"

float InterleavedGradientNoiseForClouds() {
    float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
    #ifdef TAA
        return fract(n + goldenRatio * mod(float(frameCounter), 3600.0));
    #else
        return fract(n);
    #endif
}

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

#ifdef CLOUDS_REIMAGINED
    #include "/lib/atmospherics/clouds/reimaginedClouds.glsl"
#endif
#ifdef CLOUDS_UNBOUND
    #include "/lib/atmospherics/clouds/unboundClouds.glsl"
#endif

vec4 GetClouds(inout float cloudLinearDepth, float skyFade, vec3 cameraPos, vec3 playerPos,
               float lViewPos, float VdotS, float VdotU, float dither, vec3 auroraBorealis, vec3 nightNebula) {
    
    #define CLOUD_RENDER_DISTANCE 1536 //[1024 1536 2048]

    vec4 clouds = vec4(0.0);

    vec3 nPlayerPos = normalize(playerPos);
    float lViewPosM = lViewPos < renderDistance * 1.5 ? lViewPos - 1.0 : 1000000000.0;
    float skyMult0 = pow2(skyFade * 3.333333 - 2.333333);

    float thresholdMix = pow2(clamp01(VdotU * 5.0));
    float thresholdF = mix(far, float(CLOUD_RENDER_DISTANCE), thresholdMix * 0.5 + 0.5);
    #ifdef DISTANT_HORIZONS
        thresholdF = max(thresholdF, renderDistance);
    #endif

    #ifdef CLOUDS_REIMAGINED
        cloudAmbientColor *= 1.0 - 0.25 * rainFactor;
    #endif

    vec3 cloudColorMult = vec3(1.0);
    #if CLOUD_R != 100 || CLOUD_G != 100 || CLOUD_B != 100
        cloudColorMult *= vec3(CLOUD_R, CLOUD_G, CLOUD_B) * 0.01;
    #endif
    cloudAmbientColor *= cloudColorMult;
    cloudLightColor *= cloudColorMult;

    int maxCloudAlt = max(cloudAlt1i, cloudAlt2i) * 2;
    int minCloudAlt = min(cloudAlt1i, cloudAlt2i);
    #define CUMULUS_MULT 0.5 //[0.4 0.45 0.5 0.55 0.6 0.65 0.7]
    #define CUMULUS_SIZE_MULT 600.0 //[100.0 200.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0]
        #define CUMULUS_SIZE_MULT_M CUMULUS_SIZE_MULT * 0.01
    #define CUMULUS_GRANULARITY 0.5 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
    #define CUMUMLUS_SHAPING 1.0 //[1.0 1.1 1.2 1.3]
    #define ALTOCUMULUS_MULT 0.45 //[0.4 0.45 0.5 0.55 0.6 0.65 0.7]
        #define ALTOCUMULUS_SIZE_MULT_M ALTOCUMULUS_SIZE_MULT * 0.01
    #define ALTOCUMULUS_SIZE_MULT 300.0 //[100.0 200.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0]
    #define ALTOCUMULUS_GRANULARITY 0.55 //[0.1 0.2 0.3 0.4 0.5 0.55 0.6 0.7 0.8 0.9 1.0]
    #define ALTOCUMULUS_SHAPING 1.0 //[1.0 1.005 1.01 1.015 1.02 1.025 1.03 1.035]

    #if CLOUD_QUALITY == 3
        if (abs(cameraPos.y - minCloudAlt) < abs(cameraPos.y - maxCloudAlt)) {
            clouds = GetVolumetricClouds(minCloudAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither, CUMULUS_GRANULARITY, CUMULUS_MULT, CUMUMLUS_SHAPING, CUMULUS_SIZE_MULT_M);
            if (clouds.a == 0.0) {
                clouds = GetVolumetricClouds(maxCloudAlt, thresholdF * 2.0, cloudLinearDepth, skyFade, skyMult0,
                                                cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither, ALTOCUMULUS_GRANULARITY, ALTOCUMULUS_MULT, ALTOCUMULUS_SHAPING, ALTOCUMULUS_SIZE_MULT_M);
            }
        } else {
            clouds = GetVolumetricClouds(maxCloudAlt, thresholdF * 2.0, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither, ALTOCUMULUS_GRANULARITY, ALTOCUMULUS_MULT, ALTOCUMULUS_SHAPING, ALTOCUMULUS_SIZE_MULT_M);
            if (clouds.a == 0.0) {
                clouds = GetVolumetricClouds(minCloudAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                                cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither, CUMULUS_GRANULARITY, CUMULUS_MULT, CUMUMLUS_SHAPING, CUMULUS_SIZE_MULT_M);
            }
        }
    #else
        clouds = GetVolumetricClouds(minCloudAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                        cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither, CUMULUS_GRANULARITY, CUMULUS_MULT, CUMUMLUS_SHAPING, CUMULUS_SIZE_MULT_M);
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