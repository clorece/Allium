/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

#if DETAIL_QUALITY > 2
    #define SKY_ILLUMINATION
#endif

//#define SKY_ILLUMINATION_VIEW

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

in vec3 normal;

flat in vec3 upVec, sunVec;

#if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
    flat in float vlFactor;
#endif

uniform vec2 pixel;

//Pipeline Constants//
const bool colortex0MipmapEnabled = true;

#include "/lib/commonVariables.glsl"
#include "/lib/commonFunctions.glsl"



#if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
#else
    float vlFactor = 0.0;
#endif

//Common Functions//

#ifdef TEMPORAL_FILTER
    float GetApproxDistance(float depth) {
        return near * far / (far - depth * far);
    }

    // Previous frame reprojection from Chocapic13
    vec2 Reprojection(vec3 pos, vec3 cameraOffset) {
        pos = pos * 2.0 - 1.0;

        vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
        viewPosPrev /= viewPosPrev.w;
        viewPosPrev = gbufferModelViewInverse * viewPosPrev;

        vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
        previousPosition = gbufferPreviousModelView * previousPosition;
        previousPosition = gbufferPreviousProjection * previousPosition;
        return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
    }

    vec3 FHalfReprojection(vec3 pos) {
        pos = pos * 2.0 - 1.0;

        vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
        viewPosPrev /= viewPosPrev.w;
        viewPosPrev = gbufferModelViewInverse * viewPosPrev;

        return viewPosPrev.xyz;
    }

    vec2 SHalfReprojection(vec3 playerPos, vec3 cameraOffset) {
        vec4 proPos = vec4(playerPos + cameraOffset, 1.0);
        vec4 previousPosition = gbufferPreviousModelView * proPos;
        previousPosition = gbufferPreviousProjection * previousPosition;
        return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
    }
#endif

//Includes//
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/fog/mainFog.glsl"
#include "/lib/colors/skyColors.glsl"

#if AURORA_STYLE > 0
    #include "/lib/atmospherics/auroraBorealis.glsl"
#endif

#ifdef NIGHT_NEBULA
    #include "/lib/atmospherics/nightNebula.glsl"
#endif

#ifdef VL_CLOUDS_ACTIVE
    #include "/lib/atmospherics/clouds/mainClouds.glsl"
#endif

#ifdef PBR_REFLECTIONS
    #include "/lib/materials/materialMethods/reflections.glsl"
#endif

#ifdef END
    #include "/lib/atmospherics/enderStars.glsl"   

    vec3 GetEndSun(vec3 viewDir, float VdotS) {
        float sunAngularSize = 0.009; // ~0.53 degrees
        float cosAngle = cos(sunAngularSize);

        // Sun disc (sharp)
        float disc = smoothstep(cosAngle - 0.0003, cosAngle + 0.0003, VdotS);

        // Subtle glare just around the disc (tight power falloff)
        float glare = pow(max(VdotS, 0.0), 500.0);
        glare *= 1.0 - disc; // Remove glare inside the disc

        // Final color
        vec3 sunColor = vec3(1.0, 0.97, 0.9); // white with warmth
        vec3 sun = sunColor * (disc * 40.0 + glare * 0.5); // Bright core, soft faint glow

        return sun;
    }

    vec3 GetEndBackgroundColor(vec3 viewDir, float VdotS) {
        vec3 baseColor = vec3(0.02);
        float glow = smoothstep(0.9, 1.0, -VdotS);

        vec3 glowColor = vec3(0.15, 0.15, 0.15);

        return baseColor + glow * glowColor;
    }
#endif

#ifdef WORLD_OUTLINE
    #include "/lib/misc/worldOutline.glsl"
#endif

#ifdef DARK_OUTLINE
    #include "/lib/misc/darkOutline.glsl"
#endif

#ifdef ATM_COLOR_MULTS
    #include "/lib/colors/colorMultipliers.glsl"
#endif
#ifdef MOON_PHASE_INF_ATMOSPHERE
    #include "/lib/colors/moonPhaseInfluence.glsl"
#endif

#ifdef DISTANT_LIGHT_BOKEH
    #include "/lib/misc/distantLightBokeh.glsl"
#endif

