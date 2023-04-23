#version 130

#include "/lib/options.glsl"

const float PI = 3.14159265359;

out float material;
out float foliage;
out vec2 texCoord;
out vec2 lightmapCoord;
out vec3 normal;
out vec4 color;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform sampler2D noisetex;
attribute vec4 mc_Entity;

vec3 wind(vec3 position) {
    position.xy -= abs(sin(2 * PI * (frameTimeCounter * 0.7 + position.x /  11.0 + position.y / 5.0)) * 0.015);
    //position.y -= abs(sin(2 * PI * (frameTimeCounter * 0.5 + position.x /  11.0 + position.y / 5.0)) * 0.001);
    return position;
}

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;

    material = 0.0;
    
    color = gl_Color;

    if (mc_Entity.x == 10000) material = 1.0;
    if (mc_Entity.x == 10002) material = 0.5;

    #ifdef WIND_MOVEMENT
        if (mc_Entity.x == 10000) gl_Position.xyz = wind(gl_Position.xyz);
    #endif

    /*
    Normal and Lightmap Source Code By saada2006:
    https://github.com/saada2006/MinecraftShaderProgramming
    */
    normal = normalize(gl_NormalMatrix * gl_Normal);
    // Use the texture matrix instead of dividing by 15 to maintain compatiblity for each version of Minecraft
    lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    // Transform them into the [0, 1] range
    //lightmapCoord = (lightmapCoord * 33.05f / 32.0f) - (1.05f / 32.0f);

}