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

uniform int worldTime;
uniform float rainStrength;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

float depth0 = texture2D(depthtex0, texCoord).x;
vec3 clipSpace = vec3(texCoord, depth0) * 2.0 - 1.0;

#include "/lib/util/distort.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/fragment/sky.glsl"

void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;

	vec4 fragPosition0 = getFragPosition();

    if (depth0 == 1 && (worldTime < 12700 || worldTime > 23250)) {
        color = getSky(fragPosition0.xyz); 
    }

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}