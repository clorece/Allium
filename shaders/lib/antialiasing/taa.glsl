//#define TAA_TWEAKS
#define TAA_MOVEMENT_IMPROVEMENT_FILTER

#if TAA_MODE == 1
    float blendMinimum = 0.6;
    float blendVariable = 0.2;
    float blendConstant = 0.7;

    float regularEdge = 10.0;
    float extraEdgeMult = 7.0;
#elif TAA_MODE == 2
    float blendMinimum = 0.75;
    float blendVariable = 0.2;
    float blendConstant = 0.7;

    float regularEdge = 5.0;
    float extraEdgeMult = 3.0;
#endif

vec3 ReinhardTonemap(vec3 color) {
    return color / (1.0 + GetLuminance(color));
}

vec3 ReinhardInverse(vec3 color) {
    return color / max(1.0 - GetLuminance(color), 0.001);
}

vec4 SmoothFilter(sampler2D tex, vec2 uv, vec2 resolution) {
    vec2 position = uv * resolution;
    vec2 centerPos = floor(position - 0.5) + 0.5;
    vec2 f = position - centerPos;
    vec2 w = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 sampleUV = (centerPos + w) / resolution;
    return texture2D(tex, sampleUV);
}

#ifdef TAA_MOVEMENT_IMPROVEMENT_FILTER
    vec3 textureCatmullRom(sampler2D colortex, vec2 texcoord, vec2 resolution) {
        vec2 position = texcoord * resolution;
        vec2 centerPosition = floor(position - 0.5) + 0.5;
        vec2 f = position - centerPosition;
        vec2 f2 = f * f;
        vec2 f3 = f * f2;

        float upscaleSharpness = mix(0.0, 0.25, 1.0 - RENDER_SCALE);
        float c = 0.5 + clamp(IMAGE_SHARPENING + upscaleSharpness, 0.0, 1.0) * 0.5;
        vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
        vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
        vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
        vec2 w3 =         c  * f3 -                c * f2;

        vec2 w12 = w1 + w2;
        vec2 tc12 = (centerPosition + w2 / w12) / resolution;

        vec2 tc0 = (centerPosition - 1.0) / resolution;
        vec2 tc3 = (centerPosition + 2.0) / resolution;
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

void NeighbourhoodClamping(vec3 color, inout vec3 tempColor, float z0, float z1, inout float edge, out vec3 minclr, out vec3 maxclr) {
    int cc = 2;
    ivec2 texelCoordM1 = clamp(texelCoord, ivec2(cc), ivec2(view) - cc);
    
    // Sample at render scale coordinates
    vec2 uvCenter = (vec2(texelCoordM1) + 0.5) / view * RENDER_SCALE;
    vec2 lowResPixelSize = RENDER_SCALE / view;
    
    #if RENDER_SCALE < 1.0

        minclr = texture2D(colortex14, uvCenter).rgb;
        maxclr = texture2D(colortex15, uvCenter).rgb;

        for (int i = 0; i < 8; i++) {
            vec2 uvNeighbour = uvCenter + vec2(neighbourhoodOffsets[i]) * lowResPixelSize;
            ivec2 depthCoord = ivec2(uvNeighbour * view);
            float z0Check = texelFetch(depthtex0, depthCoord, 0).r;
            float z1Check = texelFetch(depthtex1, depthCoord, 0).r;

            if (max(abs(GetLinearDepth(z0Check) - GetLinearDepth(z0)), abs(GetLinearDepth(z1Check) - GetLinearDepth(z1))) > 0.09) {
                edge = regularEdge;
                if (int(texelFetch(colortex6, depthCoord, 0).g * 255.1) == 253) edge *= extraEdgeMult;
            }
        }
    #else

        vec3 centerClr = texture2D(colortex3, uvCenter).rgb;
        minclr = centerClr;
        maxclr = centerClr;

        vec3 crossMin = centerClr;
        vec3 crossMax = centerClr;
        
        for (int i = 0; i < 8; i++) {
            vec2 uvNeighbour = uvCenter + vec2(neighbourhoodOffsets[i]) * lowResPixelSize;

            ivec2 depthCoord = ivec2(uvNeighbour * view);
            float z0Check = texelFetch(depthtex0, depthCoord, 0).r;
            float z1Check = texelFetch(depthtex1, depthCoord, 0).r;

            if (max(abs(GetLinearDepth(z0Check) - GetLinearDepth(z0)), abs(GetLinearDepth(z1Check) - GetLinearDepth(z1))) > 0.09) {
                edge = regularEdge;
                if (int(texelFetch(colortex6, depthCoord, 0).g * 255.1) == 253) edge *= extraEdgeMult;
            }

            vec3 clr = texture2D(colortex3, uvNeighbour).rgb;
            minclr = min(minclr, clr);
            maxclr = max(maxclr, clr);

            if (neighbourhoodOffsets[i].x == 0 || neighbourhoodOffsets[i].y == 0) {
                crossMin = min(crossMin, clr);
                crossMax = max(crossMax, clr);
            }
        }

        minclr = mix(minclr, crossMin, 0.5);
        maxclr = mix(maxclr, crossMax, 0.5);
    #endif

    tempColor = clamp(tempColor, minclr, maxclr);
}

void DoTAA(inout vec3 color, inout vec3 temp, float z1) {
    int materialMask = int(texelFetch(colortex6, ivec2(vec2(texelCoord) * RENDER_SCALE), 0).g * 255.1);
    
    vec2 texCoord01 = texCoord;

    float z0 = texelFetch(depthtex0, ivec2(vec2(texelCoord) * RENDER_SCALE), 0).r;

    vec4 screenPos1 = vec4(texCoord01, z1, 1.0);
    vec4 viewPos1 = gbufferProjectionInverse * (screenPos1 * 2.0 - 1.0);
    viewPos1 /= viewPos1.w;

    vec2 prvCoord01 = texCoord01;
    if (z1 > 0.56) prvCoord01 = Reprojection(viewPos1);

    vec2 velocity01 = prvCoord01 - texCoord01;
    vec2 historyCoord = texCoord01 + velocity01;

    #ifndef TAA_MOVEMENT_IMPROVEMENT_FILTER
        vec3 tempColor = texture2D(colortex2, historyCoord).rgb;
    #else
        vec3 tempColor = textureCatmullRom(colortex2, historyCoord, view);
    #endif

    if (tempColor == vec3(0.0) || any(isnan(tempColor))) { // fixes the first frame and nans
        temp = color;
        return;
    }

    vec3 unclampedHistory = tempColor;
    
    float edge = 0.0;
    vec3 minclr, maxclr;
    NeighbourhoodClamping(color, tempColor, z0, z1, edge, minclr, maxclr);

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

    vec2 velocityPixels = -velocity01 * view;
    float blendFactor = float(prvCoord01.x > 0.0 && prvCoord01.x < 1.0 &&
                              prvCoord01.y > 0.0 && prvCoord01.y < 1.0);
    float velocityFactor = dot(velocityPixels, velocityPixels) * 10.0;
    
    float upscaleBlendBoost = mix(0.0, 0.05, 1.0 - RENDER_SCALE);
    float adjustedBlendConstant = blendConstant + upscaleBlendBoost;
    
    blendFactor *= max(exp(-velocityFactor) * blendVariable + adjustedBlendConstant - length(cameraPosition - previousCameraPosition) * edge, blendMinimum);

    float aabbDistance = length(unclampedHistory - tempColor);
    float distanceRejection = clamp(aabbDistance / max(GetLuminance(unclampedHistory), 0.01) * 0.5, 0.0, 1.0);
    blendFactor *= (1.0 - distanceRejection);

    #ifdef EPIC_THUNDERSTORM
        blendFactor *= 1.0 - isLightningActive();
    #endif

    #ifdef MIRROR_DIMENSION
        blendFactor = 0.0;
    #endif

    vec3 tonemappedHistory = ReinhardTonemap(tempColor);
    vec3 tonemappedCurrent = ReinhardTonemap(color);
    vec3 blended = mix(tonemappedCurrent, tonemappedHistory, blendFactor);
    color = ReinhardInverse(blended);
    
    temp = color;

    //if (edge > 0.05) color.rgb = vec3(1.0, 0.0, 1.0);
}