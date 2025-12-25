/////////////////////////////////////
// Complementary Shaders by EminGT //
// Cloud Blur & Reconstruction     //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;
flat in vec3 upVec, sunVec;

//Pipeline Constants//

//Common Variables//
#include "/lib/commonVariables.glsl"
#include "/lib/commonFunctions.glsl"

//Includes//
#include "/lib/util/spaceConversion.glsl"

// Check if a pixel was rendered (not a checkerboard hole)
// Must match deferred5.glsl IsActivePixel exactly
bool IsActivePixel(ivec2 p) {
    #if CLOUD_RENDER_RESOLUTION == 3
        return true;
    #elif CLOUD_RENDER_RESOLUTION == 2
        return !((p.x & 1) != 0 && (p.y & 1) != 0); // 3/4 resolution: skip bottom-right of each 2x2
    #elif CLOUD_RENDER_RESOLUTION == 1
        return ((p.x + p.y) & 1) == 0; // Checkerboard: every other pixel
    #else
        return true;
    #endif
}

// Reconstruct checkerboard and apply blur
vec4 ReconstructAndBlur(vec2 uv) {
    vec2 viewRes = vec2(viewWidth, viewHeight);
    vec2 pixelSize = 1.0 / viewRes;
    
    ivec2 centerPixel = ivec2(uv * viewRes);
    bool centerActive = IsActivePixel(centerPixel);
    
    // Sample the 4 cardinal neighbors
    vec4 samples[5];
    float weights[5];
    float totalWeight = 0.0;
    
    // Offsets: center, right, left, up, down
    ivec2 offsets[5] = ivec2[5](
        ivec2(0, 0),
        ivec2(1, 0),
        ivec2(-1, 0),
        ivec2(0, 1),
        ivec2(0, -1)
    );
    
    // Gaussian-ish weights
    float baseWeights[5] = float[5](0.4, 0.15, 0.15, 0.15, 0.15);
    
    for (int i = 0; i < 5; i++) {
        ivec2 samplePixel = centerPixel + offsets[i];
        vec2 sampleUV = (vec2(samplePixel) + 0.5) * pixelSize;
        
        // Check if this sample position was rendered
        bool sampleActive = IsActivePixel(samplePixel);
        
        if (sampleActive) {
            samples[i] = texture2D(colortex12, sampleUV);
            weights[i] = baseWeights[i];
            totalWeight += weights[i];
        } else {
            samples[i] = vec4(0.0);
            weights[i] = 0.0;
        }
    }
    
    // If no valid samples found (shouldn't happen), return black
    if (totalWeight < 0.001) {
        return vec4(0.0);
    }
    
    // Weighted average
    vec4 result = vec4(0.0);
    for (int i = 0; i < 5; i++) {
        result += samples[i] * weights[i];
    }
    result /= totalWeight;
    
    return result;
}

//Program//
void main() {
    // Reconstruct the checkerboard clouds and apply blur
    vec4 blurredClouds = ReconstructAndBlur(texCoord);
    
    // Output to colortex14 (blurred clouds, read by deferred7)
    /* RENDERTARGETS:14 */
    gl_FragData[0] = blurredClouds;
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;
flat out vec3 upVec, sunVec;

//Program//
void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = normalize(sunPosition);
}

#endif
