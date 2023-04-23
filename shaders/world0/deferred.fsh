#version 130

#include "/lib/options.glsl"

const int shadowMapResolution = SHADOW_RESOLUTION;
const float shadowDistance = 160.0;
const float sunPathRotation = 40.0; // [10.0 20.0 30.0 40.0 50.0 60.0]
const float ambientOcclusionLevel = 0.5; // minecraft ambient occlusion level
const float ambientStrength = 0.3;    // ambient strength and shadow darkness
const vec3 torchColor = vec3(0.9922, 0.6471, 0.1922);

const bool shadowHardwareFiltering = true;
const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;

in vec2 texCoord;
in vec3 lightColor;
in vec3 ambientColor;
in vec3 lightVector;

uniform float rainStrength;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

float depth0 = texture2D(depthtex0, texCoord).r;
vec3 material = texture2D(colortex4, texCoord).rgb;
vec3 normal = normalize(texture2D(colortex1, texCoord).rgb * 2.0 - 1.0);
vec3 lightmap = texture2D(colortex2, texCoord).rgb;
vec3 clipSpace = vec3(texCoord, depth0) * 2.0 - 1.0;

/*
Lightmap and Shadow Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

vec3 getLightmap(vec3 l) {
    // torch lightmap (l.x)
    l.x = 1.0 * pow(l.x, 5.06);
    //l.x *= l.x * 8.0 / max(l.x, (eyeBrightnessSmooth.y / 16.0));
    // sky lightmap (l.y)
    //l.y = l.y * l.y * l.y * l.y;

    vec3 torchLighting = l.x * torchColor;
    vec3 skyLighting = l.y * ambientColor;
    
    return torchLighting + skyLighting;
}

float getNdotL(vec3 n, vec3 l) {
    float NdotL = max(dot(n, l), 0.0);
    if (material.x > 0.9) { // if object is foliage
        NdotL = 0.75;
    }
    return NdotL;
}

#include "/lib/util/common.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/fragment/shadows.glsl"
//#include "/lib/fragment/volumetricLight.glsl"


void main(){
    vec3 color = texture2D(colortex0, texCoord).rgb;

    float diffuse = getNdotL(normal, lightVector);

    color = color * (getLightmap(lightmap) + diffuse * lightColor * getShadow() * (1.0 - (rainStrength * 0.75)) + ambientStrength);

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
    //gl_FragData[1] = vec4(GetVolumetricRays());
}