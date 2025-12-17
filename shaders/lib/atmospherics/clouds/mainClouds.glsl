#define CUMULUS

#define CUMULUS_CLOUD_MULT 0.4
#define CUMULUS_CLOUD_SIZE_MULT 4.0 // [1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0 4.25 4.5 4.75 5.0]
#define CUMULUS_CLOUD_SIZE_MULT_M (200.0 * 0.01)
#define CUMULUS_CLOUD_GRANULARITY 0.4
#define CUMULUS_CLOUD_ALT 210 // [0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200 210 220 230 240 250 260 270 280 290 300 310 320 330 340 350 360 370 380 390 400]
#define CUMULUS_CLOUD_HEIGHT 164.0 // [32.0 48.0 64.0 96.0 128.0 164.0 192.0 256.0 384.0]
#define CUMULUS_CLOUD_COVERAGE 1.4 // [1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define CUMULUS_QUALITY 0.5 // [0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define CUMULUS_STEP_QUALITY (CUMULUS_QUALITY * 4.0)

#define CLOUD_LIGHTING_QUALITY 7 // [7 14 30]
#define CLOUD_AO_STRENGTH 1.0
#define CLOUD_AO_SAMPLES 3 // [3 6 9]
#define CLOUD_MULTISCATTER 4.5
#define CLOUD_MULTISCATTER_OCTAVES 3 // [1 2 3]

#define CURVED_CLOUDS
#define PLANET_RADIUS 100000
#define CURVATURE_STRENGTH 2.0

#ifdef DISTANT_HORIZONS
    #define CLOUD_RENDER_DISTANCE 1024
#else
    #define CLOUD_RENDER_DISTANCE 4096
#endif

#ifdef LQ_CLOUD
    #define CLOUD_SHADING_STRENGTH_MULT (CLOUD_SHADING_STRENGTH * 0.001)
#else
    #define CLOUD_SHADING_STRENGTH_MULT CLOUD_SHADING_STRENGTH
#endif

#if CLOUD_UNBOUND_SIZE_MULT != 100
    #define CLOUD_UNBOUND_SIZE_MULT_M CLOUD_UNBOUND_SIZE_MULT * 0.01
#endif

const int cumulusLayerAlt = int(CUMULUS_CLOUD_ALT);
float cumulusLayerStretch = CUMULUS_CLOUD_HEIGHT;
float cumulusLayerHeight = cumulusLayerStretch * 2.0;

#include "/lib/colors/lightAndAmbientColors.glsl"
#include "/lib/colors/cloudColors.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/clouds/cloudHelpers.glsl"
#include "/lib/atmospherics/clouds/cumulus.glsl"

#if SHADOW_QUALITY > -1 || VL_CLOUD_SHADOW
    vec3 GetShadowOnCloudPosition(vec3 tracePos, vec3 cameraPos) {
        vec3 worldPos = PlayerToShadow(tracePos - cameraPos);
        float distB = sqrt(worldPos.x * worldPos.x + worldPos.y * worldPos.y);
        float distortFactor = 1.0 - shadowMapBias + distB * shadowMapBias;
        vec3 shadowPosition = vec3(vec2(worldPos.xy / distortFactor), worldPos.z * 0.2);
        return shadowPosition * 0.5 + 0.5;
    }

    bool GetShadowOnCloud(vec3 tracePos, vec3 cameraPos, int cloudAltitude, float lowerPlaneAltitude, float higherPlaneAltitude) {
        vec3 shadowPosition0 = GetShadowOnCloudPosition(tracePos, cameraPos);
        if (length(shadowPosition0.xy * 2.0 - 1.0) < 1.0) {
            float shadowDepth = shadow2D(shadowtex0, shadowPosition0).z;
            if (shadowDepth == 0.0) return true;
        }
        return false;
    }
#endif

#if defined DEFERRED1 || defined DEFERRED5 || defined DH_WATER || defined GBUFFERS_WATER || defined DEFERRED
#include "/lib/atmospherics/clouds/cloudLighting.glsl"

