/*
    --------------------------------------------PLEASE READ--------------------------------------------
    The pathtracing implementation used here is derived from the Bliss Shaders by Xonk,
    and has been heavily modified from Bliss's version of Chocapic13's original ray tracing code.

    This ray tracing code was originally developed by Chocapic13.
    --------------------------------------------PLEASE READ--------------------------------------------
    LICENSE, AS STATED BY Chocapic13: SHARING A MODIFIED VERSION OF MY SHADERS:
        You are not allowed to claim any of the code included in "Chocapic13' shaders" as your own

        You can share a modified version of my shaders if you respect the following title scheme : " -Name of the shaderpack- (Chocapic13' Shaders edit) "

        You cannot use any monetizing links (for example adfoc.us ; adf.ly)

        The rules of modification and sharing have to be same as the one here (copy paste all these rules in your post and change depending if you allow modification or not), you cannot make your own rules, you can only choose if you allow redistribution.

        I have to be clearly credited

        You cannot use any version older than "Chocapic13' Shaders V4" as a base, however you can modify older versions for personal use
    --------------------------------------------PLEASE READ--------------------------------------------
    Special level of permission; with written permission from Chocapic13, on request if you think your shaderpack is an huge modification from the original:
        Allows to use monetizing links

        Allows to create your own sharing rules

        Shaderpack name can be chosen

        Listed on Chocapic13' shaders official thread

        Chocapic13 still have to be clearly credited
    --------------------------------------------PLEASE READ--------------------------------------------
    Using this shaderpack in a video or a picture:
        You are allowed to use this shaderpack for screenshots and videos if you give the shaderpack name in the description/message

        You are allowed to use this shaderpack in monetized videos if you respect the rule above.

    Minecraft websites:
        The download link must redirect to the download link given in the shaderpack's official thread

        There has to be a link to the shaderpack's official thread

        You are not allowed to add any monetizing link to the shaderpack download
    --------------------------------------------PLEASE READ--------------------------------------------
*/

/*
    CREDITS:
        Xonk
        Chocapic13
*/

vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);

#define PT_USE_RUSSIAN_ROULETTE

#if GLOBAL_ILLUMINATION == 1
    vec2 OffsetDist(float x, int s) {
        float n = fract(x * 1.414) * 3.1415;
        return pow2(vec2(cos(n), sin(n)) * x / s);
    }

    float DoAmbientOcclusion(float z0, float linearZ0, float dither, vec3 playerPos) {
        if (z0 < 0.56) return 1.0;
        float ao = 0.0;

        #if SSAO_QUALI_DEFINE == 2
            int samples = 4;
            float scm = 0.4;
        #elif SSAO_QUALI_DEFINE == 3
            int samples = 12;
            float scm = 0.6;
        #endif

        #define SSAO_I_FACTOR 0.3

        float sampleDepth = 0.0, angle = 0.0, dist = 0.0;
        float fovScale = gbufferProjection[1][1];
        float distScale = max(farMinusNear * linearZ0 + near, 3.0);
        vec2 scale = vec2(scm / aspectRatio, scm) * fovScale / distScale;

        for (int i = 1; i <= samples; i++) {
            vec2 offset = OffsetDist(i + dither, samples) * scale;
            if (i % 2 == 0) offset.y = -offset.y;

            vec2 coord1 = texCoord + offset;
            vec2 coord2 = texCoord - offset;

            sampleDepth = GetLinearDepth(texture2D(depthtex0, coord1).r);
            float aosample = farMinusNear * (linearZ0 - sampleDepth) * 2.0;
            angle = clamp(0.5 - aosample, 0.0, 1.0);
            dist = clamp(0.5 * aosample - 1.0, 0.0, 1.0);

            sampleDepth = GetLinearDepth(texture2D(depthtex0, coord2).r);
            aosample = farMinusNear * (linearZ0 - sampleDepth) * 2.0;
            angle += clamp(0.5 - aosample, 0.0, 1.0);
            dist += clamp(0.5 * aosample - 1.0, 0.0, 1.0);

            ao += clamp(angle + dist, 0.0, 1.0);
        }
        ao /= samples;

        #define SSAO_IM AO_I * SSAO_I_FACTOR
        return pow(ao, SSAO_IM);
    }

