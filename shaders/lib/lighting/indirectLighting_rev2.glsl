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

/*
    and ty chatgpt o7
    lol
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

// ------------------------------- Raytracer ------------------------------- //
#if GLOBAL_ILLUMINATION >= 2
    vec3 Raytrace(
        vec3 origin,
        vec3 dir,
        float dither,
        out bool hitFound,
        out vec3 hitColor,
        out bool hitIsFoliage,
        float maxStepsMul
    ) {
        float dist = 1.0 + clamp(dir.z*dir.z/50.0,0,2);
        float stepSize = STEP_SCALE / dist;

        float rayLength = ((origin.z + dir.z * sqrt(3.0) * far) > -sqrt(3.0) * near)
                        ? (-sqrt(3.0) * near - origin.z) / dir.z
                        : sqrt(3.0) * far;

        vec3 clipStart = toClipSpace(origin);
        vec3 clipEnd = toClipSpace(origin + dir * rayLength);
        vec3 clipDir = clipEnd - clipStart;

        float steps = max(abs(clipDir.x) / texelSize.x, abs(clipDir.y) / texelSize.y) / stepSize;
        float maxFactor = min(min(
            (step(0.0, clipDir) - clipStart).x / clipDir.x,
            (step(0.0, clipDir) - clipStart).y / clipDir.y
        ), (step(0.0, clipDir) - clipStart).z / clipDir.z) * 2000.0;

        int maxSteps = min(int(min(steps, maxFactor * steps) - 2.0), int(maxStepsMul));

        vec3 stepVec = clipDir / steps;
        vec3 tracePos = clipStart + vec3(texelSize * 0.5, 0.0);

        float minZ = tracePos.z;
        float maxZ = tracePos.z;

        hitFound = false;
        hitColor = vec3(0.0);

        float foliageFlag = texelFetch(colortex6, texelCoord, 0).a;
        hitIsFoliage = foliageFlag > 0.5;

        for (int k = 0; k < maxSteps; ++k) {
            if (tracePos.x < 0.0 || tracePos.y < 0.0 || tracePos.z < 0.0 || tracePos.x > 1.0 || tracePos.y > 1.0 || tracePos.z > 1.0) return vec3(1.1);

            ivec2 texelCoord = ivec2(tracePos.xy / texelSize);
            float depthSample = texelFetch(depthtex1, texelCoord, 0).r;
            float depthCurrent = GetLinearDepth(tracePos.z);
            float depthScene = GetLinearDepth(depthSample);

            if (depthScene < depthCurrent && depthSample >= minZ && depthSample <= maxZ) {
                hitColor = toLinear(texture2D(colortex2, tracePos.xy).rgb) * 1.0 * GI_INTENSITY;

                if (hitIsFoliage) hitColor *= 0.75;
                
                hitFound = true;
                break;
            }

            float bias = 0.0005;
            minZ = maxZ - bias / max(depthCurrent, 0.0005); 
            maxZ += stepVec.z;

            #ifdef GI_DISTANCE_BOOST
                tracePos += stepVec * 2.0 * dither;
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
    float RTAO(vec3 viewPos, vec3 normal, float skyLightFactor, float dither) {
        const float r = 1.0;
        float occlusion = 0.0;
        float invSamples = 1.0 / float(RTAO_SAMPLES);

        for (int i = 0; i < RTAO_SAMPLES; ++i) {
            vec3 rayDir = RayDirection(normal, dither, i, r);
            vec3 rayOrigin = viewPos + normal * SURFACE_BIAS;

            bool hitFound;
            bool hitIsFoliage;
            vec3 hitColor;
            vec3 tracePos = Raytrace(rayOrigin, rayDir, dither, hitFound, hitColor, hitIsFoliage, float(RTAO_STEP));

            if (hitFound) {
                float dz = GetLinearDepth(tracePos.z) - GetLinearDepth(toClipSpace(viewPos).z);
                float attenuate = 1.0 - smoothstep(0.0, AO_RADIUS, dz);
                occlusion += attenuate * 0.5 * AO_I;
            }
        }

        //occlusion = pow(occlusion, 2.2);
        return clamp(1.0 - occlusion * invSamples, 0.0, 1.0);
    }

    /* OLD RTAO
    float check(vec3 surfaceNormal, vec3 viewDir, vec3 hitPos, vec3 viewPos) {
        vec3 hitNormal = normalize(cross(dFdx(hitPos), dFdy(hitPos)));
        float facing = dot(hitNormal, surfaceNormal);
        if (facing < 0.3) return 0.0;

        return smoothstep(0.3, 1.0, facing);
    }

    float RTAO(vec3 viewPos, vec3 normal, float skyLightFactor, float dither) {

        float occlusion = 0.0;

        // Tangent space basis
        vec3 up = abs(normal.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 tangent = normalize(cross(up, normal));
        vec3 bitangent = cross(normal, tangent);

        float invSamples = 1.0 / float(RTAO_SAMPLES);
        float stepSize = AO_RADIUS / float(4);

        for (int i = 0; i < RTAO_SAMPLES; ++i) {
            
            float fi = float(i);
            float rand = fract(fi * 0.73 + dither * 4);
            float phi = 6.2831 * (rand);
            float cosTheta = sqrt(1.0 - fi * invSamples);
            float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

            vec3 hemiDir = sinTheta * cos(phi) * tangent +
                        sinTheta * sin(phi) * bitangent +
                        cosTheta * normal;

            vec3 rayDir = hemiDir * stepSize;
            vec3 rayPos = viewPos + normal * 0.01 * texture2D(colortex2, texCoord).rgb;

            for (int j = 0; j < 4; ++j) {
                rayPos += rayDir;

                vec4 projected = gbufferProjection * vec4(rayPos, 1.0);
                if (projected.w <= 0.0) break;

                vec2 screenUV = projected.xy / projected.w * 0.5 + 0.5;
                if (abs(screenUV.x - 0.5) > view.x || abs(screenUV.y - 0.5) > view.y) break;

                float sceneZ = texture2D(depthtex1, screenUV).r;
                vec4 hitClip = vec4(screenUV * 2.0 - 1.0, sceneZ * 2.0 - 1.0, 1.0);
                vec4 hitPos4 = gbufferProjectionInverse * hitClip;
                vec3 hitPos = hitPos4.xyz / hitPos4.w;

                float dz = hitPos.z - rayPos.z;
                float depthDiff = abs(hitPos.z - viewPos.z);

                if (dz > 0.001 && dz < stepSize * 12.0 && depthDiff < AO_RADIUS * 12.0) {
                    float geomFactor = check(normal, rayDir, hitPos, viewPos);
                    float weight = (1.0 - smoothstep(0.0, stepSize * 12.0, dz));
                    //occlusion -= geomFactor;
                    occlusion += weight * AO;
                    break;
                }
            }
        }
        occlusion *= 0.5;

        float ao = 1.0 - (occlusion * invSamples);
        return clamp(ao, 0.0, 1.0);

    }
    */
