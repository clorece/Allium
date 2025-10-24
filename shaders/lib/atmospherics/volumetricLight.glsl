// Volumetric tracing from Robobo1221, highly modified

#define LQ_CLOUD
#define LQ_SKY

#include "/lib/colors/lightAndAmbientColors.glsl"

float GetDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

float GetDistX(float dist) {
    return (far * (dist - near)) / (dist * (far - near));
}

vec4 DistortShadow(vec4 shadowpos, float distortFactor) {
    shadowpos.xy *= 1.0 / distortFactor;
    shadowpos.z = shadowpos.z * 0.2;
    shadowpos = shadowpos * 0.5 + 0.5;

    return shadowpos;
}

//#ifdef VL_CLOUD_SHADOW 
#include "/lib/colors/skyColors.glsl"
#include "/lib/atmospherics/clouds/mainClouds.glsl"

// start of cloud shadow code, there should be more optimal/cheap ways to do this, if anyone wants to improve this, let me know.

#ifndef PI
#define PI 3.141592653589793
#endif

#ifndef sunAngularSize
const float sunAngularSize = 0.533333;
#endif

const float SUN_ANGULAR_RADIUS_RAD = (sunAngularSize * 0.5) * (PI / 180.0);
const float INV_SHADOW_DISTANCE = 1.0 / max(shadowDistance, 1.0);
const float EPSILON = 1e-4;

// ============================================================================
// CORE FUNCTIONS - Used by both implementations
// ============================================================================

int CloudShadowStepsLOD(float camDist) {
    // Branchless LOD: returns 3 for distant, 4 for close
    float t = clamp(camDist * INV_SHADOW_DISTANCE, 0.0, 1.0);
    return 3 + int(step(t, 0.66));
}

bool RaySlabIntersectY(float yCenter, float halfThickness,
                       vec3 ro, vec3 rd, out float tEnter, out float tExit)
{
    float yMin = yCenter - halfThickness;
    float yMax = yCenter + halfThickness;

    if (abs(rd.y) < EPSILON) {
        tEnter = 0.0;
        tExit  = 0.0;
        return (ro.y >= yMin && ro.y <= yMax);
    }

    float invRy = 1.0 / rd.y;
    float t0 = (yMin - ro.y) * invRy;
    float t1 = (yMax - ro.y) * invRy;
    tEnter = min(t0, t1);
    tExit  = max(t0, t1);
    return (tExit > 0.0 && tExit > max(tEnter, 0.0));
}

float LowerLayerDensityFast(vec3 p, int steps, vec3 cameraPos)
{
    float lTracePosXZ   = length((p - cameraPos).xz);
    float cloudPlayerY  = p.y - float(cumulusLayerAlt);

    float d = GetCumulusCloud(
        p,
        steps,
        cumulusLayerAlt,
        lTracePosXZ,
        cloudPlayerY,
        CUMULUS_CLOUD_GRANULARITY,
        1.0,
        (200.0 * 0.01)
    );

    return max(d, 0.0); // Branchless replacement for (d > 0.00001) ? d : 0.0
}

// ============================================================================
// VOLUMETRIC LIGHT VERSION - For light shaft integration
// ============================================================================

float CloudVLTransmittanceAt(vec3 worldPos, vec3 sunDir_ws, vec3 cameraPos, float jitter)
{
    
    float yCenter = float(cumulusLayerAlt);
    float halfH   = cumulusLayerStretch * 0.15;

    float tEnter, tExit;
    if (!RaySlabIntersectY(yCenter, halfH, worldPos, sunDir_ws, tEnter, tExit))
        return 1.0;

    float t0 = max(tEnter, 0.0);
    float t1 = max(tExit,  0.0);
    float lenInside = t1 - t0;
    if (lenInside <= EPSILON) return 1.0;

    float camDist = distance(cameraPos, worldPos);
    
    // Optimized step count: branchless selection
    float distThreshold = float(CLOUD_RENDER_DISTANCE) * 0.6;
    int maxS = 2 + int(step(camDist, distThreshold)); // Returns 2 if far, 3 if close
    maxS = min(maxS, 3);

    // Optimized step calculation
    float baseStep = (lenInside * 0.2) * mix(0.9, 1.1, fract(jitter * 43758.5453));
    float stepLen  = max(baseStep, lenInside / float(maxS));

    // Initialize ray marching
    vec3 stepVec = sunDir_ws * stepLen;
    vec3 p = worldPos + sunDir_ws * (t0 + stepLen * 0.5);
    //float tau = 0.0;

    float dens = LowerLayerDensityFast(p, maxS, cameraPos);
    float tau = dens * stepLen;
    p += stepVec;


    // Optimized transmittance calculation
    float T = exp(-1.6 * tau);
    T = pow(T, 0.105); // 0.1 * 1.05 = 0.105
    
    return clamp(T, 0.0, 1.0);
}