#elif GLOBAL_ILLUMINATION == 2
    float rand(float dither, int i) {
        return fract(dither + float(i) * 0.61803398875);
    }
    
    float randWithSeed(float dither, int seed) {
        return fract(dither * 12.9898 + float(seed) * 78.233);
    }

    vec3 RayDirection(vec3 normal, float dither, int i) {
        vec2 Xi = vec2(rand(dither, i), rand(dither, i + 1));
        
        float theta = 6.28318530718 * Xi.y;
        float r = sqrt(Xi.x);
        vec3 hemi = vec3(r * cos(theta), r * sin(theta), sqrt(1.0 - Xi.x));
        
        vec3 T = normalize(cross(abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0), normal));
        vec3 B = cross(normal, T);
        
        return (T * hemi.x) + (B * hemi.y) + (normal * hemi.z);
    }

    vec3 toClipSpace3(vec3 viewSpacePosition) {
        vec4 clipSpace = gbufferProjection * vec4(viewSpacePosition, 1.0);
        return clipSpace.xyz / clipSpace.w * 0.5 + 0.5;
    }

    struct RayHit {
        bool hit;
        vec3 screenPos;
        vec3 worldPos;
        float hitDist;
        float border;
    };

    RayHit MarchRay(vec3 start, vec3 rayDir, sampler2D depthtex, vec2 screenEdge) {
        RayHit result;
        result.hit = false;
        result.hitDist = 0.0;
        result.border = 0.0;
        
        float stepSize = 0.05;
        vec3 rayPos = start;
        
        vec4 initialClip = gbufferProjection * vec4(rayPos, 1.0);
        vec3 initialScreen = initialClip.xyz / initialClip.w * 0.5 + 0.5;
        float minZ = initialScreen.z;
        float maxZ = initialScreen.z;

        for (int j = 0; j < int(PT_STEPS); j++) {
            rayPos += rayDir * stepSize;
            
            vec4 rayClip = gbufferProjection * vec4(rayPos, 1.0);
            vec3 rayScreen = rayClip.xyz / rayClip.w * 0.5 + 0.5;
            
            if (rayScreen.x < 0.0 || rayScreen.x > 1.0 || 
                rayScreen.y < 0.0 || rayScreen.y > 1.0) break;
            
            float sampledDepth = texture2D(depthtex, rayScreen.xy).r;
            
            float currZ = GetLinearDepth(rayScreen.z);
            float nextZ = GetLinearDepth(sampledDepth);
            
            if (nextZ < currZ && (sampledDepth <= max(minZ, maxZ) && sampledDepth >= min(minZ, maxZ))) {
                vec3 hitPos = rayPos - rayDir * stepSize * 0.5;
                vec4 hitClip = gbufferProjection * vec4(hitPos, 1.0);
                result.screenPos = hitClip.xyz / hitClip.w * 0.5 + 0.5;
                result.worldPos = hitPos;
                result.hitDist = length(hitPos - start);
                
                vec2 absPos = abs(result.screenPos.xy - 0.5);
                vec2 cdist = absPos / screenEdge;
                result.border = clamp(1.0 - pow(max(cdist.x, cdist.y), 50.0), 0.0, 1.0);
                
                result.hit = true;
                break;
            }
            
            float biasamount = 0.00005;
            minZ = maxZ - biasamount / currZ;
            maxZ = rayScreen.z;
            
            stepSize = min(stepSize, 0.1) * 2.5;
        }
        
        return result;
    }

    #include "/lib/lighting/ggx.glsl"

    vec3 EvaluateBRDF(vec3 albedo, vec3 normal, vec3 wi, vec3 wo, float smoothness) {
        float NdotL = max(dot(normal, wi), 0.0);

        vec3 diffuse = albedo / 3.14159265;
        float ggxSpec = GGX(normal, -wo, wi, NdotL, smoothness);
        
        return diffuse + albedo * ggxSpec;
    }

    vec3 EvaluateBRDF(vec3 albedo, vec3 normal, vec3 wi, vec3 wo) {
        return albedo / 3.14159265;
    }

    float CosinePDF(float NdotL) {
        return NdotL / 3.14159265;
    }

    vec3 giScreenPos = vec3(0.0);
    
    vec4 GetGI(inout vec3 occlusion, vec3 normalM, vec3 viewPos, vec3 nViewPos, sampler2D depthtex, float dither, float skyLightFactor, float smoothness, float VdotU, float VdotS, bool entityOrHand) {
        vec2 screenEdge = vec2(0.6, 0.55);
        vec3 normalMR = normalM;

        vec4 gi = vec4(0.0);
        vec3 totalRadiance = vec3(0.0);
        
        vec3 startPos = viewPos + normalMR * 0.01;
        vec3 startWorldPos = mat3(gbufferModelViewInverse) * startPos;
        
        float distanceScale = clamp(1.0 - startPos.z / far, 0.1, 1.0);
        int numPaths = int(PT_MAX_BOUNCES * distanceScale);
        
        for (int i = 0; i < numPaths; i++) {
            vec3 pathRadiance = vec3(0.0);
            vec3 pathThroughput = vec3(1.0);
            
            vec3 currentPos = startPos;
            vec3 currentNormal = normalMR;
            int bounce = 0;
            
            for (bounce = 0; bounce < PT_MAX_BOUNCES; bounce++) {
                int seed = i * PT_MAX_BOUNCES + bounce;
                vec3 rayDir = RayDirection(currentNormal, dither, seed);
                float NdotL = max(dot(currentNormal, rayDir), 0.0);
                
                RayHit hit = MarchRay(currentPos, rayDir, depthtex, screenEdge);
                
                if (hit.hit && hit.screenPos.z < 0.99997 && hit.border > 0.001) {
                    vec2 edgeFactor = pow2(pow2(pow2(abs(hit.screenPos.xy - 0.5) / screenEdge)));
                    vec2 jitteredUV = hit.screenPos.xy;
                    jitteredUV.y += (dither - 0.5) * (0.05 * (edgeFactor.x + edgeFactor.y));
                    
                    float lod = log2(hit.hitDist * 0.5) * 0.5;
                    lod = max(lod, 0.0);
                    
                    vec3 hitColor = texture2DLod(colortex0, jitteredUV, lod).rgb;
                    float hitFoliage = texture2D(colortex10, jitteredUV).a;
                    
                    if (hitFoliage > 0.9) {
                        hitColor *= 0.1;
                    }
                    
                    vec3 hitNormalEncoded = texture2DLod(colortex5, jitteredUV, 0.0).rgb;
                    vec3 hitNormal = normalize(hitNormalEncoded * 2.0 - 1.0);
                    vec3 hitAlbedo = hitColor;
                    float hitSmoothness = texture2DLod(colortex6, jitteredUV, 0.0).r;

                    vec3 brdf = EvaluateBRDF(hitAlbedo, currentNormal, rayDir, -normalize(currentPos));
                    float pdf = CosinePDF(NdotL);
                    
                    pathThroughput *= brdf * NdotL / max(pdf, 0.0001);
                    
                    float brightness = dot(hitColor, vec3(0.299, 0.587, 0.114));
                    if (brightness > 1.5) {
                        pathRadiance += pathThroughput * hitColor * 0.5;
                    }

                    #ifdef PT_USE_RUSSIAN_ROULETTE
                    if (bounce > 0) {
                        float continueProbability = min(max(pathThroughput.x, max(pathThroughput.y, pathThroughput.z)), 0.95);
                        if (randWithSeed(dither, seed + 1000) > continueProbability) {
                            break;
                        }
                        pathThroughput /= continueProbability;
                    }
                    #endif
                    
                    currentPos = hit.worldPos + rayDir * 0.01;
                    currentNormal = hitNormal;
                    
                    if (bounce == PT_MAX_BOUNCES - 1) {
                        pathRadiance += pathThroughput * hitColor * 0.25 * GI_I;
                    }
                    
                } else {
                    //float skyWeight = max(normalize(rayDir.z), pow(skyLightFactor, 16.0)) * 1.0 + 0.05;
                    #ifdef OVERWORLD
                        vec3 sampledSky = (ambientColor * 0.5 + dayMiddleSkyColor * 0.5) * SKY_I * skyLightFactor;
                        vec3 skyContribution = sampledSky * normalize(rayDir.z);
                    #else
                        vec3 skyContribution = ambientColor * 0.1 * skyWeight;
                    #endif
                    
                    pathRadiance += pathThroughput * skyContribution;
                    break;
                }
            }
            
            totalRadiance += pathRadiance;
            
            RayHit firstHit = MarchRay(startPos, RayDirection(normalMR, dither, i), depthtex, screenEdge);
            if (firstHit.hit) {
                float aoRadius = 2.0;
                float curve = 1.0 - clamp(firstHit.hitDist / aoRadius, 0.0, 1.0);
                curve = pow(curve, 2.0);
                occlusion += curve * AO_I * 0.5 * max(skyLightFactor, 0.5);
            }
        }
        
        totalRadiance /= float(numPaths);
        occlusion /= float(numPaths);
        
        #if defined DEFERRED1 && defined TEMPORAL_FILTER
            giScreenPos = vec3(texCoord, 1.0);
        #endif
        
        gi.rgb = max(totalRadiance - occlusion, 0.0);
        gi.a = 1.0;

        float giBrightness = length(gi.rgb);
        if (giBrightness > 1.2) {
            float compressedBrightness = 1.2 + (giBrightness - 1.2) / 
                                         (1.0 + (giBrightness - 1.2) / (2.5 - 1.2));
            gi.rgb *= compressedBrightness / giBrightness;
        }
        
        gi.rgb = max(gi.rgb, vec3(0.0));
        
        return gi;
    }
#endif