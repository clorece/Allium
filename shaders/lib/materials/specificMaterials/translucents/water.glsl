#define WATER_PARALLAX

// ============================== Step 1: Color Prep ============================== //
#if MC_VERSION >= 11300
    #if WATERCOLOR_MODE >= 2
        vec3 glColorM = glColor.rgb;

        #if WATERCOLOR_MODE >= 3
            glColorM.g = max(glColorM.g, 0.39);
        #endif

        #ifdef GBUFFERS_WATER
            translucentMultCalculated = true;
            translucentMult.rgb = normalize(sqrt2(glColor.rgb));
            translucentMult.g *= 0.88;
        #endif

        glColorM = sqrt1(glColorM) * vec3(1.0, 0.85, 0.8);
    #else
        vec3 glColorM = vec3(0.43, 0.6, 0.8);
    #endif

    #if WATER_STYLE < 3
        vec3 colorPM = pow2(colorP.rgb);
        color.rgb = colorPM * glColorM;
    #else
        vec3 colorPM = vec3(0.25);
        color.rgb = 0.375 * glColorM;
    #endif
#else
    #if WATER_STYLE < 3
        color.rgb = mix(color.rgb, vec3(GetLuminance(color.rgb)), 0.88);
        color.rgb = pow2(color.rgb) * vec3(2.3, 3.5, 3.1) * 0.9;
    #else
        color.rgb = vec3(0.13, 0.2, 0.27);
    #endif
#endif

#ifdef WATERCOLOR_CHANGED
    color.rgb *= vec3(WATERCOLOR_RM, WATERCOLOR_GM, WATERCOLOR_BM);
#endif
// ============================== End of Step 1 ============================== //

#define PHYSICS_OCEAN_INJECTION
#if defined GENERATED_NORMALS && (WATER_STYLE >= 2 || defined PHYSICS_OCEAN) && !defined DH_WATER
    noGeneratedNormals = true;
#endif

