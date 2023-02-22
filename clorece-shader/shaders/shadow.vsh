#version 130

const float shadowMapBias = 0.85;

/*
Shadow Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

out vec2 texCoord;

attribute vec4 mc_Entity;

void main() {
    texCoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();
    float centerDistance = length(gl_Position.xy);
	float distortFactor = (1.0 - shadowMapBias) + centerDistance * shadowMapBias;
    gl_Position.xy /= distortFactor;

    gl_FrontColor = gl_Color;
}