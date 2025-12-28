/////////////////////////////////////
// Complementary Shaders by EminGT //
// Cloud Blur & Reconstruction     //
/////////////////////////////////////

//Common//
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

// Color Includes (Required for mainClouds)
#include "/lib/colors/lightAndAmbientColors.glsl"
#include "/lib/colors/skyColors.glsl"
#include "/lib/util/spaceConversion.glsl"

// Cloud Map Generation (Top Down Density)
#if defined CLOUD_SHADOWS && defined OVERWORLD
    #include "/lib/atmospherics/clouds/cloudCoord.glsl"
    #include "/lib/atmospherics/clouds/mainClouds.glsl"
    #define CLOUD_SHADOW_GENERATION
    //#include "/lib/atmospherics/clouds/cloudShadows.glsl"
#endif



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

// Smart Blur: Fills holes and softens edges (combined horizontal + vertical)
vec4 SmartBlur(sampler2D cloudTex, vec2 coord) {
    vec4 sum = vec4(0.0);
    float validWeightSum = 0.0;
    float totalKernelWeight = 0.0;
    
    // Gaussian Weights for blur - extended for softer clouds
    float weights[4] = float[4](0.35, 0.25, 0.15, 0.08);
    vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    
    float centerDepth = texture2D(depthtex0, coord).r;
    
    // Center Sample
    vec4 centerSample = texture2D(cloudTex, coord);
    float centerW = weights[0];
    totalKernelWeight += centerW;
    
    if (centerSample.a > 0.001) {
        sum += centerSample * centerW;
        validWeightSum += centerW;
    }
    
    // Sample in a cross pattern (horizontal + vertical combined) - extended to 3 pixels
    for (int i = 1; i <= 3; i++) {
        float w = weights[i];
        
        // Horizontal samples
        vec2 posR = coord + vec2(float(i) * pixelSize.x, 0.0);
        vec2 posL = coord - vec2(float(i) * pixelSize.x, 0.0);
        
        // Vertical samples  
        vec2 posU = coord + vec2(0.0, float(i) * pixelSize.y);
        vec2 posD = coord - vec2(0.0, float(i) * pixelSize.y);
        
        vec4 sampleR = texture2D(cloudTex, posR);
        vec4 sampleL = texture2D(cloudTex, posL);
        vec4 sampleU = texture2D(cloudTex, posU);
        vec4 sampleD = texture2D(cloudTex, posD);
        
        // Depth safety for each sample
        float depthR = texture2D(depthtex0, posR).r;
        float depthL = texture2D(depthtex0, posL).r;
        float depthU = texture2D(depthtex0, posU).r;
        float depthD = texture2D(depthtex0, posD).r;
        
        float dwR = abs(centerDepth - depthR) < 0.01 ? 1.0 : 0.0;
        float dwL = abs(centerDepth - depthL) < 0.01 ? 1.0 : 0.0;
        float dwU = abs(centerDepth - depthU) < 0.01 ? 1.0 : 0.0;
        float dwD = abs(centerDepth - depthD) < 0.01 ? 1.0 : 0.0;
        
        // Accumulate weights
        totalKernelWeight += w * (dwR + dwL + dwU + dwD);
        
        if (sampleR.a > 0.001) { sum += sampleR * w * dwR; validWeightSum += w * dwR; }
        if (sampleL.a > 0.001) { sum += sampleL * w * dwL; validWeightSum += w * dwL; }
        if (sampleU.a > 0.001) { sum += sampleU * w * dwU; validWeightSum += w * dwU; }
        if (sampleD.a > 0.001) { sum += sampleD * w * dwD; validWeightSum += w * dwD; }
    }
    
    if (validWeightSum < 0.0001) return vec4(0.0);
    
    // Reconstruct pixel
    vec4 result = sum / validWeightSum;
    
    // Density softening - prevents blockiness at cloud edges
    float density = validWeightSum / max(totalKernelWeight, 0.0001);
    float fadeFactor = smoothstep(0.1, 0.45, density);
    
    result.a *= fadeFactor;
    
    return result;
}

//Program//
void main() {
    // Apply smart blur
    vec4 blurredClouds = SmartBlur(colortex12, texCoord);
    
    // Cloud shadow generation removed (using 2D Noise now)
    float cloudShadow = 1.0;
    
    // Output: colortex10 = cloud shadow (RGB), colortex14 = blurred clouds
    // Alpha of colortex10 is preserved via colormask in shaders.properties
    /* RENDERTARGETS:10,14 */
    gl_FragData[0] = vec4(cloudShadow, 0.0, 0.0, 0.0);
    gl_FragData[1] = blurredClouds;
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