#ifdef NETHER
vec3 ambientColor = vec3(0.5, 0.21, 0.01);
#endif

#define MIN_LIGHT_AMOUNT 1.0

#include "/lib/lighting/indirectLighting.glsl"

vec3 textureCatmullRom(sampler2D colortex, vec2 texcoord, vec2 view) {
        vec2 position = texcoord * view;
        vec2 centerPosition = floor(position - 0.5) + 0.5;
        vec2 f = position - centerPosition;
        vec2 f2 = f * f;
        vec2 f3 = f * f2;

        float c = 0.7;
        vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
        vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
        vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
        vec2 w3 =         c  * f3 -                c * f2;

        vec2 w12 = w1 + w2;
        vec2 tc12 = (centerPosition + w2 / w12) / view;

        vec2 tc0 = (centerPosition - 1.0) / view;
        vec2 tc3 = (centerPosition + 2.0) / view;
        vec4 color = vec4(texture2DLod(colortex, vec2(tc12.x, tc0.y ), 0).rgb, 1.0) * (w12.x * w0.y ) +
                    vec4(texture2DLod(colortex, vec2(tc0.x,  tc12.y), 0).rgb, 1.0) * (w0.x  * w12.y) +
                    vec4(texture2DLod(colortex, vec2(tc12.x, tc12.y), 0).rgb, 1.0) * (w12.x * w12.y) +
                    vec4(texture2DLod(colortex, vec2(tc3.x,  tc12.y), 0).rgb, 1.0) * (w3.x  * w12.y) +
                    vec4(texture2DLod(colortex, vec2(tc12.x, tc3.y ), 0).rgb, 1.0) * (w12.x * w3.y );
        return color.rgb / color.a;
    }

