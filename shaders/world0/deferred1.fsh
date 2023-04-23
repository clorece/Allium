#version 130

#include "/lib/options.glsl"

const int RGBA16 = 3;
const int gcolorFormat	= RGBA16;

in vec2 texCoord;
in vec3 lightColor;
in vec3 ambientColor;
in vec3 lightVector;
in vec3 upVector;
in vec3 sunVector;
in vec3 moonVector;

//uniform int worldTime;
//uniform float frameTimeCounter;
//uniform float rainStrength;
//uniform ivec2 eyeBrightnessSmooth;
//uniform vec3 cameraPosition;
//uniform vec3 sunPosition;
uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

float depth0 = texture2D(depthtex0, texCoord).x;
vec3 clipSpace = vec3(texCoord, depth0) * 2.0 - 1.0;

float SdotU = dot(sunVector, upVector);
float MdotU = dot(sunVector, upVector);
float sunVisibility = pow(clamp(SdotU+0.1,0.0,0.1)/0.1,2.0);
float moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1)/0.1,2.0);

#include "/lib/util/positions.glsl"
#include "/lib/fragment/sky.glsl"
#include "/lib/fragment/fog.glsl"

/*
vec3 getVolumetricLight(vec3 color, vec3 fragPosition, vec2 coord) { 

	float sample = texture2D(colortex6, coord.xy).r;
        sample *= VL_INTENSITY;
    vec3 vlcolor = mix(color, lightColor, sample);
	return vlcolor;
}
*/

void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;

	vec3 fragPosition = getFragPosition().xyz;
    color = getFog(fragPosition, color);
/*
    #ifdef VOLUMETRIC_LIGHT
        color = getVolumetricLight(color, fragPosition, texCoord);
    #endif
*/
    if (depth0 == 1) {
        color = getSky(fragPosition); 
        color += lightColor * (sun(fragPosition) * 5.0);
    }

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}