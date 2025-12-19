//#define TAA_TWEAKS
#define TAA_MOVEMENT_IMPROVEMENT_FILTER

#if TAA_MODE == 1
    float blendMinimum = 0.8;
    float blendVariable = 0.2;
    float blendConstant = 0.725;

    float regularEdge = 10.0;
    float extraEdgeMult = 7.0;
#elif TAA_MODE == 2
    float blendMinimum = 0.85;
    float blendVariable = 0.2;
    float blendConstant = 0.75;

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

        float c = 0.5 + clamp(IMAGE_SHARPENING, 0.0, 1.0) * 0.5;
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

// YCoCg Color Space Conversions
vec3 RGBToYCoCg(vec3 rgb) {
    float y = dot(rgb, vec3(0.25, 0.5, 0.25));
    float co = dot(rgb, vec3(0.5, 0.0, -0.5));
    float cg = dot(rgb, vec3(-0.25, 0.5, -0.25));
    return vec3(y, co, cg);
}

vec3 YCoCgToRGB(vec3 ycocg) {
    float y = ycocg.x;
    float co = ycocg.y;
    float cg = ycocg.z;
    return vec3(
        y + co - cg,
        y + cg,
        y - co - cg
    );
}

void NeighbourhoodClamping(vec3 color, inout vec3 tempColor, float z0, float z1, inout float edge) {
    vec3 m1 = vec3(0.0);
    vec3 m2 = vec3(0.0);

    int cc = 2;
    ivec2 texelCoordM1 = clamp(texelCoord, ivec2(cc), ivec2(view) - cc); // Fixes screen edges
    
    // Center pixel
    vec3 centerClr = RGBToYCoCg(texelFetch(colortex3, texelCoordM1, 0).rgb);
    m1 += centerClr;
    m2 += centerClr * centerClr;

    for (int i = 0; i < 8; i++) {
        ivec2 texelCoordM2 = texelCoordM1 + neighbourhoodOffsets[i];

        float z0Check = texelFetch(depthtex0, texelCoordM2, 0).r;
        float z1Check = texelFetch(depthtex1, texelCoordM2, 0).r;
        if (max(abs(GetLinearDepth(z0Check) - GetLinearDepth(z0)), abs(GetLinearDepth(z1Check) - GetLinearDepth(z1))) > 0.09) {
            edge = regularEdge;

            if (int(texelFetch(colortex6, texelCoordM2, 0).g * 255.1) == 253) // Reduced Edge TAA
                edge *= extraEdgeMult;
        }

        vec3 clr = RGBToYCoCg(texelFetch(colortex3, texelCoordM2, 0).rgb);
        m1 += clr;
        m2 += clr * clr;
    }

    vec3 mean = m1 / 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - mean * mean, 0.0));
    float gamma = 1.25; // Slightly looser gamma for YCoCg to preserve detail
    
    vec3 minclr = mean - gamma * sigma;
    vec3 maxclr = mean + gamma * sigma;

    vec3 tempColorYCoCg = RGBToYCoCg(tempColor);
    tempColorYCoCg = ClipAABB(tempColorYCoCg, minclr, maxclr);
    tempColor = YCoCgToRGB(tempColorYCoCg);
}
void DoTAA(inout vec3 color, inout vec3 temp, float z1) {
    int materialMask = int(texelFetch(colortex6, texelCoord, 0).g * 255.1);

    // Optimization: Skip invalid pixels
    #if RENDER_SCALE < 1.0
        if (texCoord.x > RENDER_SCALE || texCoord.y > RENDER_SCALE) {
            temp = color;
            return;
        }
    #endif

    // texCoord remains in 0-1 for reprojection calculations
    #if RENDER_SCALE < 1.0
        vec2 texCoord01 = texCoord / RENDER_SCALE; // Convert to 0-1 for reprojection
    #else
        vec2 texCoord01 = texCoord;
    #endif

    float z0 = texelFetch(depthtex0, texelCoord, 0).r;

    vec4 screenPos1 = vec4(texCoord01, z1, 1.0);
    vec4 viewPos1 = gbufferProjectionInverse * (screenPos1 * 2.0 - 1.0);
    viewPos1 /= viewPos1.w;

    // Reprojection in 0-1 space using valid viewPos1
    vec2 prvCoord01 = texCoord01;
    if (z1 > 0.56) prvCoord01 = Reprojection(viewPos1);

    // Calculate velocity in 0-1 space
    vec2 velocity01 = prvCoord01 - texCoord01;
    
    // Scale history coordinate back to RENDER_SCALE space for sampling
    // because colortex2 data lives in [0, RENDER_SCALE]
    vec2 historyCoord = (texCoord01 + velocity01) * RENDER_SCALE;

    #ifndef TAA_MOVEMENT_IMPROVEMENT_FILTER
        vec3 tempColor = texture2D(colortex2, historyCoord).rgb;
    #else
        vec3 tempColor = textureCatmullRom(colortex2, historyCoord, view);
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

    vec2 velocityPixels = -velocity01 * view;
    float blendFactor = float(prvCoord01.x > 0.0 && prvCoord01.x < 1.0 &&
                              prvCoord01.y > 0.0 && prvCoord01.y < 1.0);
    float velocityFactor = dot(velocityPixels, velocityPixels) * 10.0;
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