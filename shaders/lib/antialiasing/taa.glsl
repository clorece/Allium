//#define TAA_TWEAKS

#if TAA_MODE == 1
    float blendMinimum = 0.8;
    float blendVariable = 0.2;
    float blendConstant = 0.7;

    float regularEdge = 20.0;
    float extraEdgeMult = 3.0;
#elif TAA_MODE == 2
    float blendMinimum = 0.85;
    float blendVariable = 0.2;
    float blendConstant = 0.7;

    float regularEdge = 5.0;
    float extraEdgeMult = 3.0;
#endif

#ifdef TAA_MOVEMENT_IMPROVEMENT_FILTER
    //Catmull-Rom sampling from Filmic SMAA presentation
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

void NeighbourhoodClamping(vec3 color, inout vec3 tempColor, float z0, float z1, inout float edge) {
    vec3 minclr = color;
    vec3 maxclr = minclr;

    int cc = 2;
    ivec2 texelCoordM1 = clamp(texelCoord, ivec2(cc), ivec2(view) - cc); // Fixes screen edges
    for (int i = 0; i < 8; i++) {
        ivec2 texelCoordM2 = texelCoordM1 + neighbourhoodOffsets[i];

        float z0Check = texelFetch(depthtex0, texelCoordM2, 0).r;
        float z1Check = texelFetch(depthtex1, texelCoordM2, 0).r;
        if (max(abs(GetLinearDepth(z0Check) - GetLinearDepth(z0)), abs(GetLinearDepth(z1Check) - GetLinearDepth(z1))) > 0.09) {
            edge = regularEdge;

            if (int(texelFetch(colortex6, texelCoordM2, 0).g * 255.1) == 253) // Reduced Edge TAA
                edge *= extraEdgeMult;
        }

        vec3 clr = texelFetch(colortex3, texelCoordM2, 0).rgb;
        minclr = min(minclr, clr); maxclr = max(maxclr, clr);
    }

    tempColor = ClipAABB(tempColor, minclr, maxclr);
}

void DoTAA(inout vec3 color, inout vec3 temp, float z1) {
    int materialMask = int(texelFetch(colortex6, texelCoord, 0).g * 255.1);

    vec4 screenPos1 = vec4(texCoord, z1, 1.0);
    vec4 viewPos1 = gbufferProjectionInverse * (screenPos1 * 2.0 - 1.0);
    viewPos1 /= viewPos1.w;

    #ifdef ENTITY_TAA_NOISY_CLOUD_FIX
        float cloudLinearDepth =  texture2D(colortex5, texCoord).a;
        float lViewPos1 = length(viewPos1);

        if (pow2(cloudLinearDepth) * renderDistance < min(lViewPos1, renderDistance)) {
            // Material in question is obstructed by the cloud volume
            materialMask = 0;
        }
    #endif

    /*if (
        abs(materialMask - 149.5) < 50.0 // Entity Reflection Handling (see common.glsl for details)
        || materialMask == 254 // No SSAO, No TAA
    ) { 
        return;
    }*/

    /*if (materialMask == 254) { // No SSAO, No TAA
        #ifndef CUSTOM_PBR
            if (z1 <= 0.56) return; // The edge pixel trick doesn't look nice on hand
        #endif
        int i = 0;
        while (i < 4) {
            int mms = int(texelFetch(colortex6, texelCoord + neighbourhoodOffsets[i], 0).g * 255.1);
            if (mms != materialMask) break;
            i++;
        } // Checking edge-pixels prevents flickering
        if (i == 4) return;
    }*/

    float z0 = texelFetch(depthtex0, texelCoord, 0).r;

    vec2 prvCoord = texCoord;
    if (z1 > 0.56) prvCoord = Reprojection(viewPos1);

    #ifndef TAA_MOVEMENT_IMPROVEMENT_FILTER
        vec3 tempColor = texture2D(colortex2, prvCoord).rgb;
    #else
        vec3 tempColor = textureCatmullRom(colortex2, prvCoord, view);
    #endif

    if (tempColor == vec3(0.0) || any(isnan(tempColor))) { // Fixes the first frame and nans
        temp = color;
        return;
    }

    float edge = 0.0;
    NeighbourhoodClamping(color, tempColor, z0, z1, edge);

    if (materialMask == 253) // Reduced Edge TAA
        edge *= extraEdgeMult;

    #ifdef DISTANT_HORIZONS
        if (z0 == 1.0) {
            blendMinimum = 0.75;
            blendVariable = 0.05;
            blendConstant = 0.9;
            edge = 1.0;
        }
    #endif

    vec2 velocity = (texCoord - prvCoord.xy) * view;
    float blendFactor = float(prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
                              prvCoord.y > 0.0 && prvCoord.y < 1.0);
    float velocityFactor = dot(velocity, velocity) * 10.0;
    blendFactor *= max(exp(-velocityFactor) * blendVariable + blendConstant - length(cameraPosition - previousCameraPosition) * edge, blendMinimum);

    #ifdef EPIC_THUNDERSTORM
        blendFactor *= 1.0 - isLightningActive();
    #endif

    #ifdef MIRROR_DIMENSION
        blendFactor = 0.0;
    #endif

    color = mix(color, tempColor, blendFactor);
    temp = color;

    //if (edge > 0.05) color.rgb = vec3(1.0, 0.0, 1.0);
}

