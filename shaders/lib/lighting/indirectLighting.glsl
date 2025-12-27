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

#include "/lib/colors/blocklightColors.glsl"

#define PT_USE_RUSSIAN_ROULETTE
//#define DEBUG_SHADOW_VIEW
#if COLORED_LIGHTING_INTERNAL > 0
    #define PT_USE_VOXEL_LIGHT
#endif
#define PT_TRANSPARENT_TINTS

#if COLORED_LIGHTING_INTERNAL > 0
    #include "/lib/misc/voxelization.glsl"

    const vec3[] specialTintColorPT = vec3[](
        vec3(1.0, 1.0, 1.0),       // 200 White
        vec3(0.95, 0.65, 0.2),     // 201 Orange
        vec3(0.9, 0.2, 0.9),       // 202 Magenta
        vec3(0.4, 0.6, 0.85),      // 203 Light Blue
        vec3(0.9, 0.9, 0.2),       // 204 Yellow
        vec3(0.5, 0.8, 0.2),       // 205 Lime
        vec3(1.0, 0.4, 0.7),       // 206 Pink
        vec3(0.3, 0.3, 0.3),       // 207 Gray
        vec3(0.6, 0.6, 0.6),       // 208 Light Gray
        vec3(0.3, 0.5, 0.6),       // 209 Cyan
        vec3(0.5, 0.25, 0.7),      // 210 Purple
        vec3(0.2, 0.25, 0.7),      // 211 Blue
        vec3(0.45, 0.3, 0.2),      // 212 Brown
        vec3(0.45, 0.75, 0.35),    // 213 Green
        vec3(1.0, 0.05, 0.05),     // 214 Red
        vec3(0.1, 0.1, 0.1),       // 215 Black
        vec3(0.6, 0.8, 1.0),       // 216 Ice
        vec3(1.0, 1.0, 1.0),       // 217 Glass
        vec3(1.0, 1.0, 1.0),       // 218 Glass Pane
        vec3(1.0, 1.0, 1.0),       // 219
        vec3(0.95, 0.65, 0.2),     // 220 Honey
        vec3(0.45, 0.75, 0.35),    // 221 Slime
        vec3(1.0, 1.0, 1.0),       // 222
        vec3(1.0, 1.0, 1.0),       // 223
        vec3(1.0, 1.0, 1.0),       // 224
        vec3(1.0, 1.0, 1.0),       // 225
        vec3(1.0, 1.0, 1.0),       // 226
        vec3(1.0, 1.0, 1.0),       // 227
        vec3(1.0, 1.0, 1.0),       // 228
        vec3(1.0, 1.0, 1.0),       // 229
        vec3(1.0, 1.0, 1.0),       // 230
        vec3(1.0, 1.0, 1.0),       // 231
        vec3(1.0, 1.0, 1.0),       // 232
        vec3(1.0, 1.0, 1.0),       // 233
        vec3(1.0, 1.0, 1.0),       // 234
        vec3(1.0, 1.0, 1.0),       // 235
        vec3(1.0, 1.0, 1.0),       // 236
        vec3(1.0, 1.0, 1.0),       // 237
        vec3(1.0, 1.0, 1.0),       // 238
        vec3(1.0, 1.0, 1.0),       // 239
        vec3(1.0, 1.0, 1.0),       // 240
        vec3(1.0, 1.0, 1.0),       // 241
        vec3(1.0, 1.0, 1.0),       // 242
        vec3(1.0, 1.0, 1.0),       // 243
        vec3(1.0, 1.0, 1.0),       // 244
        vec3(1.0, 1.0, 1.0),       // 245
        vec3(1.0, 1.0, 1.0),       // 246
        vec3(1.0, 1.0, 1.0),       // 247
        vec3(1.0, 1.0, 1.0),       // 248
        vec3(1.0, 1.0, 1.0),       // 249
        vec3(1.0, 1.0, 1.0),       // 250
        vec3(1.0, 1.0, 1.0),       // 251
        vec3(1.0, 1.0, 1.0),       // 252
        vec3(1.0, 1.0, 1.0),       // 253
        vec3(0.15, 0.15, 0.15)     // 254 Tinted Glass
    );

    vec3 CheckVoxelTint(vec3 startViewPos, vec3 endViewPos) {
        vec3 tint = vec3(1.0);

        vec4 startWorld4 = gbufferModelViewInverse * vec4(startViewPos, 1.0);
        vec4 endWorld4 = gbufferModelViewInverse * vec4(endViewPos, 1.0);
        vec3 startWorld = startWorld4.xyz;
        vec3 endWorld = endWorld4.xyz;
        
        vec3 startVoxel = SceneToVoxel(startWorld);
        vec3 endVoxel = SceneToVoxel(endWorld);
        vec3 volumeSize = vec3(voxelVolumeSize);

        int steps = 24; 
        vec3 dir = endVoxel - startVoxel;
        float dist = length(dir);
        if (dist < 0.001) return tint;
        
        vec3 stepDir = dir / float(steps);
        vec3 pos = startVoxel;

        for(int i = 0; i < steps; i++) {
            pos += stepDir;

            if (any(lessThan(pos, vec3(0.5))) || any(greaterThanEqual(pos, volumeSize - 0.5))) continue;

            uint id = texelFetch(voxel_sampler, ivec3(pos), 0).r;

            if (id <= 1u) continue;
            
            if ((id >= 200u && id <= 218u) || id == 254u) {
                int idx = int(id) - 200;
                tint *= specialTintColorPT[idx];
            }
        }
        return tint;
    }