//Program//
void main() {
    vec3 color = texelFetch(colortex0, texelCoord, 0).rgb;

    float z0 = texelFetch(depthtex0, texelCoord, 0).r;

    vec4 screenPos = vec4(texCoord, z0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    float lViewPos = length(viewPos);
    vec3 nViewPos = normalize(viewPos.xyz);
    vec3 playerPos = ViewToPlayer(viewPos.xyz);
    vec3 worldPos = playerPos + cameraPosition;

    float dither = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 128.0).b;
    vec3 dither2 = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 128.0).xyz;
    #if defined TAA || defined TEMPORAL_FILTER
        dither = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
        dither2.x = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
        dither2.y = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
        dither2.z = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
    #endif

    #ifdef ATM_COLOR_MULTS
        atmColorMult = GetAtmColorMult();
        sqrtAtmColorMult = sqrt(atmColorMult);
    #endif

    float VdotU = dot(nViewPos, upVec);
    float VdotS = dot(nViewPos, sunVec);
    float VdotM = dot(nViewPos, -sunVec);
    float skyFade = 0.0;
    vec3 waterRefColor = vec3(0.0);
    vec3 auroraBorealis = vec3(0.0);
    vec3 nightNebula = vec3(0.0);

    #ifdef TEMPORAL_FILTER
        vec4 refToWrite = vec4(0.0);
    #endif

    if (z0 < 1.0) {
        #ifdef DISTANT_LIGHT_BOKEH
            int dlbo = 1;
            vec3 dlbColor = color;
            dlbColor += texelFetch(colortex0, texelCoord + ivec2( 0, dlbo), 0).rgb;
            dlbColor += texelFetch(colortex0, texelCoord + ivec2( 0,-dlbo), 0).rgb;
            dlbColor += texelFetch(colortex0, texelCoord + ivec2( dlbo, 0), 0).rgb;
            dlbColor += texelFetch(colortex0, texelCoord + ivec2(-dlbo, 0), 0).rgb;
            dlbColor = max(color, dlbColor * 0.2);
            float dlbMix = GetDistantLightBokehMix(lViewPos);
            color = mix(color, dlbColor, dlbMix);
        #endif

        #if GLOBAL_ILLUMINATION >= 0 || defined WORLD_OUTLINE || defined TEMPORAL_FILTER
            float linearZ0 = GetLinearDepth(z0);
        #endif

        vec4 texture6 = texelFetch(colortex6, texelCoord, 0);
        bool entityOrHand = z0 < 0.56;
        int materialMaskInt = int(texture6.g * 255.1);
        float intenseFresnel = 0.0;
        float smoothnessD = texture6.r;
        vec3 reflectColor = vec3(1.0);

        float skyLightFactor = texture6.b;
        //int foliage = int(texture6.a * 1.1);
        vec3 texture5 = texelFetch(colortex5, texelCoord, 0).rgb;
        vec3 normalM = mat3(gbufferModelView) * texture5;

        float albedoS = texelFetch(colortex10, texelCoord, 0).a;

        float foliage = texelFetch(colortex6, texelCoord, 0).a;
        bool isFoliage = foliage > 0.5;
        
        //color.rgb = foliage > 1.0 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        //if (isFoliage) color.rgb = vec3(0.0, 1.0, 0.0);

        float ao = 1.0;
        float colorMultInv = 1.0;

        if (materialMaskInt <= 240) {
            #ifdef IPBR
                #include "/lib/materials/materialHandling/deferredMaterials.glsl"
            #elif defined CUSTOM_PBR
                #if RP_MODE == 2 // seuspbr
                    float metalness = materialMaskInt / 240.0;

                    intenseFresnel = metalness;
                #elif RP_MODE == 3 // labPBR
                    float metalness = float(materialMaskInt >= 230);

                    intenseFresnel = materialMaskInt / 240.0;
                #endif
                reflectColor = mix(reflectColor, color.rgb / max(color.r + 0.00001, max(color.g, color.b)), metalness);
            #endif
        } else {
            if (materialMaskInt == 254) { // No SSAO, No TAA
                ao = 1.0;
                entityOrHand = true;
            }
        }

        #ifdef PBR_REFLECTIONS

            float fresnel = clamp(1.0 + dot(normalM, nViewPos), 0.0, 1.0);

            float fresnelFactor = (1.0 - smoothnessD) * 0.7;
            float fresnelM = max(fresnel - fresnelFactor, 0.0) / (1.0 - fresnelFactor);
            #ifdef IPBR
                fresnelM = mix(pow2(fresnelM), fresnelM * 0.75 + 0.25, intenseFresnel);
            #else
                fresnelM = mix(pow2(fresnelM), fresnelM * 0.5 + 0.5, intenseFresnel);
            #endif
            fresnelM = fresnelM * sqrt1(smoothnessD) - dither * 0.001;

            if (fresnelM > 0.0) {
                #ifdef TAA
                    float noiseMult = 0.3;
                #else
                    float noiseMult = 0.1;
                #endif
                #ifdef TEMPORAL_FILTER
                    float blendFactor = 1.0;
                    float writeFactor = 1.0;
                #endif
                #if defined CUSTOM_PBR || defined IPBR && defined IS_IRIS
                    if (entityOrHand) {
                        noiseMult *= 0.1;
                        #ifdef TEMPORAL_FILTER
                            blendFactor = 0.0;
                            writeFactor = 0.0;
                        #endif
                    }
                #endif
                noiseMult *= pow2(1.0 - smoothnessD);

                vec2 roughCoord = gl_FragCoord.xy / 128.0;
                vec3 roughNoise = vec3(
                    texture2D(noisetex, roughCoord).r,
                    texture2D(noisetex, roughCoord + 0.09375).r,
                    texture2D(noisetex, roughCoord + 0.1875).r
                );
                roughNoise = fract(roughNoise + vec3(dither, dither * goldenRatio, dither * pow2(goldenRatio)));
                roughNoise = noiseMult * (roughNoise - vec3(0.5));

                normalM += roughNoise;

                vec4 reflection = GetReflection(normalM, viewPos.xyz, nViewPos, playerPos, lViewPos, z0,
                                                depthtex0, dither, skyLightFactor, fresnel,
                                                smoothnessD, vec3(0.0), vec3(0.0), vec3(0.0), 0.0);

                vec3 colorAdd = reflection.rgb * reflectColor;
                //float colorMultInv = (0.75 - intenseFresnel * 0.5) * max(reflection.a, skyLightFactor);
                //float colorMultInv = max(reflection.a, skyLightFactor);
                //float colorMultInv = 1.0;

                vec3 colorP = color;
                /*
                #ifdef TEMPORAL_FILTER
                    vec3 cameraOffset = cameraPosition - previousCameraPosition;
                    vec2 prvCoord = SHalfReprojection(playerPos, cameraOffset);
                    #if defined IPBR && !defined GENERATED_NORMALS
                        vec2 prvRefCoord = Reprojection(vec3(texCoord, max(refPos.z, z0)), cameraOffset);
                        vec4 oldRef = texture2D(colortex7, prvRefCoord);
                    #else
                        vec2 prvRefCoord = Reprojection(vec3(texCoord, z0), cameraOffset);
                        vec2 prvRefCoord2 = Reprojection(vec3(texCoord, max(refPos.z, z0)), cameraOffset);
                        vec4 oldRef1 = texture2D(colortex7, prvRefCoord);
                        vec4 oldRef2 = texture2D(colortex7, prvRefCoord2);
                        vec3 dif1 = colorAdd - oldRef1.rgb;
                        vec3 dif2 = colorAdd - oldRef2.rgb;
                        float dotDif1 = dot(dif1, dif1);
                        float dotDif2 = dot(dif2, dif2);

                        float oldRefMixer = clamp01((dotDif1 - dotDif2) * 500.0);
                        vec4 oldRef = mix(oldRef1, oldRef2, oldRefMixer);
                    #endif

                    vec4 newRef = vec4(colorAdd, colorMultInv);
                    vec2 oppositePreCoord = texCoord - 2.0 * (prvCoord - texCoord);

                    // Reduce blending at speed
                    blendFactor *= float(prvCoord.x > 0.0 && prvCoord.x < 1.0 && prvCoord.y > 0.0 && prvCoord.y < 1.0);
                    float velocity = length(cameraOffset) * max(16.0 - lViewPos / gbufferProjection[1][1], 3.0);
                    blendFactor *= mix(1.0, exp(-velocity) * 0.5 + 0.5, smoothnessD);

                    // Reduce blending if depth changed
                    float linearZDif = abs(GetLinearDepth(texture2D(colortex1, oppositePreCoord).r) - linearZ0) * far;
                    blendFactor *= max0(2.0 - linearZDif) * 0.5;
                    //color = mix(vec3(1,1,0), color, max0(2.0 - linearZDif) * 0.5);

                    // Reduce blending if normal changed
                    vec3 texture5P = texture2D(colortex5, oppositePreCoord, 0).rgb;
                    vec3 texture5Dif = abs(texture5 - texture5P);
                    if (texture5Dif != clamp(texture5Dif, vec3(-0.004), vec3(0.004))) {
                        blendFactor = 0.0;
                           //color.rgb = vec3(1,0,1);
                    }

                    blendFactor = max0(blendFactor); // Prevent first frame NaN
                    newRef = max(newRef, vec4(0.0)); // Prevent random NaNs from persisting
                    refToWrite = mix(newRef, oldRef, blendFactor * 0.95);
                    refToWrite = mix(max(refToWrite, newRef), refToWrite, pow2(pow2(pow2(refToWrite.a))));
                    
                    color.rgb *= 1.0 - refToWrite.a * fresnelM;
                    color.rgb += refToWrite.rgb * fresnelM;
                    refToWrite *= writeFactor;
                #else
                */
                    color *= 1.0 - colorMultInv * fresnelM;
                    color += colorAdd * fresnelM;
                //#endif

                color = max(colorP, color); // Prevents reflections from making a surface darker
                
            }
        #endif

        #if GLOBAL_ILLUMINATION == 0
            ao = 1.0;
            if (!entityOrHand) color.rgb *= ao;
        #elif GLOBAL_ILLUMINATION == 1
            ao = DoAmbientOcclusion(z0, linearZ0, dither, playerPos);
            if (!entityOrHand) color.rgb *= ao;
        #else
            #ifdef EXCLUDE_ENTITIES
            if (!entityOrHand) {
            #endif
                vec3 rawGI = texture2D(colortex9, texCoord).rgb;
                vec3 gi = vec3(0.0);
                #ifdef TEMPORAL_BILATERAL_FILTER
                    float totalWeight = 0.0;
                    
                    float giBlurWeight[7] = float[7](1.0, 6.0, 15.0, 20.0, 15.0, 6.0, 1.0);
                    
                    float centerDepth = linearZ0;
                    vec3 centerNormal = normalM;

                    float centerVariance = texture2D(colortex9, texCoord).a;
                    
                    for (int i = -BLUR_SAMPLES; i <= BLUR_SAMPLES; i++) {
                        for (int j = -BLUR_SAMPLES; j <= BLUR_SAMPLES; j++) {
                            vec2 offset = vec2(i, j) / vec2(viewWidth, viewHeight);
                            vec2 sampleCoord = texCoord + offset * BLUR_AMOUNT;

                            float spatialWeight = giBlurWeight[abs(i)] * giBlurWeight[abs(j)];

                            float sampleDepth = GetLinearDepth(texture2D(depthtex0, sampleCoord).r);
                            float depthDiff = abs(centerDepth - sampleDepth) * far;
                            float depthWeight = exp(-depthDiff * depthDiff * 2.0);

                            vec3 sampleNormal = texture2D(colortex5, sampleCoord).rgb * 2.0 - 1.0;
                            sampleNormal = mat3(gbufferModelView) * sampleNormal;
                            float normalWeight = pow(max(dot(centerNormal, sampleNormal), 0.0), 4.0);

                            vec4 sampleGIData = texture2D(colortex9, sampleCoord);
                            vec3 sampleGI = sampleGIData.rgb;
                            float sampleVariance = sampleGIData.a;

                            float varianceWeight = sqrt(centerVariance * sampleVariance + 0.001);
                            varianceWeight = 1.0 / (1.0 + varianceWeight * 5.0); // Adjust sensitivity with the 5.0 multiplier
                            
                            float weight = spatialWeight * depthWeight * normalWeight * varianceWeight;
                            
                            gi += sampleGI * weight;
                            totalWeight += weight;
                        }
                    }
                    
                    gi /= totalWeight;
                #else
                    gi = rawGI;
                #endif

                /*
    vec3 doIndirectLighting(vec3 lightColor, vec3 minimumLightColor, float lightmap) {
        float lightmapCurve = (pow(lightmap, 2.0) * 2.0 + pow(lightmap, 2.5)) * 0.5;
        
        vec3 indirectLight = lightColor * lightmapCurve * 0.7;  // ambient_brightness placeholder
        indirectLight += minimumLightColor * 0.01;  // MIN_LIGHT_AMOUNT placeholder
        return indirectLight;
    }*/

                /*
                vec3 colorCurve = (pow(ambientColor, vec3(16.0)) * 2.0 + pow(ambientColor, vec3(2.5))) * 0.5;

                vec3 indirectLight = gi * colorCurve * 0.7;
                indirectLight += 0.01 * 0.01; */

                #ifdef RT_VIEW
                    vec3 colorAdd = gi;
                #else
                    vec3 colorAdd = (gi * 0.5 + color * 0.5) * 1.0;
                #endif
                
                #ifdef TEMPORAL_FILTER
                float blendFactor = 1.0;
                float writeFactor = 1.0;
                vec3 cameraOffset = cameraPosition - previousCameraPosition;
                vec2 prvCoord = SHalfReprojection(playerPos, cameraOffset);
                vec2 prvRefCoord = Reprojection(vec3(texCoord, z0), cameraOffset);
                vec2 prvRefCoord2 = Reprojection(vec3(texCoord, max(refPos.z, z0)), cameraOffset);
                vec4 oldRef1 = vec4(textureCatmullRom(colortex7, prvRefCoord, vec2(viewWidth, viewHeight)), texture2D(colortex7, prvRefCoord).a);
                vec4 oldRef2 = vec4(textureCatmullRom(colortex7, prvRefCoord2, vec2(viewWidth, viewHeight)), texture2D(colortex7, prvRefCoord2).a);
                
                vec3 dif1 = colorAdd - oldRef1.rgb;
                vec3 dif2 = colorAdd - oldRef2.rgb;
                float dotDif1 = dot(dif1, dif1);
                float dotDif2 = dot(dif2, dif2);
                float oldRefMixer = clamp01((dotDif1 - dotDif2) * 500.0);
                vec4 oldRef = mix(oldRef1, oldRef2, oldRefMixer);
                vec4 newRef = vec4(colorAdd, colorMultInv);
                vec2 oppositePreCoord = texCoord - 2.0 * (prvCoord - texCoord);
                
                // Reduce blending at screen edges
                blendFactor *= float(prvCoord.x > 0.0 && prvCoord.x < 1.0 && prvCoord.y > 0.0 && prvCoord.y < 1.0);
                
                // Camera velocity reduction
                vec2 screenVelocity = (texCoord - prvCoord) * vec2(viewWidth, viewHeight);
                float pixelVelocity = length(screenVelocity);

                // Use pixel velocity instead
                blendFactor *= mix(1.0, exp(-pixelVelocity * 0.1) * 0.5 + 0.5, GHOST_REDUCTION);
                
                vec3 colorDiff = abs(colorAdd - oldRef.rgb);
                float colorChange = dot(colorDiff, vec3(0.299, 0.587, 0.114)); // Luminance weighted
                
                // Reduce blending on significant color changes (moving objects/GI)
                float antiGhostFactor = exp(-colorChange * 0.0);
                blendFactor *= antiGhostFactor;
                
                // Reduce blending if depth changed
                float linearZDif = abs(GetLinearDepth(texture2D(colortex1, oppositePreCoord).r) - linearZ0) * far;
                blendFactor *= max0(1.0 - linearZDif * BLEND_WEIGHT);

                vec3 texture5P = texture2D(colortex5, oppositePreCoord, 0).rgb;
                vec3 texture5Dif = abs(texture5 - texture5P);
                if (texture5Dif != clamp(texture5Dif, vec3(-0.004), vec3(0.004))) {
                    blendFactor = 0.0;
                }
                
                blendFactor = max0(blendFactor);
                newRef = max(newRef, vec4(0.0));
                refToWrite = mix(newRef, oldRef, blendFactor * 0.95);
                refToWrite = mix(max(refToWrite, newRef), refToWrite, pow2(pow2(pow2(refToWrite.a))));
                color.rgb *= 1.0 - refToWrite.a * 1.0;
                color.rgb += refToWrite.rgb * 1.0;
                refToWrite *= writeFactor;

                #else
                    #ifdef RT_VIEW
                        color.rgb = colorAdd;
                    #else
                        color.rgb = colorAdd;
                    #endif
                #endif
            #ifdef EXCLUDE_ENTITIES
            }
            #endif
        #endif

        #ifdef WORLD_OUTLINE
            #ifndef WORLD_OUTLINE_ON_ENTITIES
                if (!entityOrHand)
            #endif
            DoWorldOutline(color, linearZ0);
        #endif

        #ifndef SKY_EFFECT_REFLECTION
            waterRefColor = sqrt(color) - 1.0;
        #else
            waterRefColor = color;
        #endif

        #ifndef END
            DoFog(color, skyFade, lViewPos, playerPos, VdotU, VdotS, dither);
        #endif
    } else { // Sky
        #ifdef DISTANT_HORIZONS
            float z0DH = texelFetch(dhDepthTex, texelCoord, 0).r;
            if (z0DH < 1.0) { // Distant Horizons Chunks
                vec4 screenPosDH = vec4(texCoord, z0DH, 1.0);
                vec4 viewPosDH = dhProjectionInverse * (screenPosDH * 2.0 - 1.0);
                viewPosDH /= viewPosDH.w;
                lViewPos = length(viewPosDH.xyz);
                playerPos = ViewToPlayer(viewPosDH.xyz);
                
                #ifndef SKY_EFFECT_REFLECTION
                    waterRefColor = sqrt(color) - 1.0;
                #else
                    waterRefColor = color;
                #endif
                #ifndef END
                    DoFog(color.rgb, skyFade, lViewPos, playerPos, VdotU, VdotS, dither);
                #endif
            } else { // Start of Actual Sky
        #endif

        skyFade = 1.0;

        #ifdef OVERWORLD
            #if AURORA_STYLE > 0
                auroraBorealis = GetAuroraBorealis(viewPos.xyz, VdotU, dither);
                color.rgb += auroraBorealis;
            #endif
            #ifdef NIGHT_NEBULA
                nightNebula += GetNightNebula(viewPos.xyz, VdotU, VdotS);
                color.rgb += nightNebula;
            #endif
        #endif
        #ifdef NETHER
            color.rgb = netherColor * (1.0 - maxBlindnessDarkness);

            #ifdef ATM_COLOR_MULTS
                color.rgb *= atmColorMult;
            #endif
        #endif
        #ifdef END
            color.rgb += GetEndSky(viewPos.xyz, VdotU);
            color.rgb += GetEndSun(viewPos.xyz, VdotS);
            color.rgb += GetEndBackgroundColor(viewPos.xyz, VdotM); // this is optional, just really like the look with the sun in the end

            color.rgb *= 1.0 - maxBlindnessDarkness;

            #ifdef ATM_COLOR_MULTS
                color.rgb *= atmColorMult;
            #endif
        #endif

        #ifdef DISTANT_HORIZONS
        } // End of Actual Sky
        #endif
    }

    float cloudLinearDepth = 1.0;
    vec4 clouds = vec4(0.0);

    #ifdef VL_CLOUDS_ACTIVE
        float cloudZCheck = 0.56;

        if (z0 > cloudZCheck) {
            clouds = GetClouds(cloudLinearDepth, skyFade, cameraPosition, playerPos,
                               lViewPos, VdotS, VdotU, dither, auroraBorealis, nightNebula);

            color = mix(color, clouds.rgb, clouds.a);
        }
    #endif

    #ifdef SKY_EFFECT_REFLECTION
        waterRefColor = mix(waterRefColor, clouds.rgb, clouds.a);
        waterRefColor = sqrt(waterRefColor) - 1.0;
    #endif

    #if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
        if (viewWidth + viewHeight - gl_FragCoord.x - gl_FragCoord.y < 1.5)
            cloudLinearDepth = vlFactor;
    #endif

    #if defined OVERWORLD && defined ATMOSPHERIC_FOG && (defined SPECIAL_BIOME_WEATHER || RAIN_STYLE == 2)
        float altitudeFactorRaw = GetAtmFogAltitudeFactor(playerPos.y + cameraPosition.y);
        vec3 atmFogColor = GetAtmFogColor(altitudeFactorRaw, VdotS);

        #if RAIN_STYLE == 2
            float factor = 1.0;
        #else
            float factor = max(inSnowy, inDry);
        #endif

        color = mix(color, atmFogColor, 0.5 * rainFactor * factor * sqrt1(skyFade));
    #endif

    #ifdef DARK_OUTLINE
        if (clouds.a < 0.5) DoDarkOutline(color, skyFade, z0, dither);
    #endif

    /*DRAWBUFFERS:054*/
    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(waterRefColor, 1.0 - skyFade);
    gl_FragData[2] = vec4(cloudLinearDepth, 0.0, 0.0, 1.0);
    #ifdef TEMPORAL_FILTER
        /*DRAWBUFFERS:0547*/
        gl_FragData[3] = refToWrite;
    #endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

out vec3 normal;

flat out vec3 upVec, sunVec;

#if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
    flat out float vlFactor;
#endif

//Attributes//

//Common Variables//

//Common Functions//

//Includes//

//Program//
void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    normal = normalize(gl_NormalMatrix * gl_Normal);

    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = normalize(sunPosition);

    #if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
        vlFactor = texelFetch(colortex4, ivec2(viewWidth-1, viewHeight-1), 0).r;

        #ifdef END
            if (frameCounter % int(0.06666 / frameTimeSmooth + 0.5) == 0) { // Change speed is not too different above 10 fps
                vec2 absCamPosXZ = abs(cameraPosition.xz);
                float maxCamPosXZ = max(absCamPosXZ.x, absCamPosXZ.y);

                if (gl_Fog.start / far > 0.5 || maxCamPosXZ > 350.0) vlFactor = max(vlFactor - OSIEBCA*2, 0.0);
                else                                                 vlFactor = min(vlFactor + OSIEBCA*2, 1.0);
            }
        #endif
    #endif
}

#endif
