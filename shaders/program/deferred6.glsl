/////////////////////////////////////
// Complementary Shaders by EminGT //
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

//Common Functions//
float GetLinearDepth2(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/util/spaceConversion.glsl"

// Smart Blur: Fills holes but softens edges to prevent "Lego" look
vec4 SmartBlurHorizontal(sampler2D cloudTex, vec2 coord, float centerDepth) {
    vec4 sum = vec4(0.0);
    float validWeightSum = 0.0;
    float totalKernelWeight = 0.0;
    
    // Standard Gaussian Weights
    float weights[5] = float[5](0.153170, 0.144893, 0.122649, 0.092902, 0.062970);
    vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    // 1. Center Sample
    vec4 centerSample = texture2D(cloudTex, coord);
    float centerW = weights[0];
    totalKernelWeight += centerW;

    if (centerSample.a > 0.001) {
        sum += centerSample * centerW;
        validWeightSum += centerW;
    }

    // 2. Loop Neighbors
    for (int i = 1; i <= 2; i++) {
        vec2 offset = vec2(float(i) * pixelSize.x, 0.0);
        float w = weights[i];

        // Right Sample
        vec2 posR = coord + offset;
        vec4 sampleR = texture2D(cloudTex, posR);
        float depthR = texture2D(depthtex0, posR).r;
        
        // Depth Safety (prevent clouds bleeding into mountains)
        float depthDiffR = abs(centerDepth - depthR);
        float depthWeightR = depthDiffR < 0.01 ? 1.0 : 0.0;
        
        // Accumulate max potential weight for density calculation
        totalKernelWeight += w * depthWeightR;

        if (sampleR.a > 0.001) {
            sum += sampleR * w * depthWeightR;
            validWeightSum += w * depthWeightR;
        }

        // Left Sample
        vec2 posL = coord - offset;
        vec4 sampleL = texture2D(cloudTex, posL);
        float depthL = texture2D(depthtex0, posL).r;
        
        float depthDiffL = abs(centerDepth - depthL);
        float depthWeightL = depthDiffL < 0.01 ? 1.0 : 0.0;

        totalKernelWeight += w * depthWeightL;

        if (sampleL.a > 0.001) {
            sum += sampleL * w * depthWeightL;
            validWeightSum += w * depthWeightL;
        }
    }

    if (validWeightSum < 0.0001) return vec4(0.0);

    // 3. Reconstruct Pixel
    vec4 result = sum / validWeightSum;

    // 4. Density Softening (Fixes Blockiness)
    // If we found only a few neighbors (edge of cloud), fade it out.
    // If we found many neighbors (checkerboard hole), keep it opaque.
    float density = validWeightSum / max(totalKernelWeight, 0.0001);
    
    // Lower threshold to preventing flickering at low resolutions (checkerboard pattern reduces density)
    float fadeFactor = smoothstep(0.05, 0.2, density); 
    
    result.a *= fadeFactor;

    return result;
}

//Program//
void main() {
    vec2 actualTexCoord = texCoord;
    float sceneDepth = texture2D(depthtex0, actualTexCoord).r;
    
    vec4 blurredClouds = SmartBlurHorizontal(colortex12, actualTexCoord, sceneDepth);

    /* RENDERTARGETS:14,15 */
    gl_FragData[0] = blurredClouds;
    gl_FragData[1] = vec4(sceneDepth, 0.0, 0.0, 1.0);
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