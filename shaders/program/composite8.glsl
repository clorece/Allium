/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

in vec3 normal;

flat in vec3 upVec, sunVec;

void main() {
    vec3 color = texelFetch(colortex0, texelCoord, 0).rgb;

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = vec4(color, 1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

out vec3 normal;

flat out vec3 upVec, sunVec;

void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    normal = normalize(gl_NormalMatrix * gl_Normal);

    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = GetSunVector();
}

#endif
