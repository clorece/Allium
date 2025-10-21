//#define TAA_TWEAKS

// Anti-ghosting and anti-flicker controls
#define TAA_ANTI_GHOST_STRENGTH 30.0    //[5.0 10.0 15.0 20.0 25.0 30.0] Higher = less ghosting but may reduce stability
#define TAA_ANTI_FLICKER_STRENGTH 0.6   //[0.0 0.2 0.4 0.6 0.8 1.0] Higher = less flickering
#define TAA_MOTION_REJECT 1.5           //[0.5 1.0 1.5 2.0 2.5 3.0] Higher = more rejection on subpixel motion
#define TAA_STABILITY_WEIGHT 0.982      //[0.90 0.95 0.97 0.982 0.99 0.995] Base temporal stability weight

#if TAA_MODE == 1
    float blendMinimum = 0.3;
    float blendVariable = 0.2;
    float blendConstant = 0.7;

    float regularEdge = 20.0;
    float extraEdgeMult = 3.0;
#elif TAA_MODE == 2
    float blendMinimum = 1.0;
    float blendVariable = 0.2;
    float blendConstant = 0.7;

    float regularEdge = 5.0;
    float extraEdgeMult = 3.0;
#endif

#ifdef TAA_MOVEMENT_IMPROVEMENT_FILTER
    // Improved Catmull-Rom sampling from taa2
    vec3 textureCatmullRom(sampler2D colortex, vec2 texcoord, vec2 view) {
        vec2 position = texcoord * view;
        vec2 centerPosition = floor(position - 0.5) + 0.5;
        vec2 f = position - centerPosition;
        vec2 f2 = f * f;

        vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
        vec2 w1 = 1.0 + f2 * (-2.5 + 1.5 * f);
        vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
        vec2 w3 = f2 * (-0.5 + 0.5 * f);

        vec2 w12 = w1 + w2;
        vec2 delta12 = w2 / w12;

        vec2 uv0 = centerPosition - 1.0;
        vec2 uv3 = centerPosition + 1.0;
        vec2 uv12 = centerPosition + delta12;

        vec2 viewPixelSize = 1.0 / view;
        uv0 *= viewPixelSize;
        uv3 *= viewPixelSize;
        uv12 *= viewPixelSize;

        vec3 col = vec3(0.0);
        col += texture2DLod(colortex, vec2(uv0.x, uv0.y), 0).rgb * w0.x * w0.y;
        col += texture2DLod(colortex, vec2(uv12.x, uv0.y), 0).rgb * w12.x * w0.y;
        col += texture2DLod(colortex, vec2(uv3.x, uv0.y), 0).rgb * w3.x * w0.y;

        col += texture2DLod(colortex, vec2(uv0.x, uv12.y), 0).rgb * w0.x * w12.y;
        col += texture2DLod(colortex, vec2(uv12.x, uv12.y), 0).rgb * w12.x * w12.y;
        col += texture2DLod(colortex, vec2(uv3.x, uv12.y), 0).rgb * w3.x * w12.y;

        col += texture2DLod(colortex, vec2(uv0.x, uv3.y), 0).rgb * w0.x * w3.y;
        col += texture2DLod(colortex, vec2(uv12.x, uv3.y), 0).rgb * w12.x * w3.y;
        col += texture2DLod(colortex, vec2(uv3.x, uv3.y), 0).rgb * w3.x * w3.y;

        return clamp(col, 0.0, 65535.0);
    }
#endif

// Previous frame reprojection from Chocapic13
vec2 Reprojection(vec4 viewPos1) {
    vec4 pos = gbufferModelViewInverse * viewPos1;
    vec4 previousPosition = pos + vec4(cameraPosition - previousCameraPosition, 0.0);
    previousPosition = gbufferPreviousModelView * previousPosition;
    previousPosition = gbufferPreviousProjection * previousPosition;
    return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
}

vec3 ClipAABB(vec3 q, vec3 aabb_min, vec3 aabb_max){
    vec3 p_clip = 0.5 * (aabb_max + aabb_min);
    vec3 e_clip = 0.5 * (aabb_max - aabb_min) + 0.00000001;

    vec3 v_clip = q - vec3(p_clip);
    vec3 v_unit = v_clip.xyz / e_clip;
    vec3 a_unit = abs(v_unit);
    float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

    if (ma_unit > 1.0)
        return vec3(p_clip) + v_clip / ma_unit;
    else
        return q;
}

// Luminance function from taa2
float getLuma(vec3 color) {
    return dot(color, vec3(0.2125, 0.7154, 0.0721));
}

ivec2 neighbourhoodOffsets[8] = ivec2[8](
    ivec2( 1, 1),
    ivec2( 1,-1),
    ivec2(-1, 1),
    ivec2(-1,-1),
    ivec2( 1, 0),
    ivec2( 0, 1),
    ivec2(-1, 0),
    ivec2( 0,-1)
);