vec4 GetVolumetricClouds(int cloudAltitude, 
    float distanceThreshold, 
    inout float cloudLinearDepth, 
    float skyFade, 
    float skyMult0, 
    vec3 cameraPos, 
    vec3 normalizedPlayerPos, 
    float linearViewPosModified, 
    float viewDotSun, 
    float viewDotUp, 
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
        float higherPlaneAltitude = cloudAltitude + cumulusLayerStretch;
        float lowerPlaneAltitude  = cloudAltitude - cumulusLayerStretch;

        float lowerPlaneDistance = (lowerPlaneAltitude - cameraPos.y) / normalizedPlayerPos.y;
        float higherPlaneDistance = (higherPlaneAltitude - cameraPos.y) / normalizedPlayerPos.y;
        float minPlaneDistance = max(min(lowerPlaneDistance, higherPlaneDistance), 0.0);
        float maxPlaneDistance = max(lowerPlaneDistance, higherPlaneDistance);
        
        if (maxPlaneDistance < 0.0) return vec4(0.0);
        
        float planeDistanceDif = maxPlaneDistance - minPlaneDistance;

        // 1. Fixed Sample Count
        // We decide the count purely based on your quality setting. 
        // No geometry math here. Just "Higher Quality = More Loops".
        int sampleCount = int(64.0 * CUMULUS_QUALITY); 
        
        // Safety clamps
        #ifdef LQ_CLOUD
            sampleCount = 16;
        #endif
        
        // If you need the AMD crash fix, this method is actually safer
        // because we will stretch the steps to fit the limit.
        #ifdef FIX_AMD_REFLECTION_CRASH
            sampleCount = min(sampleCount, 30);
        #endif

        // Ensure we have at least a few steps to prevent divide-by-zero
        sampleCount = max(sampleCount, 5);

        // 2. Adaptive Step Size
        // We stretch the ray step to ensure we cover the ENTIRE distance 
        // in exactly 'sampleCount' steps.
        float stepLen = planeDistanceDif / float(sampleCount);
        vec3 rayStep = normalizedPlayerPos * stepLen;

        #ifndef LQ_CLOUD
             int cloudSteps = CLOUD_LIGHTING_QUALITY;
        #else
             int cloudSteps = 2;
        #endif
        
        #ifdef LQ_CLOUD || DISTANT_HORIZONS
            rayStep = normalizedPlayerPos * (int(CUMULUS_CLOUD_HEIGHT) / 1.0);
        #endif

        //float stepLen = length(rayStep);
        vec3 tracePos = cameraPos + minPlaneDistance * normalizedPlayerPos + rayStep * dither;

        vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * lightVec);
        float mu = dot(sunDir, -normalizedPlayerPos);
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

        #ifdef TAA
            float noiseMult = 1.0;
        #else
            float noiseMult = 0.1;
        #endif
        vec2 roughCoord = gl_FragCoord.xy / 128.0;
        vec3 roughNoise = vec3(
            texture2D(noisetex, roughCoord).r,
            texture2D(noisetex, roughCoord + 0.09375).r,
            texture2D(noisetex, roughCoord + 0.1875).r
        );
        roughNoise = fract(roughNoise + vec3(dither, dither * goldenRatio, dither * pow2(goldenRatio)));
        roughNoise = noiseMult * (roughNoise - vec3(0.5));
        
        //clouds.rgb += roughNoise;

        for (int i = 0; i < sampleCount; i++) {
            if (transmittance < BREAK_THRESHOLD) break;

            tracePos += rayStep;

            vec3 toPos = tracePos - cameraPos;
            float lTracePosXZ = length(toPos.xz);
            float drop = curvatureDrop(lTracePosXZ);
            
            float yCurved = tracePos.y + drop; 

            if (layer == 2 && abs(yCurved - float(cloudAltitude)) > cumulusLayerStretch * 3.0) break;

            float lTracePos = length(toPos);
            lastLxz = lTracePosXZ;

            if (lTracePosXZ > distanceThreshold) break;
            if (lTracePos > linearViewPosModified && skyFade < 0.7) continue;

            float density = GetCumulusCloud(tracePos, cloudSteps, cloudAltitude,
                                            lTracePosXZ, yCurved, 
                                            noisePersistance, 1.0, size);

            if (density <= 0.5) continue;

            if (firstHitPos <= 0.0) firstHitPos = lTracePos;

            #ifdef LQ_CLOUD
                float shadow = CalculateCloudShadow(tracePos, sunDir, dither, cloudSteps,
                                                    cloudAltitude, cumulusLayerStretch, size, 2) * 0.35;
            #else
                float shadow = CalculateCloudShadow(tracePos, sunDir, dither, cloudSteps,
                                                    cloudAltitude, cumulusLayerStretch, size, 2);
            #endif
            
            float ao = CalculateCloudAO(tracePos, cloudAltitude, cumulusLayerStretch, size, dither, 2);

            shadow -= rainFactor * 0.05;

            #if CLOUD_LIGHTING_QUALITY == 7
                float shadowMult = 2.4;
            #elif CLOUD_LIGHTING_QUALITY == 14
                float shadowMult = 5.05;
            #elif CLOUD_LIGHTING_QUALITY == 30
                float shadowMult = 11.55;
            #else
                float shadowMult = 1.0;
            #endif

            float lightTrans = 1.0 - clamp(shadow * shadowMult + noonFactor * 0.1, 0.0, 1.0) - rainFactor * 0.1;

            float skylight = clamp((yCurved - lowerPlaneAltitude) /
                      max(higherPlaneAltitude - lowerPlaneAltitude, 1e-3), 0.0, 1.0);

            float blendedDensity = (density + prevDens) * 0.5; 
            float extinction = blendedDensity * sigma_t;
            float stepT = exp2(-extinction * stepLen * 1.442695041);
            float integral = (sigma_t > 1e-5) ? (1.0 - stepT) / sigma_t : stepLen;

            vec2 powderMul = CalculatePowderEffect(density);
            float powderSun = powderMul.x;
            float powderSky = powderMul.y;

            float directStep = sigma_s * phaseHG * lightTrans * powderSun;
            float skyStep = sigma_s * 0.0795775 * (0.4 + 0.6 * skylight) * powderSky;

            scatter.x += transmittance * integral * directStep * 1.15 * ao;
            scatter.y += transmittance * integral * skyStep * 1.15 * ao;

            scatter.y += transmittance * (1.0 - stepT) * (0.3 + 0.7 * skylight) * 0.06 * ao;

            vec3 multiScatterStep = CalculateMultiScattering(density, lightTrans, lightColor, mu);
            multiScatter += transmittance * integral * multiScatterStep * ao;

            transmittance *= stepT;
            float stepFactor = mix(1.0, 0.5, smoothstep(0.1, 0.35, max(density, prevDens)));
            tracePos += rayStep * (stepFactor - 1.0);
            prevDens = density;
        }
        

        vec3 skyColor = GetSky(viewDotUp, viewDotSun, dither, true, false);
        vec3 directSun = (lightColor * 164) * (scatter.x);
        vec3 ambSky = (skyColor * 2.0) * scatter.y;
        vec3 cloudCol = directSun + ambSky + multiScatter;
        cloudCol = pow(cloudCol, vec3(2.2)) * 0.02;
        cloudCol = mix(cloudCol, pow(cloudCol, vec3(1.0 / 1.2)) * 10.0, nightFactor);

        #ifdef LQ_CLOUD
            cloudCol *= 8.0 - nightFactor * 7.0;
        #endif

        float cloudFogFactor = 0.0;
        
        if (firstHitPos > 0.0) {
            float fadeDistance = distanceThreshold * 1.0;
            float distF = clamp((fadeDistance - lastLxz) / fadeDistance, 0.0, 1.0);
            cloudFogFactor = pow(distF, 1.25) ;
        }

        float skyMult1 = 1.0 - 0.2 * max(sunVisibility2, nightFactor);
        float skyMult2 = 1.0 - 0.33333;
        vec3 finalColor = mix(skyColor, cloudCol * skyMult1, cloudFogFactor * skyMult2 * 0.3);

        finalColor *= pow2(1.0 - maxBlindnessDarkness);

        volumetricClouds.rgb = finalColor;
        volumetricClouds.a = 1.01 - transmittance;

        //if (volumetricClouds.a < 0.1) return vec4(0.0);

        return volumetricClouds;
    #endif
}