#if defined GBUFFERS_WATER || defined DH_WATER
    lmCoordM.y = min(lmCoord.y * 1.07, 1.0); // Iris/Sodium skylight inconsistency workaround
    
    float fresnel2 = pow2(fresnel);
    float fresnel4 = pow2(fresnel2);

    // ============================== Step 2: Water Normals ============================== //

    reflectMult = 1.0;

    #if WATER_MAT_QUALITY >= 3
        materialMask = OSIEBCA * 241.0; // Water
    #endif

    #if WATER_MAT_QUALITY >= 2 || WATER_STYLE >= 2
        #define WATER_SPEED_MULT_M WATER_SPEED_MULT * 0.018
        float rawWind = frameTimeCounter * WATER_SPEED_MULT_M;
        vec2 wind = vec2(rawWind, 0.0);
        vec3 worldPos = playerPos + cameraPosition;
        vec2 waterPos = worldPos.xz;
        #if WATER_STYLE < 3 && defined GBUFFERS_WATER
            float blockRes = absMidCoordPos.x * atlasSize.x * 2.0;
            waterPos = floor(waterPos * blockRes) / blockRes;
        #endif
        waterPos = 0.032 * (waterPos + worldPos.y * 2.0);
    #endif

    #if WATER_STYLE >= 2 || RAIN_PUDDLES >= 1 && WATER_STYLE == 1 && WATER_MAT_QUALITY >= 2
        vec3 normalMap = vec3(0.0, 0.0, 1.0);
        
            vec2 waterPosM = waterPos;

            #if WATER_SIZE_MULT != 100
                #define WATER_SIZE_MULT_M WATER_SIZE_MULT * 0.01
                waterPosM *= WATER_SIZE_MULT_M;
            #endif

            #define WATER_BUMPINESS_M WATER_BUMPINESS * 0.8

           #if WATER_STYLE >= 2
            #ifdef WATER_PARALLAX
                const int steps = 8;
                const float stepSize = inversesqrt(float(steps));
                const float maxHeight = 0.1;

                vec3 rayStep = stepSize * vec3(viewVector.xy, viewVector.z) / viewVector.z;

                vec3 offset = vec3(0.0);
                float height = 0.0;

                for (int i = 0; i < steps; ++i) {
                    vec2 sampleUV = waterPosM + offset.xy;
                    height = dot(GetCombinedWaves(sampleUV, wind), vec2(0.5)) * maxHeight;

                    if (offset.z >= height) break;

                    float dz = height - offset.z;
                    offset += rayStep * dz;
                }

                height = dot(GetCombinedWaves(waterPosM + offset.xy, wind), vec2(0.5)) * maxHeight;
                float dz = height - offset.z;
                offset.xy += rayStep.xy * dz;

                waterPosM += offset.xy;
            #endif

            vec2 finalNormal = GetCombinedWaves(waterPosM, wind);
            normalMap.xy = finalNormal * 6.0 * (1.0 - 0.7 * fresnel) * WATER_BUMPINESS_M;
        #endif

            normalMap.xy *= 0.03 * lmCoordM.y + 0.01;
            normalMap.z = sqrt(1.0 - (pow2(normalMap.x) + pow2(normalMap.y)));
            normalM = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));

            vec3 vector = reflect(nViewPos, normalize(normalM));
            float norMix = pow2(pow2(pow2(1.0 - max0(dot(normal, vector))))) * 0.5;
            normalM = mix(normalM, normal, norMix); // Fixes normals pointing inside water

            float fresnelP = fresnel;
            fresnel = clamp(1.0 + dot(normalM, nViewPos), 0.0, 1.0);
    #endif
    // ============================== End of Step 2 ============================== //

    // ============================== Step 3: Water Material Features ============================== //
    #if WATER_MAT_QUALITY >= 2
        if (isEyeInWater != 1) {
            // Noise Coloring //
            float noise = texture2D(noisetex, (waterPos + wind) * 0.25).g;
                  noise = noise - 0.5;
                  noise *= 0.25;
            color.rgb = pow(color.rgb, vec3(1.0 + noise));

            // Water Alpha //
            #ifdef GBUFFERS_WATER
                float depthT = texelFetch(depthtex1, texelCoord, 0).r;
            #elif defined DH_WATER
                float depthT = texelFetch(dhDepthTex1, texelCoord, 0).r;
            #endif
            vec3 screenPosT = vec3(screenPos.xy, depthT);
            #ifdef TAA
                vec3 viewPosT = ScreenToView(vec3(TAAJitter(screenPosT.xy, -0.5), screenPosT.z));
            #else
                vec3 viewPosT = ScreenToView(screenPosT);
            #endif
            float lViewPosT = length(viewPosT);
            float lViewPosDifM = lViewPos - lViewPosT;

            #if WATER_STYLE < 3
                color.a = sqrt1(color.a);
            #else
                color.a = 0.98;
            #endif

            #ifdef DISTANT_HORIZONS
                if (depthT == 1.0) color.a *= smoothstep(far, far * 0.9, lViewPos);
            #endif

            #if WATER_FOG_MULT != 100
                #define WATER_FOG_MULT_M WATER_FOG_MULT * 0.01;
                lViewPosDifM *= WATER_FOG_MULT_M;
            #endif

            float waterFog = max0(1.0 - exp(lViewPosDifM * 0.075));
            color.a *= 0.25 + 0.75 * waterFog;

            #if defined BRIGHT_CAVE_WATER && WATER_ALPHA_MULT < 200
                // For better water visibility in caves and some extra color pop outdoors
                color.rgb *= 2.5 - sqrt2(waterFog) - 0.5 * lmCoordM.y;
            #endif

            #if WATER_ALPHA_MULT != 100
                #define WATER_ALPHA_MULT_M 100.0 / WATER_ALPHA_MULT
                color.a = pow(color.a, WATER_ALPHA_MULT_M);
            #endif
            ////

            // Water Foam //
            #if WATER_FOAM_I > 0 && defined GBUFFERS_WATER
                if (NdotU > 0.99) {
                    vec3 matrixM = vec3(
                        gbufferModelViewInverse[0].y,
                        gbufferModelViewInverse[1].y,
                        gbufferModelViewInverse[2].y
                    );
                    float playerPosTY = dot(matrixM, viewPosT) + gbufferModelViewInverse[3].y;
                    float yPosDif = playerPosTY - playerPos.y;

                    #if WATER_STYLE < 3 && MC_VERSION >= 11300
                        float dotColorPM = dot(colorPM, colorPM);
                        float foamThreshold = min(pow2(dotColorPM) * 1.6, 1.2);
                    #else
                        float foamThreshold = pow2(texture2D(noisetex, waterPos * 4.0 + wind * 0.5).g) * 1.6;
                    #endif
                    float foam = pow2(clamp((foamThreshold + yPosDif) / foamThreshold, 0.0, 1.0));
                    #ifndef END
                        foam *= 0.4 + 0.25 * lmCoord.y;
                    #else
                        foam *= 0.6;
                    #endif
                    foam *= clamp((fract(worldPos.y) - 0.7) * 10.0, 0.0, 1.0);

                    vec4 foamColor = vec4(0.9, 0.95, 1.05, 1.0);

                    #define WATER_FOAM_IM WATER_FOAM_I * 0.01
                    #if WATER_FOAM_I < 100
                        foam *= WATER_FOAM_IM;
                    #elif WATER_FOAM_I > 100
                        foamColor *= WATER_FOAM_IM;
                    #endif

                    color = mix(color, foamColor, foam);
                    reflectMult = 1.0 - foam;
                }
            #endif
            ////
        } else { // Underwater
            noDirectionalShading = true;

            reflectMult = 0.5;

            #if MC_VERSION < 11300 && WATER_STYLE >= 3
                color.a = 0.7;
            #endif

            #ifdef GBUFFERS_WATER
                #if WATER_STYLE == 1
                    translucentMult.rgb *= 1.0 - fresnel4;
                #else
                    translucentMult.rgb *= 1.0 - 0.9 * max(0.5 * sqrt(fresnel4), fresnel4);
                #endif
            #endif
        }
    #else
        shadowMult = vec3(0.0);
    #endif
    // ============================== End of Step 3 ============================== //

    // ============================== Step 4: Final Tweaks ============================== //
    reflectMult *= 0.5 + 0.5 * NdotUmax0;

    color.a = mix(color.a, 1.0, fresnel4);

    #ifdef GBUFFERS_WATER
        #if WATER_STYLE == 3 || WATER_STYLE == 2 && SUN_MOON_STYLE >= 2
            smoothnessG = 1.0;

            const float WATER_BUMPINESS_M2 = min(WATER_BUMP_MED * WATER_BUMP_SMALL * WATER_BUMPINESS * 0.65, 1.0);
            vec2 lightNormalP = WATER_BUMPINESS_M2 * ((texture2D(gaux4, waterPosM + wind).rg - 0.5) + 0.5 * (texture2D(gaux4, waterPosM * 2.0 - 2.0 * wind).rg - 0.5));
            vec3 lightNormal = normalize(vec3(lightNormalP, 1.0) * tbnMatrix);
            highlightMult = dot(lightNormal, lightVec);
            highlightMult = max0(highlightMult) / max(dot(normal, lightVec), 0.17);
            highlightMult = mix(pow2(pow2(highlightMult * 1.1)), 1.0, min1(sqrt(miplevel) * 0.45)) * 0.24;
        #else
            smoothnessG = 0.5;

            highlightMult = min(pow2(pow2(dot(colorP.rgb, colorP.rgb) * 0.4)), 0.5);
            highlightMult *= (16.0 - 15.0 * fresnel2) * (sunVisibility > 0.5 ? 0.85 : 0.425);
        #endif
    #endif
    // ============================== End of Step 4 ============================== //
#endif