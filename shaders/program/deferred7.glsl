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

// Vertical Pass
vec4 SoftBlurVertical(sampler2D cloudTex, vec2 coord, float centerDepth) {
    vec4 sum = vec4(0.0);
    float totalWeight = 0.0;
    
    float weights[5] = float[5](0.153170, 0.144893, 0.122649, 0.092902, 0.062970);
    vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    // Center
    sum += texture2D(cloudTex, coord) * weights[0];
    totalWeight += weights[0];

    // Loop
    for (int i = 1; i <= 2; i++) {
        vec2 offset = vec2(0.0, float(i) * pixelSize.y);
        float w = weights[i];

        // Up
        vec2 posU = coord + offset;
        float depthU = texture2D(colortex15, posU).r;
        
        // Relaxed depth check to allow blurring across checkerboard pattern
        // if (abs(centerDepth - depthU) < 0.01) { 
            sum += texture2D(cloudTex, posU) * w;
            totalWeight += w;
        //}

        // Down
        vec2 posD = coord - offset;
        float depthD = texture2D(colortex15, posD).r;
        
        // if (abs(centerDepth - depthD) < 0.01) {
            sum += texture2D(cloudTex, posD) * w;
            totalWeight += w;
        //}
    }

    if (totalWeight > 0.0001) return sum / totalWeight;
    return vec4(0.0);
}

//Program//
void main() {
    vec2 actualTexCoord = texCoord;
    float sceneDepth = texture2D(colortex15, actualTexCoord).r;
    
    vec4 blurredClouds = SoftBlurVertical(colortex14, actualTexCoord, sceneDepth);
    
    /* RENDERTARGETS:12 */
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