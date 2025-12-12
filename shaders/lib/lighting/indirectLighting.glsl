/*
    --------------------------------------------PLEASE READ--------------------------------------------
    This ray tracing code was originally developed by Chocapic13.
    The specific implementation used here is derived from the Bliss Shaders by Xonk,
    and has been heavily modified from Bliss's version of Chocapic13’s original ray tracing code.
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

    // GI_MODE 0: Performance Raymarching (Fixed/Expanding Step)
    // GI_MODE 1: Accuracy Raymarching (Screen-Space DDA)
    #define GI_MODE 0 // [0 1]

    float rand(float dither, int i) {
        return fract(dither + float(i) * 0.61803398875);
    }

    // Unified RayDirection (Standard Cosine-Weighted Hemisphere Sampling)
    vec3 RayDirection(vec3 normal, float dither, int i) {
        vec2 Xi = vec2(rand(dither, i), rand(dither, i + 1));
        
        float theta = 6.28318530718 * Xi.y;
        float r = sqrt(Xi.x);
        vec3 hemi = vec3(r * cos(theta), r * sin(theta), sqrt(1.0 - Xi.x));
        
        // Build TBN Frame
        vec3 T = normalize(cross(abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0), normal));
        vec3 B = cross(normal, T);
        
        // Transform hemisphere sample to world/view space
        return (T * hemi.x) + (B * hemi.y) + (normal * hemi.z);
    }

    vec3 toClipSpace3(vec3 viewSpacePosition) {
        vec4 clipSpace = gbufferProjection * vec4(viewSpacePosition, 1.0);

        return clipSpace.xyz / clipSpace.w * 0.5 + 0.5;
    }

    vec3 giScreenPos = vec3(0.0);
    vec4 GetGI(inout vec3 occlusion, vec3 normalM, vec3 viewPos, vec3 nViewPos, sampler2D depthtex, float dither, float skyLightFactor, float smoothness, float VdotU, float VdotS, bool entityOrHand) {
        vec2 screenEdge = vec2(0.6, 0.55);
        vec3 normalMR = normalM;

        vec4 gi = vec4(0.0);
        vec3 radiance = vec3(0.0);
        
        vec3 start = viewPos + normalMR * 0.01;

        vec3 startWorldPos = mat3(gbufferModelViewInverse) * start;
        float distanceScale = clamp(1.0 - start.z / far, 0.1, 1.0);
        int maxIterations = int(RT_SAMPLES * distanceScale);
        
        for (int i = 0; i < maxIterations; i++) {
            vec3 rayDir = RayDirection(normalMR, dither, i);
            float NdotL = max(dot(normalMR, rayDir), 0.0);

            // --- Sky Light Contribution (Same in both modes) ---
            float skyWeight = max(rayDir.y, pow(skyLightFactor, 2.0)) * 1.0 + 0.05;

            #ifdef OVERWORLD
                vec3 sampledSky = pow((ambientColor * 0.5 + GetSky(VdotU, VdotS, dither, false, false) * 0.5), vec3(1.0 / 2.2)) * SKY_I;
                vec3 skyContribution = sampledSky * skyWeight;
            #else
                vec3 skyContribution = ambientColor * 0.1 * skyWeight;
            #endif
            radiance += skyContribution; // Sky light is accumulated regardless of hit

            bool hit = false;
            float hitDist = 0.0;
            vec3 hitPos = vec3(0.0);

            #if GI_MODE == 0
                // ==================== GI_MODE 0: Performance Raymarching (Fixed/Expanding Step) ====================
                
                float stepSize = 0.05;
                vec3 rayPos = start;
                
                // Track depth bounds in screen space
                vec4 initialClip = gbufferProjection * vec4(rayPos, 1.0);
                vec3 initialScreen = initialClip.xyz / initialClip.w * 0.5 + 0.5;
                float minZ = initialScreen.z;
                float maxZ = initialScreen.z;

                for (int j = 0; j < int(RT_STEPS); j++) {
                    rayPos += rayDir * stepSize;
                    
                    vec4 rayClip = gbufferProjection * vec4(rayPos, 1.0);
                    vec3 rayScreen = rayClip.xyz / rayClip.w * 0.5 + 0.5;
                    
                    if (rayScreen.x < 0.0 || rayScreen.x > 1.0 || 
                        rayScreen.y < 0.0 || rayScreen.y > 1.0) break;
                    
                    float sampledDepth = texture2D(depthtex, rayScreen.xy).r;
                    
                    float currZ = GetLinearDepth(rayScreen.z);
                    float nextZ = GetLinearDepth(sampledDepth);
                    
                    // Check if ray intersects geometry using bounds (Refinement removed)
                    if (nextZ < currZ && (sampledDepth <= max(minZ, maxZ) && sampledDepth >= min(minZ, maxZ))) {
                        // Estimate hitPos as midpoint of last step for consistency/simplicity
                        hitPos = rayPos - rayDir * stepSize * 0.5; 
                        vec4 hitClip = gbufferProjection * vec4(hitPos, 1.0);
                        giScreenPos = hitClip.xyz / hitClip.w * 0.5 + 0.5;
                        hitDist = length(hitPos - start);
                        hit = true;
                        break;
                    }
                    
                    // Update depth bounds with bias
                    float biasamount = 0.00005;
                    minZ = maxZ - biasamount / currZ;
                    maxZ = rayScreen.z;
                    
                    // Expanding step size from performance code
                    stepSize = min(stepSize, 0.1) * 2.0;
                }

            #elif GI_MODE == 1
                // ==================== GI_MODE 1: Accuracy Raymarching (Screen-Space DDA) ====================
                
                vec3 worldpos = mat3(gbufferModelViewInverse) * start;
                float distMetric = 1.0 + 2.0 * length(worldpos) / far;
                float stepSizeMetric = distMetric / 10.0;

                vec4 clipPos4 = gbufferProjection * vec4(start, 1.0);
                vec3 clipPosition = clipPos4.xyz / clipPos4.w * 0.5 + 0.5;

                float rayLength = ((start.z + rayDir.z * sqrt(3.0) * far) > -sqrt(3.0) * near) ?
                                (-sqrt(3.0) * near - start.z) / rayDir.z : sqrt(3.0) * far;

                vec3 endPos = start + rayDir * rayLength;
                vec4 endClip4 = gbufferProjection * vec4(endPos, 1.0);
                vec3 end = endClip4.xyz / endClip4.w * 0.5 + 0.5;

                vec3 direction = end - clipPosition;
                
                float len = max(abs(direction.x) / texelSize.x, abs(direction.y) / texelSize.y) * stepSizeMetric;

                vec3 maxLengths = (step(0.0, direction) - clipPosition) / direction;
                float mult = min(min(maxLengths.x, maxLengths.y), maxLengths.z) * 2000.0;
                
                vec3 stepv = direction / len;
                
                int iterations = min(int(min(len, mult * len) - 2.0), RT_STEPS);
                
                vec3 spos = clipPosition;
                spos += stepv * dither;
                spos += stepv * 0.3;
                
                float biasamount = 0.00005;
                float minZ = spos.z - biasamount / GetLinearDepth(spos.z);
                float maxZ = spos.z;
                
                float CURVE = 0.0;

                for (int j = 0; j < iterations; j++) {
                    // check bounds
                    if (spos.x < 0.0 || spos.y < 0.0 || spos.z < 0.0 || 
                        spos.x > 1.0 || spos.y > 1.0 || spos.z > 1.0) break;
                    
                    float sp = texture2D(depthtex, spos.xy).r;
                    
                    float currZ = GetLinearDepth(spos.z);
                    float nextZ = GetLinearDepth(sp);
                    
                    // check if ray intersects geometry using bounds
                    if (nextZ < currZ && (sp <= max(minZ, maxZ) && sp >= min(minZ, maxZ))) {
                        hitPos = spos;
                        giScreenPos = hitPos;
                        
                        // Reconstruct view-space hit position
                        vec3 hitViewPos = vec3(hitPos.xy, texture2D(depthtex, hitPos.xy).r);
                        hitViewPos = hitViewPos * 2.0 - 1.0;
                        vec4 hitView4 = gbufferProjectionInverse * vec4(hitViewPos, 1.0);
                        hitViewPos = hitView4.xyz / hitView4.w;
                        
                        hitDist = length(hitViewPos - start);
                        hit = true;
                        
                        break;
                    }
                    
                    // update depth bounds
                    minZ = maxZ - biasamount / currZ;
                    maxZ += stepv.z;
                    
                    #ifdef HALF_RAY_STEPS
                        spos += stepv;
                    #else
                        spos += stepv;
                    #endif
                    CURVE += 1.0 / float(iterations);
                }
            #endif
            
            // --- Common Accumulation Logic (from 'accuracy' code) ---
            if (hit && giScreenPos.z < 0.99997) {
                // CURVE calculation is only done in GI_MODE 1, so we need a placeholder/estimate for GI_MODE 0
                float CURVE_ADJUSTED = 1.0; 
                #if GI_MODE == 1
                    // CURVE is calculated in the GI_MODE 1 loop
                    CURVE_ADJUSTED = 1.0 - pow(1.0 - pow(1.0 - CURVE, 2.0), 5.0);
                    CURVE_ADJUSTED = mix(CURVE_ADJUSTED, 1.0, clamp(start.z / far, 0.0, 1.0));
                #elif GI_MODE == 0
                    // Heuristic for GI_MODE 0 (distance-based occlusion)
                    float aoRadius = 2.0;
                    CURVE_ADJUSTED = 1.0 - clamp(hitDist / aoRadius, 0.0, 1.0); 
                    CURVE_ADJUSTED = pow(CURVE_ADJUSTED, 2.0); 
                #endif

                vec2 absPos = abs(giScreenPos.xy - 0.5);
                vec2 cdist = absPos / screenEdge;
                float border = clamp(1.0 - pow(max(cdist.x, cdist.y), 50.0), 0.0, 1.0);
                
                if (border > 0.001) {
                    vec2 edgeFactor = pow2(pow2(pow2(cdist)));
                    giScreenPos.y += (dither - 0.5) * (0.05 * (edgeFactor.x + edgeFactor.y));

                    vec3 incomingRadiance = vec3(0.0);
                    float lod = log2(hitDist * 0.5) * 0.5;
                    lod = max(lod, 0.0);
                    
                    incomingRadiance = pow(texture2DLod(colortex0, giScreenPos.xy, lod).rgb, vec3(2.2)) * 0.05 * GI_I;
                    float hitFoliage = texture2D(colortex10, giScreenPos.xy).a;

                    if (hitFoliage > 0.9) {
                        incomingRadiance *= 0.1;
                    }

                    // --- NEW LOGIC: Scale down incomingRadiance on the illuminated side ---
                    // If NdotL = 1 (fully lit side), giScale = 0 (no incomingRadiance).
                    // If NdotL = 0 (perpendicular side), giScale = 1 (full incomingRadiance).
                    vec3 texture5 = texelFetch(colortex5, texelCoord, 0).rgb;
                    vec3 n2 = mat3(gbufferModelView) * texture5;
                    float ndotl = normalize(dot(n2, lightVec));
                    float giScale = 1.0 - ndotl;
                    giScale = max(giScale, 1.0); // Clamps it at 1.0, meaning shadowed sides get full GI.
                    
                    incomingRadiance *= giScale;
                    // --- END NEW LOGIC ---
                    
                    radiance += incomingRadiance;
                    
                    occlusion += CURVE_ADJUSTED * 0.25 * AO_I - (nightFactor * 0.25) * skyContribution;

                    //#if GI_MODE == 0
                    //    occlusion *= 1.25;
                    //#endif
                    
                    edgeFactor.x = pow2(edgeFactor.x);
                    edgeFactor = 1.0 - edgeFactor;
                    gi.a += border * edgeFactor.x * edgeFactor.y;
                }
            }
        }
        
        // --- Final Output (from 'accuracy' code) ---
        occlusion /= float(maxIterations);
        
        gi.rgb = max((radiance - (occlusion * 0.2)) / float(maxIterations), 0.0);
        
        #if defined DEFERRED1 && defined TEMPORAL_FILTER
            if (gi.a < 0.001) giScreenPos.z = 1.0;
        #endif

        gi.rgb *= 3.14159265;
        gi.rgb += max((dither - 0.5), 0.0);
        gi.rgb = max(gi.rgb, vec3(0.0));

        return gi;
    }
#endif