#endif

// ------------------------------- Global Illumination ------------------------------- //
#if GLOBAL_ILLUMINATION == 3 || GLOBAL_ILLUMINATION == 4
    vec3 GlobalIllumination(
        vec3 viewPos,
        vec3 playerPos,
        vec3 normal,
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
            vec3 bounceOrigin = viewPos + normal * SURFACE_BIAS;

            vec3 rayDir = RayDirection(normal, dither + float(i), i, r);

            bool hitFound = false;
            bool hitIsFoliage = false;
            vec3 hitColor = vec3(0.0);
            vec3 tracePos = Raytrace(bounceOrigin, rayDir, dither, hitFound, hitColor, hitIsFoliage, 10.0);

            if (hitFound) {
                float depthCurrent = GetLinearDepth(toClipSpace(bounceOrigin).z);
                float depthHit = GetLinearDepth(tracePos.z);
                float fade = exp(-clamp((depthCurrent - depthHit) / 4.0, 0.0, 1.0));

                hitColor += CalculateFlux(hitColor, normal, rayDir, r, length(rayDir), 0.5);

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
        //exposure -= nightFactor * 0.1;

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
/*
    vec3 DoRT(
        vec3 color, 
        vec3 viewPos, 
        vec3 playerPos, 
        vec3 normal, 
        float skyLightFactor, 
        float linearZ0, 
        float dither, 
        bool entityOrHand,
        bool isFoliage
    ) {
    */
    vec3 DoRT(
        vec3 color, 
        vec3 viewPos, 
        vec3 playerPos, 
        vec3 normal, 
        float skyLightFactor, 
        float linearZ0, 
        float dither, 
        bool entityOrHand,
        float smoothnessD
    ) {
        float VdotU = dot(normal, upVec);
        float VdotS = dot(normal, sunVec);
        float VdotL = dot(normal, lightVec);

        #ifdef EXCLUDE_ENTITIES_IN_RT
        if (!entityOrHand) {
        #endif

            //bool shadow = GetShadow(viewPos, cameraPosition);
            //float rts = RaytraceShadow(lightVec, viewPos, dither, shadow);

            #if GLOBAL_ILLUMINATION == 3
                color += GITonemap(GlobalIllumination(viewPos, playerPos, normal, VdotU, VdotS, skyLightFactor, linearZ0, dither)) * 1.0;
            #elif GLOBAL_ILLUMINATION == 4
                color += GITonemap(GlobalIllumination(viewPos, playerPos, normal, VdotU, VdotS, skyLightFactor, linearZ0, dither)) * 1.35;
            #endif

            //color += mix(color, vec3(rts), vec3(0.5)) * 0.1;

            #if GLOBAL_ILLUMINATION == 2 || GLOBAL_ILLUMINATION == 4
                color *= RTAO(viewPos, normal, skyLightFactor, dither);
            #endif

        #ifdef EXCLUDE_ENTITIES_IN_RT
        }
        #endif
        return color;
    }
#endif