/*
//#define TAA_TWEAKS

#if TAA_MODE == 1
    float blendMinimum = 0.8;
    float blendVariable = 0.2;
    float blendConstant = 0.7;
    float regularEdge = 20.0;
    float extraEdgeMult = 3.0;
#elif TAA_MODE == 2
    float blendMinimum = 0.85;
    float blendVariable = 0.2;
    float blendConstant = 0.7;

    float regularEdge = 5.0;
    float extraEdgeMult = 3.0;
#endif

// --- CHECKERBOARD LOGIC (STATIC) ---
// Matches composite5.glsl exactly to identify valid pixels.
bool IsActivePixel(vec2 coord) {
    #if RENDER_SCALE == 3
        return true;
    #else
        ivec2 p = ivec2(coord);
        
        // Scale 1: 75% Resolution (Keep 3, Skip 1)
        if (RENDER_SCALE == 2) return !((p.x & 1) != 0 && (p.y & 1) != 0);
        
        // Scale 2: Checkerboard (Standard)
        if (RENDER_SCALE == 1) return ((p.x + p.y) & 1) == 0;
        
        // Scale 3: Quarter Resolution (Grid)
        if (RENDER_SCALE == 0) return ((p.x & 1) == 0 && (p.y & 1) == 0);
        
        return true;
    #endif
}

#ifdef TAA_MOVEMENT_IMPROVEMENT_FILTER
    //Catmull-Rom sampling from Filmic SMAA presentation
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
                    vec4(texture2DLod(colortex, vec2(tc3.x,  tc12.y), 0).rgb, 1.0) 
                    * (w3.x  * w12.y) +
                    vec4(texture2DLod(colortex, vec2(tc12.x, tc3.y ), 0).rgb, 1.0) * (w12.x * w3.y );
        return color.rgb / color.a;
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

// Updated Clamping to handle Skipped Pixels and Lonely Pixels
void NeighbourhoodClamping(vec3 color, inout vec3 tempColor, float z0, float z1, inout float edge, bool isActive) {
    // If active, start with self. If inactive, start inverted so first neighbor sets the box.
    vec3 minclr = isActive ? color : vec3(100.0);
    vec3 maxclr = isActive ? color : vec3(-100.0);

    int cc = 2;
    ivec2 texelCoordM1 = clamp(texelCoord, ivec2(cc), ivec2(view) - cc);
    
    bool foundValidNeighbor = false;

    for (int i = 0; i < 8; i++) {
        ivec2 texelCoordM2 = texelCoordM1 + neighbourhoodOffsets[i];

        // IMPORTANT: Only sample neighbors that were actually rendered!
        if (IsActivePixel(vec2(texelCoordM2) + 0.5)) { 
            float z0Check = texelFetch(depthtex0, texelCoordM2, 0).r;
            float z1Check = texelFetch(depthtex1, texelCoordM2, 0).r;
            
            if (max(abs(GetLinearDepth(z0Check) - GetLinearDepth(z0)), abs(GetLinearDepth(z1Check) - GetLinearDepth(z1))) > 0.09) {
                edge = regularEdge;
                if (int(texelFetch(colortex6, texelCoordM2, 0).g * 255.1) == 253) // Reduced Edge TAA
                    edge *= extraEdgeMult;
            }

            vec3 clr = texelFetch(colortex3, texelCoordM2, 0).rgb;
            
            // Initialization for inactive center pixel
            if (!isActive && !foundValidNeighbor) {
                minclr = clr;
                maxclr = clr;
                foundValidNeighbor = true;
            }

            minclr = min(minclr, clr);
            maxclr = max(maxclr, clr);
            foundValidNeighbor = true;
        }
    }

    // EDGE CASE: If we are active but found NO active neighbors (Scale 3 Lonely Pixel),
    // we must NOT clamp to self, otherwise we kill TAA. We trust history instead.
    if (isActive && !foundValidNeighbor) {
        // Expand box to include history, allowing smoothing to happen.
        minclr = min(color, tempColor);
        maxclr = max(color, tempColor);
    }
    // EDGE CASE: Inactive hole with no neighbors (rare), trust history.
    else if (!isActive && !foundValidNeighbor) {
        minclr = tempColor; 
        maxclr = tempColor;
    }

    tempColor = ClipAABB(tempColor, minclr, maxclr);
}

void DoTAA(inout vec3 color, inout vec3 temp, float z1) {
    int materialMask = int(texelFetch(colortex6, texelCoord, 0).g * 255.1);
    vec4 screenPos1 = vec4(texCoord, z1, 1.0);
    vec4 viewPos1 = gbufferProjectionInverse * (screenPos1 * 2.0 - 1.0);
    viewPos1 /= viewPos1.w;
    
    #ifdef ENTITY_TAA_NOISY_CLOUD_FIX
        float cloudLinearDepth =  texture2D(colortex5, texCoord).a;
        float lViewPos1 = length(viewPos1);
        if (pow2(cloudLinearDepth) * renderDistance < min(lViewPos1, renderDistance)) {
            materialMask = 0;
        }
    #endif

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

    // --- RECONSTRUCTION LOGIC ---
    // Use gl_FragCoord to ensure alignment with composite5
    bool activePixel = IsActivePixel(gl_FragCoord.xy);

    float edge = 0.0;
    
    // Pass 'active' status to Clamping
    NeighbourhoodClamping(color, tempColor, z0, z1, edge, activePixel);
    
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

    vec2 velocity = (texCoord - prvCoord.xy) * view;
    float blendFactor = float(prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
                              prvCoord.y > 0.0 && prvCoord.y < 1.0);
    float velocityFactor = dot(velocity, velocity) * 10.0;
    blendFactor *= max(exp(-velocityFactor) * blendVariable + blendConstant - length(cameraPosition - previousCameraPosition) * edge, blendMinimum);
    
    #ifdef EPIC_THUNDERSTORM
        blendFactor *= 1.0 - isLightningActive();
    #endif

    #ifdef MIRROR_DIMENSION
        blendFactor = 0.0;
    #endif

    if (activePixel) {
        // Standard TAA mix for rendered pixels
        color = mix(color, tempColor, blendFactor);
    } else {
        // Force Reconstruction for empty pixels
        // Uses the clamped history (which is now based on neighbors)
        color = tempColor;
    }
    
    temp = color;
}*/ 