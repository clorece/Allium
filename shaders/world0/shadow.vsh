#version 130

#include "/lib/options.glsl"

const float PI = 3.14159265359;

/*
Shadow Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

out vec2 texCoord;

uniform float far;
uniform float frameTimeCounter;

attribute vec4 mc_Entity;

vec3 wind(vec3 position) {
    position.xy += abs(sin(2 * PI * (frameTimeCounter * 0.7 + position.x /  11.0 + position.y / 5.0)) * 0.0015);
    //position.y += abs(sin(2 * PI * (frameTimeCounter * 0.7 + position.y /  11.0 + position.y / 5.0)) * 0.000001);
    return position;
}

#include "/lib/util/distort.glsl"

void main() {
    texCoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform(); 

    // shadowSpace from shaderLabs shadow tutorial
    float distortFactor = getDistortFactor(gl_Position.xy);
	gl_Position.xyz = distort(gl_Position.xyz, distortFactor); //apply shadow distortion
	//gl_Position.xyz = gl_Position.xyz * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
	gl_Position.z -= SHADOW_BIAS * (distortFactor * distortFactor); //apply shadow bias

    gl_FrontColor = gl_Color;
}