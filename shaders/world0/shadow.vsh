#version 130

#include "/lib/options.glsl"

//#define SHADOW_MAP_BIAS 0.9

const float PI = 3.14159265359;

/*
Shadow Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/


out vec2 texCoord;

uniform float far;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

attribute vec4 mc_Entity;

vec3 wind(vec3 position) {
    position.xy += abs(sin(2 * PI * (frameTimeCounter * 0.7 + position.x /  11.0 + position.y / 5.0)) * 0.0015);
    //position.y += abs(sin(2 * PI * (frameTimeCounter * 0.7 + position.y /  11.0 + position.y / 5.0)) * 0.000001);
    return position;
}

//#include "/lib/util/distort.glsl"

void main() {
    texCoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform(); 

    vec4 position = gl_Position;

	position = shadowProjectionInverse * position;
	position = shadowModelViewInverse * position;
	position.xyz += cameraPosition.xyz;

    //insert foliage terrain displacement code here

    position.xyz -= cameraPosition.xyz;
	//if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0 || mc_Entity.x == 51.0 || mc_Entity.x == 79.0) position *= 0.0;
	position = shadowModelView * position;
	position = shadowProjection * position;

	//if (mc_Entity.x == 95 || mc_Entity.x == 160 || mc_Entity.x == 79 || mc_Entity.x == 165) makecolor = 1.0;

	gl_Position = position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	
	gl_Position.xy *= 1.0 / distortFactor;
	//gl_Position.xy *= 0.5;

    gl_FrontColor = gl_Color;
}