vec4 GetClouds(inout float cloudLinearDepth, float skyFade, vec3 cameraPos, vec3 playerPos,
               float lViewPos, float VdotS, float VdotU, float dither, vec3 auroraBorealis, vec3 nightNebula) {

    vec4 clouds = vec4(0.0);
    
    vec3 normalizedPlayerPos = normalize(playerPos);
    float linearViewPosModified = lViewPos < renderDistance * 1.5 ? lViewPos - 1.0 : 1000000000.0;
    float skyMult0 = pow2(skyFade * 3.333333 - 2.333333);

    float thresholdMix = pow2(clamp01(VdotU * 5.0));
    float thresholdF = mix(far, float(CLOUD_RENDER_DISTANCE), thresholdMix * 0.5 + 0.5);
    #ifdef DISTANT_HORIZONS
        thresholdF = max(thresholdF, renderDistance);
    #endif

    #if CLOUD_QUALITY == 3
        #ifdef CUMULUS
        clouds = GetVolumetricClouds(cumulusLayerAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                            cameraPos, normalizedPlayerPos, lViewPos, VdotS, VdotU, dither,
                                            CUMULUS_CLOUD_GRANULARITY, CUMULUS_CLOUD_MULT, CUMULUS_CLOUD_SIZE_MULT_M, 2);
        #endif
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

    clouds = max(clouds, vec4(0.0));

    return clouds;
}
#endif