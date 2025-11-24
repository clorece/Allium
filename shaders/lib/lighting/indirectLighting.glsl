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

    float rand(float dither, int i) {
        return fract(dither + float(i) * 0.61803398875);
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

    vec3 giScreenPos = vec3(0.0);
    vec4 GetGI(inout vec3 occlusion, vec3 normalM, vec3 viewPos, vec3 nViewPos, sampler2D depthtex, float dither, float skyLightFactor, float smoothness, float VdotU, float VdotS, bool entityOrHand) {
        vec2 screenEdge = vec2(0.6, 0.55);
        vec3 normalMR = normalM;

        vec4 gi = vec4(0.0);
        vec3 radiance = vec3(0.0);  // Change: separate radiance from occlusion
        //vec3 occlusion = vec3(0.0);
        
        vec3 start = viewPos + normalMR * 0.01;

        vec3 worldpos = mat3(gbufferModelViewInverse) * start;
        float dist = 1.0 + 2.0 * length(worldpos) / far;
        float stepSize = dist / 10.0;

        float foliage = texture2D(colortex10, texCoord).a;

        vec3 startWorldPos = mat3(gbufferModelViewInverse) * start;
        float distanceScale = clamp(1.0 - start.z / far, 0.1, 1.0);
        int maxIterations = int(RT_SAMPLES * distanceScale);
        
        for (int i = 0; i < maxIterations; i++) {
            vec3 rayDir = RayDirection(normalMR, dither, i);
            float NdotL = max(dot(normalMR, rayDir), 0.0);

            float skyWeight = max(rayDir.y, pow(skyLightFactor, 2.0)) * 1.0 + 0.05;

            #ifdef OVERWORLD
                vec3 sampledSky = pow((ambientColor * 0.5 + GetSky(VdotU, VdotS, dither, false, false) * 0.5), vec3(1.0 / 2.2)) * SKY_I;
                
                vec3 skyContribution = sampledSky * skyWeight;
            #else
                vec3 skyContribution = ambientColor * 0.1 * skyWeight;
            #endif

            vec4 clipPos4 = gbufferProjection * vec4(start, 1.0);
            vec3 clipPosition = clipPos4.xyz / clipPos4.w * 0.5 + 0.5;

            float rayLength = ((start.z + rayDir.z * sqrt(3.0) * far) > -sqrt(3.0) * near) ?
                            (-sqrt(3.0) * near - start.z) / rayDir.z : sqrt(3.0) * far;

            vec3 endPos = start + rayDir * rayLength;
            vec4 endClip4 = gbufferProjection * vec4(endPos, 1.0);
            vec3 end = endClip4.xyz / endClip4.w * 0.5 + 0.5;

            vec3 direction = end - clipPosition;
            
            float len = max(abs(direction.x) / texelSize.x, abs(direction.y) / texelSize.y) * stepSize;

            vec3 maxLengths = (step(0.0, direction) - clipPosition) / direction;
            float mult = min(min(maxLengths.x, maxLengths.y), maxLengths.z) * 2000.0;
            
            vec3 stepv = direction / len;
            
            int iterations = min(int(min(len, mult * len) - 2.0), RT_STEPS);
            
            vec3 spos = clipPosition;
            spos += stepv * dither;
            spos += stepv * 0.3;
            
            bool hit = false;
            float hitDist = 0.0;
            vec3 hitPos = vec3(0.0);
            
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

            radiance += skyContribution;
            
            if (hit && giScreenPos.z < 0.99997) {
                CURVE = 1.0 - pow(1.0 - pow(1.0 - CURVE, 2.0), 5.0);
                CURVE = mix(CURVE, 1.0, clamp(start.z / far, 0.0, 1.0));
                
                vec2 absPos = abs(giScreenPos.xy - 0.5);
                vec2 cdist = absPos / screenEdge;
                float border = clamp(1.0 - pow(max(cdist.x, cdist.y), 50.0), 0.0, 1.0);
                
                if (border > 0.001) {
                    vec2 edgeFactor = pow2(pow2(pow2(cdist)));
                    giScreenPos.y += (dither - 0.5) * (0.05 * (edgeFactor.x + edgeFactor.y));

                    vec3 incomingRadiance = vec3(0.0);
                    float lod = log2(hitDist * 0.5) * 0.5;
                    lod = max(lod, 0.0);
                    incomingRadiance = pow(texture2DLod(colortex0, giScreenPos.xy, lod).rgb, vec3(1.5)) * 0.125 * GI_I;
                    float hitFoliage = texture2D(colortex10, giScreenPos.xy).a;

                    if (hitFoliage > 0.9) {
                        incomingRadiance *= 0.425;
                    }

                    radiance += incomingRadiance;
                    
                    occlusion += CURVE * 0.3 * AO_I - (nightFactor * 0.25); // nightfactor since ao is way too dark at night
                    
                    edgeFactor.x = pow2(edgeFactor.x);
                    edgeFactor = 1.0 - edgeFactor;
                    gi.a += border * edgeFactor.x * edgeFactor.y;
                }
            }
        }
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