vec4 GetVolumetricLight(inout vec3 color, inout float vlFactor, vec3 translucentMult, float lViewPos0, float lViewPos1, vec3 nViewPos, float VdotL, float VdotU, float VdotS, vec2 texCoord, float z0, float z1, float dither) {
    vec4 volumetricLight = vec4(0.0);
    float vlMult = 10.0 - maxBlindnessDarkness;

    #if SHADOW_QUALITY > -1
        // Optifine for some reason doesn't provide correct shadowMapResolution if Shadow Quality isn't 1x
        vec2 shadowMapResolutionM = textureSize(shadowtex0, 0);
    #endif

    #ifdef OVERWORLD
        vec3 vlColor = lightColor * 0.15;
        vec3 vlColorReducer = vec3(1.0);
        float vlSceneIntensity = isEyeInWater != 1 ? vlFactor : 1.0;

        #ifdef SPECIAL_BIOME_WEATHER
            vlSceneIntensity = mix(vlSceneIntensity, 1.0, inDry * rainFactor);
        #endif

        if (sunVisibility < 0.5) {
            vlSceneIntensity = 0.0;
            
            float vlMultNightModifier = 0.6 + 0.4 * max0(far - lViewPos1) / far;
            #ifdef SPECIAL_PALE_GARDEN_LIGHTSHAFTS
                vlMultNightModifier = mix(vlMultNightModifier, 1.0, inPaleGarden);
            #endif
            vlMult *= vlMultNightModifier;

            vlColor = normalize(pow(vlColor, vec3(1.0 - max0(1.0 - 1.5 * nightFactor))));
            vlColor *= 0.0766 + 0.0766 * vsBrightness;

        } else {
            vlColorReducer = 1.0 / sqrt(vlColor);
        }

        #ifdef SPECIAL_PALE_GARDEN_LIGHTSHAFTS
            vlSceneIntensity = mix(vlSceneIntensity, 1.0, inPaleGarden);
            vlMult *= 1.0 + (3.0 * inPaleGarden) * (1.0 - sunVisibility);
        #endif

        float rainyNight = (1.0 - sunVisibility) * rainFactor;
        float VdotLM = max((VdotL + 1.0) / 3.0, 0.0);
        float VdotUmax0 = max(VdotU, 0.0);
        float VdotUM = mix(pow2(1.0 - VdotUmax0), 1.0, 0.5 * vlSceneIntensity);
              VdotUM = smoothstep1(VdotUM);
              VdotUM = pow(VdotUM, min(lViewPos1 / far, 1.0) * (3.0 - 2.0 * vlSceneIntensity));
        vlMult *= mix(VdotUM * VdotLM * 3.0, 1.0, 0.4 * rainyNight) * vlTime;
        vlMult *= mix(invNoonFactor2 * 3.875 + 2.525, 1.0, max(vlSceneIntensity, rainFactor2));

        #if LIGHTSHAFT_QUALI == 4
            int sampleCount = vlSceneIntensity < 0.5 ? 30 : 50;
        #elif LIGHTSHAFT_QUALI == 3
            int sampleCount = vlSceneIntensity < 0.5 ? 15 : 30;
        #elif LIGHTSHAFT_QUALI == 2
            int sampleCount = vlSceneIntensity < 0.5 ? 10 : 20;
        #elif LIGHTSHAFT_QUALI == 1
            int sampleCount = vlSceneIntensity < 0.5 ? 6 : 12;
        #endif

        #ifdef LIGHTSHAFT_SMOKE
            float totalSmoke = 0.0;
        #endif
    #else
        translucentMult = sqrt(translucentMult); // Because we pow2() the vl result in composite for the End dimension

        float vlSceneIntensity = 0.0;

        #ifndef LOW_QUALITY_ENDER_NEBULA
            int sampleCount = 16;
        #else
            int sampleCount = 10;
        #endif
    #endif

    float addition = 1.0;
    float maxDist = 0.0;

    float depth0 = GetDepth(z0);
    float depth1 = GetDepth(z1);
    //#ifndef CLOUD_SHADOWS
        //maxDist = mix(max(far * 1.5, renderDistance * 0.15) * 0.55, 80.0, vlSceneIntensity);
        maxDist = mix(max(far, 96.0) * 0.55, 80.0, vlSceneIntensity);
    //#else
    //    bool  isSky   = (z1 == 1.0);
    //    maxDist = isSky ? min(far * 1.25, renderDistance * 0.15)
    //                        : min(depth1, far * 0.95);
    //#endif

    #if WATER_FOG_MULT != 100
        if (isEyeInWater == 1) {
            #define WATER_FOG_MULT_M WATER_FOG_MULT * 0.001;
            maxDist /= WATER_FOG_MULT_M;
        }
    #endif

    float sampleMultIntense = isEyeInWater != 1 ? 1.0 : 0.85;
    float distMult = maxDist / (sampleCount + 1.0);


    float viewFactor = 1.0 - 0.7 * pow2(dot(nViewPos.xy, nViewPos.xy));

    #ifdef END
        if (z0 == 1.0) depth0 = 1000.0;
        if (z1 == 1.0) depth1 = 1000.0;
    #endif

    //Fast but inaccurate perspective distortion approximation
    maxDist *= viewFactor;
    distMult *= viewFactor;
    
    float horizonBoost = clamp(1.0 - abs(VdotU), 0.0, 1.0);
    maxDist += mix(0.0, 2.0, horizonBoost);

    // Keep sample brightness uniform regardless of maxDist
    float sampleMult = 1.0 / float(sampleCount);

    #ifdef OVERWORLD
        float maxCurrentDist = min(depth1, maxDist);
    #else
        float maxCurrentDist = min(depth1, far);
    #endif

    for (int i = 0; i < sampleCount; i++) {
        float currentDist = (i + dither) * distMult + addition;

        if (currentDist > maxCurrentDist) break;

        vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, GetDistX(currentDist), 1.0) * 2.0 - 1.0);
        viewPos /= viewPos.w;
        vec4 wpos = gbufferModelViewInverse * viewPos;
        vec3 playerPos = wpos.xyz / wpos.w;
        #ifdef END
            #ifdef DISTANT_HORIZONS
                playerPos *= sqrt(renderDistance / far);
            #endif
           //vec4 enderBeamSample = vec4(DrawEnderBeams(VdotU, playerPos), 1.0);
           vec4 enderBeamSample = vec4(0.0);
            //enderBeamSample /= sampleCount;
        #endif

        float shadowSample = 1.0;
        vec3 vlSample = vec3(1.0);


        #if SHADOW_QUALITY > -1
            wpos = shadowModelView * wpos;
            wpos = shadowProjection * wpos;
            wpos /= wpos.w;
            float distb = sqrt(wpos.x * wpos.x + wpos.y * wpos.y);
            float distortFactor = 1.0 - shadowMapBias + distb * shadowMapBias;
            vec4 shadowPosition = DistortShadow(wpos,distortFactor);
            //shadowPosition.z += 0.0001;

            #ifdef OVERWORLD
                float percentComplete = currentDist / maxDist;
                float sampleMult = mix(percentComplete * 3.0, sampleMultIntense, max(rainFactor, vlSceneIntensity));
                if (currentDist < 5.0) sampleMult *= smoothstep1(clamp(currentDist / 5.0, 0.0, 1.0));
                sampleMult /= sampleCount;
            #endif

            if (length(shadowPosition.xy * 2.0 - 1.0) < 1.0) {
                // 28A3DK6 We need to use texelFetch here or a lot of Nvidia GPUs can't get a valid value
                shadowSample = texelFetch(shadowtex0, ivec2(shadowPosition.xy * shadowMapResolutionM), 0).x;
                shadowSample = clamp((shadowSample-shadowPosition.z)*65536.0,0.0,1.0);

                vlSample = vec3(shadowSample);

                #if SHADOW_QUALITY >= 1
                    if (shadowSample == 0.0) {
                        float testsample = shadow2D(shadowtex1, shadowPosition.xyz).z;
                        if (testsample == 1.0) {
                            vec3 colsample = texture2D(shadowcolor1, shadowPosition.xy).rgb * 4.0;
                            colsample *= colsample;
                            vlSample = colsample;
                            shadowSample = 1.0;
                            #ifdef OVERWORLD
                                vlSample *= vlColorReducer;
                            #endif
                        }
                    } else {
                        #ifdef OVERWORLD
                            if (translucentMult != vec3(1.0) && currentDist > depth0) {
                                vec3 tinter = vec3(1.0);
                                if (isEyeInWater == 1) {
                                    vec3 translucentMultM = translucentMult * 2.8;
                                    tinter = pow(translucentMultM, vec3(sunVisibility * 3.0 * clamp01(playerPos.y * 0.03)));
                                } else {
                                    tinter = 0.1 + 0.9 * pow2(pow2(translucentMult * 1.7));
                                }
                                vlSample *= mix(vec3(1.0), tinter, clamp01(oceanAltitude - cameraPosition.y));
                            }
                        #endif

                        if (isEyeInWater == 1 && translucentMult == vec3(1.0)) vlSample = vec3(0.0);
                    }
                #endif
            }
        #endif

        if (currentDist > depth0) vlSample *= translucentMult;

        
        #ifdef CLOUD_SHADOWS
            if (isEyeInWater != 1) {
                vec3 worldPos  = playerPos + cameraPosition;
                vec3 sunDir_ws = normalize(mat3(gbufferModelViewInverse) * lightVec);
                float cloudT   = CloudVLTransmittanceAt(worldPos, sunDir_ws, cameraPosition, dither);

                //cloudT *= 1.0; // for screenshots

                vlSample     *= cloudT;
                //shadowSample *= cloudT;
                //vlSample = max(vlSample, vec3(0.0));
            }
        #endif
        

        #ifdef OVERWORLD
            #ifdef LIGHTSHAFT_SMOKE
                vec3 smokePos  = 0.00055 * (playerPos + cameraPosition);
                vec3 smokeWind = frameTimeCounter * vec3(0.002, 0.001, 0.0) * 0.1;

                float smoke = 0.65 * Noise3D(smokePos + smokeWind)
                            + 0.25 * Noise3D((smokePos - smokeWind) * 3.0)
                            + 0.10 * Noise3D((smokePos + smokeWind) * 9.0);
                smoke = smoothstep1(smoothstep1(smoothstep1(smoke)));

                float smokeMask = max(smoke - 0.0, 0.0);
                smokeMask = pow(smokeMask, 3.0);           // hardness = 3.0
                smokeMask *= 1.0;

                vlSample     *= smokeMask;
                shadowSample *= smokeMask;

                volumetricLight += vec4(vlSample, shadowSample) * sampleMult * smokeMask;
            #else
                volumetricLight += vec4(vlSample, shadowSample) * sampleMult;
            #endif
        #else
            volumetricLight += vec4(vlSample, shadowSample) * enderBeamSample;
        #endif
    }

    float smokeVisibility = 10.0;

    #ifdef LIGHTSHAFT_SMOKE
        volumetricLight += pow(totalSmoke / volumetricLight.a, min(smokeVisibility - volumetricLight.a, smokeVisibility));
        volumetricLight.rgb /= pow(0.5, 1.0 - volumetricLight.a);
    #endif

    // Decision of Intensity for Scene Aware Light Shafts //
    #if defined OVERWORLD && LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1
        if (viewWidth + viewHeight - gl_FragCoord.x - gl_FragCoord.y < 1.5) {
            if (frameCounter % int(0.06666 / frameTimeSmooth + 0.5) == 0) {
                int salsX = 5;
                int salsY = 5;
                float heightThreshold = 6.0;

                vec2 viewM = 1.0 / vec2(salsX, salsY);
                float salsSampleSum = 0.0;
                int salsSampleCount = 0;
                for (float i = 0.25; i < salsX; i++) {
                    for (float h = 0.45; h < salsY; h++) {
                        vec2 coord = 0.3 + 0.4 * viewM * vec2(i, h);
                        ivec2 icoord = ivec2(coord * shadowMapResolutionM);
                        float salsSample = texelFetch(shadowtex0, icoord, 0).x;
                        if (salsSample < 0.55) {
                            float sampledHeight = texture2D(shadowcolor1, coord).a;
                            if (sampledHeight > 0.0) {
                                sampledHeight = max0(sampledHeight - 0.25) / 0.05;
                                salsSampleSum += sampledHeight;
                                salsSampleCount++;
                            }
                        }
                    }
                }

                float salsCheck = salsSampleSum / salsSampleCount;
                int reduceAmount = 2;

                int skyCheck = 0;
                for (float i = 0.1; i < 1.0; i += 0.2) {
                    skyCheck += int(texelFetch(depthtex0, ivec2(view.x * i, view.y * 0.9), 0).x == 1.0);
                }
                if (skyCheck >= 4) {
                    salsCheck = 0.0;
                    reduceAmount = 3;
                }

                if (salsCheck > heightThreshold) {
                    vlFactor = min(vlFactor + OSIEBCA, 0.25);
                } else {
                    vlFactor = max(vlFactor - OSIEBCA * reduceAmount, 0.0);
                }
            }
        } else vlFactor = 0.0;
    #endif

    #ifdef OVERWORLD
        vlColor = pow(vlColor, vec3(0.5 + 0.5 * invNoonFactor * invRainFactor + 0.3 * rainFactor));
        vlColor *= 1.0 - (0.5 + 0.5 * noonFactor) * rainFactor - 0.5 * rainyNight;

        #if LIGHTSHAFT_DAY_I != 100 || LIGHTSHAFT_NIGHT_I != 100 || LIGHTSHAFT_RAIN_I != 100
            #define LIGHTSHAFT_DAY_IM LIGHTSHAFT_DAY_I * 0.01
            #define LIGHTSHAFT_NIGHT_IM LIGHTSHAFT_NIGHT_I * 0.01
            #define LIGHTSHAFT_RAIN_IM LIGHTSHAFT_RAIN_I * 0.01

            if (isEyeInWater == 0) {
                #if LIGHTSHAFT_DAY_I != 100 || LIGHTSHAFT_NIGHT_I != 100
                    vlColor.rgb *= mix(LIGHTSHAFT_NIGHT_IM, LIGHTSHAFT_DAY_IM, sunVisibility);
                #endif
                #if LIGHTSHAFT_RAIN_I != 100
                    vlColor.rgb *= mix(1.0, LIGHTSHAFT_RAIN_IM, rainFactor);
                #endif
            }
        #endif

        volumetricLight.rgb *= vlColor;
    #endif

    volumetricLight.rgb *= vlMult;
    volumetricLight = max(volumetricLight, vec4(0.0));

    #ifdef DISTANT_HORIZONS
        if (isEyeInWater == 0) {
            #ifdef OVERWORLD
                float lViewPosM = lViewPos0;
                if (z0 >= 1.0) {
                    float z0DH = texelFetch(dhDepthTex, texelCoord, 0).r;
                    vec4 screenPosDH = vec4(texCoord, z0DH, 1.0);
                    vec4 viewPosDH = dhProjectionInverse * (screenPosDH * 2.0 - 1.0);
                    viewPosDH /= viewPosDH.w;
                    lViewPosM = length(viewPosDH.xyz);
                }
                lViewPosM = min(lViewPosM, renderDistance * 0.1);

                float dhVlStillIntense = max(max(vlSceneIntensity, rainFactor), nightFactor * 0.5);

                volumetricLight *= mix(0.0003 * lViewPosM, 1.0, dhVlStillIntense) * 3.0;
            #else
                volumetricLight *= min1(lViewPos1 * 3.0 / renderDistance);
            #endif
        }
    #endif

    #ifndef DISTANT_HORIZONS
        volumetricLight *= 0.5;
    #else
        volumetricLight *= 2.0;
    #endif

    return volumetricLight;
}