#else
    vec3 CheckVoxelTint(vec3 startViewPos, vec3 endViewPos) {
        return vec3(1.0);
    }
#endif

const float PHI = 1.618033988749895;
const float PHI_INV = 0.618033988749895;
const float PHI2_INV = 0.38196601125010515;


float rand(float dither, int i) {
    return fract(dither + float(i) * 0.61803398875);
}

float randWithSeed(float dither, int seed) {
    return fract(dither * 12.9898 + float(seed) * 78.233);
}

vec2 R2Sequence(int n, int seed) {
    float u = fract(float(n) * PHI_INV + fract(float(seed) * PHI_INV));
    float v = fract(float(n) * PHI2_INV + fract(float(seed) * PHI2_INV));
    return vec2(u, v);
}

vec2 CranleyPattersonRotation(vec2 sample, float dither) {
    vec2 shift = vec2(
        fract(dither * 12.9898),
        fract(dither * 78.233)
    );
    return fract(sample + shift);
}

vec3 SampleHemisphereCosine(vec2 Xi) {
    float theta = 6.28318530718 * Xi.y;
    float r = sqrt(Xi.x);
    
    vec3 hemi = vec3(
        r * cos(theta),
        r * sin(theta),
        sqrt(1.0 - Xi.x)
    );
    
    return hemi;
}

void BuildOrthonormalBasis(vec3 normal, out vec3 tangent, out vec3 bitangent) {
    if (normal.z < -0.9999999) {
        tangent = vec3(0.0, -1.0, 0.0);
        bitangent = vec3(-1.0, 0.0, 0.0);
        return;
    }
    
    float a = 1.0 / (1.0 + normal.z);
    float b = -normal.x * normal.y * a;
    
    tangent = vec3(1.0 - normal.x * normal.x * a, b, -normal.x);
    bitangent = vec3(b, 1.0 - normal.y * normal.y * a, -normal.y);
}


vec3 RayDirection(vec3 normal, float dither, int i) {
    vec2 Xi = R2Sequence(i, int(dither * 7919.0));
        Xi = CranleyPattersonRotation(Xi, dither);
    
    vec3 hemiDir = SampleHemisphereCosine(Xi);
    
    vec3 T, B;
    BuildOrthonormalBasis(normal, T, B);

    return normalize(T * hemiDir.x + B * hemiDir.y + normal * hemiDir.z);
}


