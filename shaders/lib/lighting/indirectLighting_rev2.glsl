/*
    --------------------------------------------PLEASE READ--------------------------------------------
    This ray tracing code was originally developed by Chocapic13.
    The specific implementation used here is derived from the Bliss Shaders by Xonk,
    and has been heavily modified from Bliss's version of Chocapic13's original ray tracing code.
    Modified to use world space coordinates for Global Illumination.
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

#define GI_DISTANCE_BOOST
#define GI_RENDER_DISTANCE 2.0
#define GI_BOUNCE 1 //[1 2 3]
#define PREVENT_ACCUMULATION_IN_FOLIAGE
#define EXCLUDE_ENTITIES_IN_RT

vec2 texelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);

float rand(float dither, int i) {
    return fract(dither + float(i) * 0.61803398875);
}

vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

vec2 OffsetDist(float x, int s) {
    float n = fract(x * 1.414) * 3.1415;
    return pow2(vec2(cos(n), sin(n)) * x / s);
}

vec3 toSRGB(vec3 color) {
    return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, color));
}

vec3 toLinear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), vec3(greaterThan(color, vec3(0.04045))));
}

vec3 cosineHemisphereSampleRough(vec2 Xi, float roughness) {
    float exponent = 1.0 / max(roughness * roughness, 0.001);

    float phi = 2.0 * 3.14159265 * Xi.y;
    float cosTheta = pow(1.0 - Xi.x, 1.0 / (exponent + 1.0));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

vec3 CalculateFlux(vec3 incidentLight, vec3 normal, vec3 lightDir, float visibility, float distance, float falloffStrength) {
    float NdotL = 0.5 + 0.5 * dot(normal, lightDir);

    // Optional distance-based attenuation
    float attenuation = 1.0 / (1.0 + falloffStrength * distance * distance);

    return incidentLight * NdotL * visibility * attenuation;
}

vec3 RayDirection(vec3 normal, float dither, int i, float roughness) {
    vec3 up = abs(normal.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(up, normal));
    vec3 bitangent = cross(normal, tangent);

    vec2 Xi = vec2(rand(dither, i));
    vec3 hemi = normalize(cosineHemisphereSampleRough(Xi, roughness));
    return ((tangent * hemi.x) + (bitangent * hemi.y) + (normal * hemi.z));
}

// Convert world space position to screen space
vec3 worldToScreen(vec3 worldPos) {
    vec4 viewPos = gbufferModelView * vec4(worldPos, 1.0);
    vec4 clipPos = gbufferProjection * viewPos;
    vec3 ndcPos = clipPos.xyz / clipPos.w;
    return ndcPos * 0.5 + 0.5;
}

// Convert screen space to world space position
vec3 screenToWorld(vec3 screenPos) {
    vec4 ndcPos = vec4(screenPos * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * ndcPos;
    viewPos /= viewPos.w;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    return worldPos.xyz;
}

// ------------------------------- Filters ------------------------------- //
#if GLOBAL_ILLUMINATION >= 2
    vec4 bilateralBlur(sampler2D tex, sampler2D depthTex, vec2 uv, float radius)
    {
        vec2 texSize = vec2(viewWidth, viewHeight);
        vec2 texelSize = 1.0 / texSize;

        float centerDepth = texture(depthTex, uv).r;

        float totalWeight = 0.0;
        vec4 result = vec4(0.0);

        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                vec2 offset = vec2(x, y) * texelSize * radius;
                vec2 sampleUV = uv + offset;

                float sampleDepth = texture(depthTex, sampleUV).r;
                float spatialWeight = exp(-dot(offset, offset) * 10.0);
                float depthWeight = exp(-abs(sampleDepth - centerDepth) * 50.0);

                float weight = spatialWeight * depthWeight;
                result += texture(tex, sampleUV) * weight;
                totalWeight += weight;
            }
        }

        return result / totalWeight;
    }

    vec4 atrousFilter(
        sampler2D tex,
        sampler2D depthTex,
        vec2 uv,
        int stepWidth
    ) {
        vec2 kernel[5] = vec2[](
            vec2( 0.0,  0.0), // center
            vec2(-1.0,  0.0),
            vec2( 1.0,  0.0),
            vec2( 0.0, -1.0),
            vec2( 0.0,  1.0)
        );

        float centerDepth = texture(depthTex, uv).r;
        vec4 result = vec4(0.0);
        float totalWeight = 0.0;

        for (int i = 0; i < 5; i++) {
            vec2 offset = kernel[i] * float(stepWidth) * texelSize;
            vec2 sampleUV = uv + offset;

            float sampleDepth = texture(depthTex, sampleUV).r;
            float depthWeight = exp(-abs(sampleDepth - centerDepth) * 50.0);
            float spatialWeight = (i == 0) ? 1.0 : 0.25;

            float weight = spatialWeight * depthWeight;
            result += texture(tex, sampleUV) * weight;
            totalWeight += weight;
        }

        return result / totalWeight;
    }
#endif

// ------------------------------- Raytracer (World Space) ------------------------------- //
#if GLOBAL_ILLUMINATION >= 2
    vec3 RaytraceWorldSpace(
        vec3 worldOrigin,
        vec3 worldDir,
        float dither,
        out bool hitFound,
        out vec3 hitColor,
        out bool hitIsFoliage,
        float maxStepsMul
    ) {
        // Transform to screen space for marching
        vec3 screenStart = worldToScreen(worldOrigin);
        vec3 screenEnd = worldToScreen(worldOrigin + worldDir * GI_RENDER_DISTANCE);
        
        vec3 screenDir = screenEnd - screenStart;
        float rayLength = length(screenDir);
        screenDir = normalize(screenDir);

        // Calculate step size based on screen space distance
        float stepSize = STEP_SCALE;
        float steps = rayLength / (stepSize * max(texelSize.x, texelSize.y));
        
        int maxSteps = min(int(steps), int(maxStepsMul));
        
        vec3 stepVec = screenDir * stepSize * max(texelSize.x, texelSize.y);
        vec3 tracePos = screenStart;

        hitFound = false;
        hitColor = vec3(0.0);
        hitIsFoliage = false;

        for (int k = 0; k < maxSteps; ++k) {
            // Check bounds
            if (tracePos.x < 0.0 || tracePos.y < 0.0 || tracePos.z < 0.0 || 
                tracePos.x > 1.0 || tracePos.y > 1.0 || tracePos.z > 1.0) {
                return tracePos;
            }

            ivec2 texelCoord = ivec2(tracePos.xy / texelSize);
            float depthSample = texelFetch(depthtex1, texelCoord, 0).r;
            
            // Convert both to world space for comparison
            vec3 worldRayPos = screenToWorld(tracePos);
            vec3 worldScenePos = screenToWorld(vec3(tracePos.xy, depthSample));
            
            float distToScene = length(worldScenePos - worldOrigin);
            float distAlongRay = length(worldRayPos - worldOrigin);

            if (distAlongRay >= distToScene - 0.01) {
                hitColor = toLinear(texture2D(colortex2, tracePos.xy).rgb) * GI_INTENSITY;
                
                float foliageFlag = texelFetch(colortex6, texelCoord, 0).a;
                hitIsFoliage = foliageFlag > 0.5;
                
                if (hitIsFoliage) hitColor *= 0.75;
                
                hitFound = true;
                break;
            }

            #ifdef GI_DISTANCE_BOOST
                tracePos += stepVec * mix(1.0, 2.0, dither);
            #else
                tracePos += stepVec;
            #endif
        }

        return tracePos;
    }
#endif

// ------------------------------- Ambient Occlusion ------------------------------- //
#if GLOBAL_ILLUMINATION == 1 || GLOBAL_ILLUMINATION == 3
    // non-rt
    float SSAO(float z0, float linearZ0, float dither) {
        if (z0 < 0.56) return 1.0;

        int samples = 4;
        float scm = 0.4;
        float ao = 0.0;

        float fovScale = gbufferProjection[1][1];
        float distScale = max(farMinusNear * linearZ0 + near, 3.0);
        vec2 scale = vec2(scm / aspectRatio, scm) * fovScale / distScale;

        for (int i = 1; i <= samples; i++) {
            vec2 offset = OffsetDist(i + dither, samples) * scale;
            if (i % 2 == 0) offset.y = -offset.y;

            vec2 coord1 = texCoord + offset;
            vec2 coord2 = texCoord - offset;

            float sampleDepth = GetLinearDepth(texture2D(depthtex0, coord1).r);
            float aosample = farMinusNear * (linearZ0 - sampleDepth) * 2.0;
            float angle = clamp(0.5 - aosample, 0.0, 1.0);
            float dist = clamp(0.5 * aosample - 1.0, 0.0, 1.0);

            sampleDepth = GetLinearDepth(texture2D(depthtex0, coord2).r);
            aosample = farMinusNear * (linearZ0 - sampleDepth) * 2.0;
            angle += clamp(0.5 - aosample, 0.0, 1.0);
            dist += clamp(0.5 * aosample - 1.0, 0.0, 1.0);

            ao += clamp(angle + dist, 0.0, 1.0);
        }

        ao /= float(samples);
        return pow(ao, AO_I);
    }
#endif

#if GLOBAL_ILLUMINATION == 2 || GLOBAL_ILLUMINATION == 4
    float RTAO(vec3 worldPos, vec3 worldNormal, float skyLightFactor, float dither) {
        const float r = 1.0;
        float occlusion = 0.0;
        float invSamples = 1.0 / float(RTAO_SAMPLES);

        for (int i = 0; i < RTAO_SAMPLES; ++i) {
            vec3 rayDir = RayDirection(worldNormal, dither, i, r);
            vec3 rayOrigin = worldPos + worldNormal * SURFACE_BIAS;

            bool hitFound;
            bool hitIsFoliage;
            vec3 hitColor;
            vec3 tracePos = RaytraceWorldSpace(rayOrigin, rayDir, dither, hitFound, hitColor, hitIsFoliage, float(RTAO_STEP));

            if (hitFound) {
                vec3 worldHitPos = screenToWorld(tracePos);
                float hitDist = length(worldHitPos - worldPos);
                float attenuate = 1.0 - smoothstep(0.0, AO_RADIUS, hitDist);
                occlusion += attenuate * 0.5 * AO_I;
            }
        }

        return clamp(1.0 - occlusion * invSamples, 0.0, 1.0);
    }
#endif

// ------------------------------- Global Illumination (World Space) ------------------------------- //
#if GLOBAL_ILLUMINATION == 3 || GLOBAL_ILLUMINATION == 4
    vec3 GlobalIllumination(
        vec3 worldPos,
        vec3 worldNormal,
        float VdotU,
        float VdotS,
        float skyLightFactor,
        float linearZ0,
        float dither
    ) {
        const float r = 0.9;

        vec3 totalGI = vec3(0.0);
        vec3 contribution = vec3(0.0);

        for (int i = 0; i < GI_SAMPLES; ++i) {
            vec3 bounceOrigin = worldPos + worldNormal * SURFACE_BIAS;

            vec3 rayDir = RayDirection(worldNormal, dither + float(i), i, r);

            bool hitFound = false;
            bool hitIsFoliage = false;
            vec3 hitColor = vec3(0.0);
            vec3 tracePos = RaytraceWorldSpace(bounceOrigin, rayDir, dither, hitFound, hitColor, hitIsFoliage, 10.0);

            if (hitFound) {
                vec3 worldHitPos = screenToWorld(tracePos);
                float hitDistance = length(worldHitPos - worldPos);
                float fade = exp(-clamp(hitDistance / 4.0, 0.0, 1.0));

                hitColor += CalculateFlux(hitColor, worldNormal, rayDir, r, hitDistance, 0.5);

                contribution = clamp(hitColor, 0.0, 1.0) * fade;
            }
            else {
                #ifdef OVERWORLD
                    contribution = GetSky(VdotU, VdotS, dither, false, true) * 0.25 * skyLightFactor;
                #endif
            }
            totalGI += contribution / float(GI_SAMPLES);
        }

        return totalGI;
    }

    vec3 GITonemap(vec3 color) {
        color = clamp(color, 0.0, 10.0);

        float exposure = 0.9 - (rainFactor * 0.05);

        float saturation = 1.1;
        float gamma = 1.0;
        float contrast = 1.3;

        color *= exposure;

        const mat3 m1 = mat3(
            0.59719, 0.07600, 0.02840,
            0.35458, 0.90834, 0.13383,
            0.04823, 0.01566, 0.83777
        );

        const mat3 m2 = mat3(
            1.60475, -0.10208, -0.00327,
            -0.53108,  1.10813, -0.07276,
            -0.07367, -0.00605,  1.07602
        );

        vec3 v = m1 * color;
        vec3 a = v * (v + 0.0245786) - 0.000090537;
        vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
        vec3 tonemapped = m2 * (a / b);

        float luminance = dot(tonemapped, vec3(0.2126, 0.7152, 0.0722));
        tonemapped = mix(vec3(luminance), tonemapped, saturation);
        tonemapped = mix(vec3(0.5), tonemapped, contrast);

        return pow(clamp(tonemapped, 0.0, 1.0), vec3(1.0 / gamma));
    }
#endif

// ------------------------------- Apply ------------------------------- //
#ifdef GLOBAL_ILLUMINATION > 1
    vec3 DoRT(
        vec3 color, 
        vec3 worldPos,
        vec3 worldNormal, 
        float skyLightFactor, 
        float linearZ0, 
        float dither, 
        bool entityOrHand,
        float smoothnessD
    ) {
        float VdotU = dot(worldNormal, upVec);
        float VdotS = dot(worldNormal, sunVec);
        float VdotL = dot(worldNormal, lightVec);

        #ifdef EXCLUDE_ENTITIES_IN_RT
        if (!entityOrHand) {
        #endif

            #if GLOBAL_ILLUMINATION == 3
                color += GITonemap(GlobalIllumination(worldPos, worldNormal, VdotU, VdotS, skyLightFactor, linearZ0, dither)) * 1.0;
            #elif GLOBAL_ILLUMINATION == 4
                color += GITonemap(GlobalIllumination(worldPos, worldNormal, VdotU, VdotS, skyLightFactor, linearZ0, dither)) * 1.35;
            #endif

            #if GLOBAL_ILLUMINATION == 2 || GLOBAL_ILLUMINATION == 4
                color *= RTAO(worldPos, worldNormal, skyLightFactor, dither);
            #endif

        #ifdef EXCLUDE_ENTITIES_IN_RT
        }
        #endif
        return color;
    }
#endif