// Improved neighborhood clamping using min/max from taa2
void NeighbourhoodClamping(vec3 color, inout vec3 tempColor, float z0, float z1, inout float edge) {
    vec3 minclr = color;
    vec3 maxclr = color;

    int cc = 2;
    ivec2 texelCoordM1 = clamp(texelCoord, ivec2(cc), ivec2(view) - cc);
    
    for (int i = 0; i < 8; i++) {
        ivec2 texelCoordM2 = texelCoordM1 + neighbourhoodOffsets[i];

        float z0Check = texelFetch(depthtex0, texelCoordM2, 0).r;
        float z1Check = texelFetch(depthtex1, texelCoordM2, 0).r;
        if (max(abs(GetLinearDepth(z0Check) - GetLinearDepth(z0)), abs(GetLinearDepth(z1Check) - GetLinearDepth(z1))) > 0.09) {
            edge = regularEdge;

            if (int(texelFetch(colortex6, texelCoordM2, 0).g * 255.1) == 253)
                edge *= extraEdgeMult;
        }

        vec3 clr = texelFetch(colortex3, texelCoordM2, 0).rgb;
        minclr = min(minclr, clr);
        maxclr = max(maxclr, clr);
    }

    // Use direct clamping like taa2 instead of ClipAABB
    tempColor = clamp(tempColor, minclr, maxclr);
}

void DoTAA(inout vec3 color, inout vec3 temp, float z1) {
    int materialMask = int(texelFetch(colortex6, texelCoord, 0).g * 255.1);

    vec4 screenPos1 = vec4(texCoord, z1, 1.0);
    vec4 viewPos1 = gbufferProjectionInverse * (screenPos1 * 2.0 - 1.0);
    viewPos1 /= viewPos1.w;

    #ifdef ENTITY_TAA_NOISY_CLOUD_FIX
        float cloudLinearDepth = texture2D(colortex4, texCoord).r;
        float lViewPos1 = length(viewPos1);

        if (pow2(cloudLinearDepth) * renderDistance < min(lViewPos1, renderDistance)) {
            materialMask = 0;
        }
    #endif

    /*
    #ifdef TAA_TWEAKS
        if (materialMask == 254) {
            #ifndef CUSTOM_PBR
                if (z1 <= 0.56) return;
            #endif
            int i = 0;
            while (i < 4) {
                int mms = int(texelFetch(colortex6, texelCoord + neighbourhoodOffsets[i], 0).g * 255.1);
                if (mms != materialMask) break;
                i++;
            }
            if (i == 4) return;
        }
    #endif
    */

    float z0 = texelFetch(depthtex0, texelCoord, 0).r;

    vec2 prvCoord = texCoord;
    if (z1 > 0.56) prvCoord = Reprojection(viewPos1);

    #ifndef TAA_MOVEMENT_IMPROVEMENT_FILTER
        vec3 tempColor = texture2D(colortex2, prvCoord).rgb;
    #else
        vec3 tempColor = textureCatmullRom(colortex2, prvCoord, view);
    #endif

    if (tempColor == vec3(0.0) || any(isnan(tempColor))) {
        temp = color;
        return;
    }

    // Store unclamped for comparison (taa2 technique)
    vec3 unclampedColor = tempColor;

    float edge = 0.0;
    NeighbourhoodClamping(color, tempColor, z0, z1, edge);

    if (materialMask == 253)
        edge *= extraEdgeMult;

    #ifdef DISTANT_HORIZONS
        if (z0 == 1.0) {
            blendMinimum = 0.75;
            blendVariable = 0.05;
            blendConstant = 0.9;
            edge = 1.0;
        }
    #endif

    vec2 velocity = (texCoord - prvCoord) * view;

    vec2 px_dist = 0.5 - abs(fract((prvCoord - texCoord) * view) - 0.5);
    float blend_weight = dot(px_dist, px_dist);
    blend_weight = pow(blend_weight, 1.5) * TAA_MOTION_REJECT;

    float clamped = distance(unclampedColor, tempColor) / max(getLuma(unclampedColor), 0.001);

    float lum_diff = distance(unclampedColor, color) / max(getLuma(unclampedColor), 0.001);
    lum_diff = 1.0 - clamp(lum_diff * lum_diff, 0.0, 1.0) * TAA_ANTI_FLICKER_STRENGTH;

    float blendFactor = float(prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
                              prvCoord.y > 0.0 && prvCoord.y < 1.0);
    float velocityFactor = dot(velocity, velocity) * 100.0;
    blendFactor *= max(exp(-velocityFactor) * blendVariable + blendConstant - length(cameraPosition - previousCameraPosition) * edge, blendMinimum);

    float taa_weight = clamp(1.0 - sqrt(length(velocity)) / 2.0, 0.0, 1.0) * 0.9;
    taa_weight = max(taa_weight, 0.35); // Minimum weight from taa2

    float stability = 1.0 - clamp(lum_diff * 0.5 + blend_weight + clamped * TAA_ANTI_GHOST_STRENGTH, 0.0, 1.0);
    taa_weight = mix(taa_weight, TAA_STABILITY_WEIGHT, stability);

    blendFactor = mix(blendFactor, taa_weight, 0.5);

    color = mix(color, tempColor, blendFactor);
    temp = color;
}