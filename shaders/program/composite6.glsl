/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

//Pipeline Constants//
#include "/lib/pipelineSettings.glsl"

const bool colortex3MipmapEnabled = true;

//Common Variables//
vec2 view = vec2(viewWidth, viewHeight);

//Common Functions//
float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#ifdef TAA
    #include "/lib/antialiasing/taa.glsl"
#endif

// CAS Sharpening (Contrast Adaptive Sharpening)
vec3 ContrastAdaptiveSharpening(vec3 color, ivec2 coord, float sharpness) {
    vec3 u = texelFetch(colortex3, coord + ivec2(0, 1), 0).rgb;
    vec3 d = texelFetch(colortex3, coord + ivec2(0, -1), 0).rgb;
    vec3 l = texelFetch(colortex3, coord + ivec2(-1, 0), 0).rgb;
    vec3 r = texelFetch(colortex3, coord + ivec2(1, 0), 0).rgb;

    vec3 blur = (u + d + l + r) * 0.25;
    vec3 sharp = color + (color - blur) * sharpness;

    // Anti-ringing clamp: restrict result to local neighborhood
    vec3 minNeigh = min(min(min(u, d), l), r);
    vec3 maxNeigh = max(max(max(u, d), l), r);
    minNeigh = min(minNeigh, color);
    maxNeigh = max(maxNeigh, color);
    
    return clamp(sharp, minNeigh, maxNeigh);
}

//Program//
void main() {
    vec3 color = texelFetch(colortex3, texelCoord, 0).rgb;

    vec3 temp = vec3(0.0);
    float z1 = 0.0;

    #if defined TAA || defined TEMPORAL_FILTER
            z1 = texelFetch(depthtex1, texelCoord, 0).r;
    #endif

    #ifdef TAA
        DoTAA(color, temp, z1);
        #if RENDER_SCALE < 1.0
            // CAS Sharpening for TAAU
            // Increase sharpness as resolution decreases to recover more detail
            // Tuning: conservative sharpening (0.4 + dynamic) to prevent artifacts
            float sharpness = 0.4 + (1.0 - RENDER_SCALE) * 1.0; 
            color = ContrastAdaptiveSharpening(color, texelCoord, sharpness);
        #endif
    #endif

    float averageLuma = GetLuminance(color);

    /* DRAWBUFFERS:32 */
    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(temp, 1.0);

    // Supposed to be #ifdef TEMPORAL_FILTER but Optifine bad
    #if BLOCK_REFLECT_QUALITY >= 3 && RP_MODE >= 1
        /* DRAWBUFFERS:321 */
        gl_FragData[2] = vec4(z1, 1.0, 1.0, 1.0);
    #endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

//Attributes//

//Common Variables//

//Common Functions//

//Includes//

//Program//
void main() {
    gl_Position = ftransform();

    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif
