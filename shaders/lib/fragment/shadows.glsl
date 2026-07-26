#ifndef SHADOWS_GLSL
#define SHADOWS_GLSL

#ifndef FRAME_COUNTER_DECLARE
#define FRAME_COUNTER_DECLARE
#endif


float shadow2DLinear(sampler2D shadowTex, vec2 uv, float receiverDepth) {
    ivec2 texSize = textureSize(shadowTex, 0);
    vec2 f = fract(uv * vec2(texSize) - 0.5);
    
    vec4 depths = textureGather(shadowTex, uv);
    vec4 comparisons = step(receiverDepth, depths);
    

    float shadowBottom = mix(comparisons.w, comparisons.z, f.x);
    float shadowTop = mix(comparisons.x, comparisons.y, f.x);
    return mix(shadowBottom, shadowTop, f.y);
}

vec3 getShadow(float material) {
    vec4 worldPos = getWorldPosition();
    vec3 playerPos = worldPos.xyz;

    float NdotL = max(dot(normal, lightVector), 0.0);

    float distance = length(playerPos);

    vec3 normalWorld = normalize(mat3(gbufferModelViewInverse) * normal);
    vec3 bias = 0.25 * normalWorld * clamp(0.12 + 0.01 * distance, 0.0, 1.0) * (2.0 - clamp(NdotL, 0.0, 1.0));
    vec3 edge = (0.1 - 0.2 * fract(playerPos + cameraPosition + normalWorld * 0.01)) * (1.0 - lightmap.y);

    playerPos += bias + edge;

    worldPos.xyz = playerPos;

    vec4 shadowPos = toShadowSpace(worldPos);
    

    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 || shadowPos.y < 0.0 || shadowPos.y > 1.0 || shadowPos.z < 0.0 || shadowPos.z > 1.0) {
        return vec3(1.0);
    }

    float distortedDist = length(shadowPos.xy * 2.0 - 1.0);
    float distortFactor = (1.0 - SHADOW_MAP_BIAS) / max(1.0 - distortedDist * SHADOW_MAP_BIAS, 0.0001);

    float resolutionScale = 4096.0 / float(shadowMapResolution);
    float receiverDepth = shadowPos.z - 0.00006 * resolutionScale;


    if (material > 0.16 && material < 0.83) {
        receiverDepth -= 0.000175;
    }

    #ifdef SHADOW_FILTER
        vec2 ditherCoord = floor(gl_FragCoord.xy);
        float ditherVal = interleavedGradientNoise(ditherCoord, frameCounter);
        float phi = ditherVal * 6.283185307179586;
        
        const float cosGold = -0.7373688220971415; // cos(2.399963229728653)
        const float sinGold = 0.6754902942615236;  // sin(2.399963229728653)

        float penumbraScale = 0.0092; 
        float minFilterRadius = 0.375 / (float(shadowMapResolution) * max(distortFactor, 0.001)); 
        float maxFilterRadius = 0.0015 / max(distortFactor, 0.001); 

        int blockerSearchSteps = 16;
        float blockerSum = 0.0;
        int numBlockers = 0;
        float searchRadius = maxFilterRadius; 

        vec2 bDir = vec2(cos(phi), sin(phi));
        float rcpSqrtBlocker = 1.0 / sqrt(float(blockerSearchSteps));

        for (int i = 0; i < blockerSearchSteps; i++) {
            float r = sqrt(float(i) + ditherVal) * rcpSqrtBlocker;
            vec2 offset = bDir * r * searchRadius;
            vec4 gatheredDepths = textureGather(shadowtex0, shadowPos.xy + offset);
            

            if (gatheredDepths.x < receiverDepth) { blockerSum += gatheredDepths.x; numBlockers++; }
            if (gatheredDepths.y < receiverDepth) { blockerSum += gatheredDepths.y; numBlockers++; }
            if (gatheredDepths.z < receiverDepth) { blockerSum += gatheredDepths.z; numBlockers++; }
            if (gatheredDepths.w < receiverDepth) { blockerSum += gatheredDepths.w; numBlockers++; }

            bDir = vec2(bDir.x * cosGold - bDir.y * sinGold, bDir.x * sinGold + bDir.y * cosGold);
        }

        // PCSS early-out: the blocker search just probed 64 shadowtex0 texels
        // across the FULL maxFilterRadius disk (a superset of any PCF radius
        // below, and shadowtex1's occluders are a subset of shadowtex0's). No
        // blockers found => fully lit; skip the whole PCF loop. This is the
        // common case for open sunlit terrain.
        if (numBlockers == 0) {
            return vec3(1.0);
        }

        float filterRadius = minFilterRadius;

        if (numBlockers > 0) {
            float avgBlockerDepth = blockerSum / float(numBlockers);
            float penumbra = max(receiverDepth - avgBlockerDepth, 0.0);
            
            float calculatedRadius = penumbra * penumbraScale / max(distortFactor, 0.001);
            filterRadius = clamp(calculatedRadius, minFilterRadius, maxFilterRadius);

            filterRadius *= mix(0.65, 1.35, ditherVal);
        }


        if (material > 0.16 && material < 0.83) {
            // force a large minimum blur radius for subsurface scattering to prevent sharp self-shadowing from nearby leaves.
            filterRadius = max(filterRadius, maxFilterRadius * 0.8);
        }

        if (numBlockers == blockerSearchSteps * 4) {
            float avgBlockerDepth = blockerSum / float(numBlockers);
            float penumbra = max(receiverDepth - avgBlockerDepth, 0.0);
            if (penumbra < 0.0001) {
                float shadow0 = shadow2DLinear(shadowtex0, shadowPos.xy, receiverDepth);
                float shadow1 = shadow2DLinear(shadowtex1, shadowPos.xy, receiverDepth);
                vec4 shadowCol = texture(shadowcolor0, shadowPos.xy);
                return mix(shadowCol.rgb * shadow1, vec3(1.0), shadow0);
            }
        }

        int pcfSamples = SHADOW_FILTER_QUALITY;
        vec3 finalShading = vec3(0.0);
        float weightSum = 0.0;


        vec2 dir = vec2(cos(phi), sin(phi));
        float rcpSqrtSamples = 1.0 / sqrt(float(pcfSamples));

        for (int i = 0; i < pcfSamples; i++) {
            float r = sqrt(float(i) + ditherVal) * rcpSqrtSamples;
            float weight = exp(-3.0 * r * r); 
            vec2 offset = dir * r * filterRadius;

            float shadow0 = shadow2DLinear(shadowtex0, shadowPos.xy + offset, receiverDepth);
            float shadow1 = shadow2DLinear(shadowtex1, shadowPos.xy + offset, receiverDepth);
            vec4 shadowCol = texture(shadowcolor0, shadowPos.xy + offset);

            finalShading += mix(shadowCol.rgb * shadow1, vec3(1.0), shadow0) * weight;
            weightSum += weight;


            dir = vec2(dir.x * cosGold - dir.y * sinGold, dir.x * sinGold + dir.y * cosGold);
        }

        finalShading /= max(weightSum, 0.0001);
        return finalShading;
    #else
        float shadow0 = shadow2DLinear(shadowtex0, shadowPos.xy, receiverDepth);
        float shadow1 = shadow2DLinear(shadowtex1, shadowPos.xy, receiverDepth);
        vec4 shadowCol = texture(shadowcolor0, shadowPos.xy);
        return mix(shadowCol.rgb * shadow1, vec3(1.0), shadow0);
    #endif
}

#endif