vec3 GetShadowPosition(vec3 tracePos, vec3 cameraPos) {
    vec3 worldPos = PlayerToShadow(tracePos - cameraPos);
    float distB = sqrt(worldPos.x * worldPos.x + worldPos.y * worldPos.y);
    float distortFactor = 1.0 - shadowMapBias + distB * shadowMapBias;
    vec3 shadowPosition = vec3(vec2(worldPos.xy / distortFactor), worldPos.z * 0.2);
    return shadowPosition * 0.5 + 0.5;
}

bool GetShadow(vec3 tracePos, vec3 cameraPos) {
    vec3 shadowPosition0 = GetShadowPosition(tracePos, cameraPos);
    if (length(shadowPosition0.xy * 2.0 - 1.0) < 1.0) {
        float shadowDepth = shadow2D(shadowtex0, shadowPosition0).z;
        if (shadowDepth == 0.0) return true;
    }
    return false;
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

RayHit MarchRay(vec3 start, vec3 rayDir, sampler2D depthtex, vec2 screenEdge, float dither) {
    RayHit result;
    result.hit = false;
    result.hitDist = 0.0;
    result.border = 0.0;
    
    // Jitter initial step size to break ring patterns from exponential step growth
    float stepSize = 0.05 * (0.5 + dither);
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
            vec3 hitScreen = hitClip.xyz / hitClip.w * 0.5 + 0.5;
            
            result.screenPos = hitScreen;
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

vec4 GetGI(inout vec3 occlusion, inout vec3 emissiveOut, vec3 normalM, vec3 viewPos, vec3 unscaledViewPos, vec3 nViewPos, sampler2D depthtex, 
           float dither, float skyLightFactor, float smoothness, float VdotU, float VdotS, bool entityOrHand) {
    vec2 screenEdge = vec2(0.6, 0.55);
    vec3 normalMR = normalM;

    vec4 gi = vec4(0.0);
    vec3 totalRadiance = vec3(0.0);
    vec3 emissiveRadiance = vec3(0.0);
    
    vec3 startPos = viewPos + normalMR * 0.01;
    vec3 startWorldPos = mat3(gbufferModelViewInverse) * startPos;
    
    float distanceScale = clamp(1.0 - startPos.z / far, 0.1, 1.0);
    int numPaths = int(PT_MAX_BOUNCES * distanceScale);

    vec3 receiverScenePos = (gbufferModelViewInverse * vec4(unscaledViewPos, 1.0)).xyz;
    vec3 receiverWorldPos = receiverScenePos + cameraPosition;
    bool receiverInShadow = GetShadow(receiverWorldPos, cameraPosition);
    float receiverShadowMask = receiverInShadow ? 0.5 : 0.1; // default is 0.5
    
    // visualize shadow map for the starting pixel
    #ifdef DEBUG_SHADOW_VIEW
        gi.rgb = receiverInShadow ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        return gi;
    #endif

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
            
            // Per-bounce dither variation to decorrelate ray patterns
            float rayDither = fract(dither + float(seed) * PHI_INV);
            RayHit hit = MarchRay(currentPos, rayDir, depthtex, screenEdge, rayDither);
            
            if (hit.hit && hit.screenPos.z < 0.99997 && hit.border > 0.001) {
                vec2 edgeFactor = pow2(pow2(pow2(abs(hit.screenPos.xy - 0.5) / screenEdge)));
                vec2 jitteredUV = hit.screenPos.xy;
                jitteredUV.y += (dither - 0.5) * (0.05 * (edgeFactor.x + edgeFactor.y));
                
                float lod = log2(hit.hitDist * 0.5) * 0.5;
                lod = max(lod, 0.0);
                
                vec3 hitColor = pow(texture2DLod(colortex0, jitteredUV, lod).rgb, vec3(1.0)) * 1.0 - nightFactor * 0.2;;
                
                vec3 hitNormalEncoded = texture2DLod(colortex5, jitteredUV, 0.0).rgb;
                vec3 hitNormal = normalize(hitNormalEncoded * 2.0 - 1.0);
                vec3 hitAlbedo = texture2DLod(colortex0, jitteredUV, 0.0).rgb;
                float hitSmoothness = texture2DLod(colortex6, jitteredUV, 0.0).r;



                vec3 voxelTint = CheckVoxelTint(currentPos, hit.worldPos);

                vec3 brdf = EvaluateBRDF(hitAlbedo, currentNormal, rayDir, -normalize(currentPos));
                float pdf = CosinePDF(NdotL);

                vec3 throughputMult = brdf * NdotL / max(pdf, 0.0001);
                pathThroughput *= sqrt(throughputMult + 0.01);

                #if defined (PT_TRANSPARENT_TINTS) && defined (PT_USE_VOXEL_LIGHT)
                    pathThroughput *= voxelTint;
                #endif

                #ifdef PT_USE_VOXEL_LIGHT
                int voxelID = int(texture2DLod(colortex10, jitteredUV, 0.0).a * 255.0 + 0.5);

                if (voxelID > 1 && voxelID < 100) {
                    vec4 blockLightColor = GetSpecialBlocklightColor(voxelID);
                    vec3 boostedColor = blockLightColor.rgb;
                    vec3 emissiveColor = pow(boostedColor, vec3(1.0 / 8.0)) * PT_EMISSIVE_I;
                    #ifdef PT_TRANSPARENT_TINTS
                        emissiveColor *= voxelTint;
                    #endif
                    emissiveRadiance += pathThroughput * emissiveColor * hitAlbedo;
                }
                #endif

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

                float hitSkyLightFactor = texture2DLod(colortex6, jitteredUV, 0.0).b;
                float directLightMask = 1.0 - pow2(hitSkyLightFactor) * 0.85;
                
               if (bounce == PT_MAX_BOUNCES - 1) {
                    pathRadiance += pathThroughput * hitColor * 0.5 * directLightMask;
                }
                
            } else {
                // Sky contribution
                vec3 sampledSky = ambientColor * SKY_I * min(2.0 * skyLightFactor, 1.0) - (nightFactor * 0.25);
                vec3 worldRayDir = mat3(gbufferModelViewInverse) * rayDir;
                vec3 skyContribution = sampledSky * max(worldRayDir.y, 0.0);
                skyContribution -= nightFactor * 0.1;
                
                pathRadiance += pathThroughput * skyContribution;
                break;
            }
        } 
        
        totalRadiance += pathRadiance;
        
        // AO calculation
        float aoDither = fract(dither + float(i) * PHI_INV);
        RayHit firstHit = MarchRay(startPos, RayDirection(normalMR, dither, i), depthtex, screenEdge, aoDither);
        if (firstHit.hit) {
            float aoRadius = AO_RADIUS;
            float curve = 1.0 - clamp(firstHit.hitDist / aoRadius, 0.0, 1.0);
            curve = pow(curve, 2.0);
            occlusion += curve * AO_I * 1.5 * max(skyLightFactor, 0.1) - (nightFactor * 1.5 + invNoonFactor * 1.0);
        }
    }
    
    totalRadiance /= float(numPaths);
    emissiveRadiance /= float(numPaths);
    occlusion /= float(numPaths);
    
    #if defined DEFERRED1 && defined TEMPORAL_FILTER
        giScreenPos = vec3(texCoord, 1.0);
    #endif
    
    emissiveOut = emissiveRadiance;
    
    gi.rgb = totalRadiance * receiverShadowMask;
    gi.rgb = max(gi.rgb, vec3(0.0));
    
    return gi;
}