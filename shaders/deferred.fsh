#version 130
#extension GL_ARB_shader_texture_lod : enable 

#define shadowFiltering
#define shadowResolution 2048 //[512 1024 2048 4096 8192]
#define shadowFilterQuality 3 //[2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

const int shadowMapResolution = shadowResolution;
const float shadowMapBias = 0.85;
const float shadowDistance = 128.0;
const float sunPathRotation = 40.0;
const float ambientOcclusionLevel = 0.25; // minecraft ambient occlusion level
const float ambientStrength = 0.30;    // ambient strength and shadow darkness
const vec3 torchColor = vec3(0.9922, 0.6471, 0.1922);

const bool shadowHardwareFiltering = true;
const bool shadowtex1Mipmap = true;
const bool shadowtex1Nearest = false;

in vec2 texCoord;
in vec3 lightColor;
in vec3 ambientColor;
in vec3 lightVector;

uniform float far;
uniform float rainStrength;
uniform ivec2 eyeBrightness;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2DShadow shadow;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

float depth0 = texture2D(depthtex0, texCoord).r;
vec3 normal = normalize(texture2D(colortex1, texCoord).rgb * 2.0 - 1.0);
vec3 lightmap = texture2D(colortex2, texCoord).rgb;
vec3 clipSpace = vec3(texCoord, depth0) * 2.0 - 1.0;

float bayer32(vec2 a){
    uvec2 b = uvec2(a);
    uint x = ((b.x^b.y)&0x1fu) | b.y<<5;
    
    x = (x & 0x048u)
  | ((x & 0x024u) << 3)
  | ((x & 0x002u) << 6)
  | ((x & 0x001u) << 9)
  | ((x & 0x200u) >> 9)
  | ((x & 0x100u) >> 6)
  | ((x & 0x090u) >> 3); // 22 ops
  
    return float(
        x
    )/32./32.;
}

#define dither32(p)  (bayer32( p)-.499511719)
float dither = dither32(gl_FragCoord.xy);

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

float lambert(vec3 n, vec3 l) {
    float NdotL = dot(n, l);
    return max(NdotL, 0.0);
}


vec4 getFragPosition() {
    vec4 fragPosition = gbufferProjectionInverse * vec4(clipSpace, 1.0);
    fragPosition.xyz /= fragPosition.w;

    return fragPosition;
}

vec4 getWorldPosition() {
    vec4 fragPosition = getFragPosition();
    vec4 worldPosition = gbufferModelViewInverse * vec4(fragPosition.xyz, 1.0);

    return worldPosition;
}

vec4 toShadowSpace() {
    vec4 worldPosition = getWorldPosition();
    vec4 shadowSpace = shadowProjection * shadowModelView * worldPosition;
    float centerDistance = length(shadowSpace.xy);
	float distortFactor = (1.0 - shadowMapBias) + centerDistance * shadowMapBias;
    shadowSpace.xy /= distortFactor;
    shadowSpace.xyz = shadowSpace.xyz * 0.5 + 0.5;

    return shadowSpace;
}

vec3 getShadow() {
    int samples = shadowFilterQuality;

    float shading = 0.0;
    float shading1 = 0.0;
    vec3 finalShading = vec3(0.0);
    vec4 shading2 = vec4(0.0);

    vec4 worldPosition = toShadowSpace();

    float cosTheta = cos(dither);
    float sinTheta = sin(dither);
    mat2 rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

    #ifdef shadowFiltering
        for(int x = 0; x < samples; x++){
            for(int y = 0; y < samples; y++){
                vec2 offset = vec2(x, y) * (rotation / shadowMapResolution);

                shading = step(worldPosition.z - 0.001, texture2D(shadowtex0, worldPosition.xy + offset).x);
                shading1 = step(worldPosition.z - 0.001, texture2D(shadowtex1, worldPosition.xy + offset).x);
                //shading = texture2D(shadowtex0, worldPosition.xy + offset).x;
                //shading1 = texture2D(shadowtex1, worldPosition.xy + offset).x;
                shading2 = texture2D(shadowcolor0, worldPosition.xy + offset);

                finalShading += mix(shading2.rgb * shading1, vec3(1.0), shading);
                //finalShading += mix(shading, shading1, shading2.rgb);
            }
        }
        finalShading /= pow(samples, 2.0);
    #else
        shading = step(worldPosition.z - 0.001, texture2D(shadowtex0, worldPosition.xy).x);
        shading1 = step(worldPosition.z - 0.001, texture2D(shadowtex1, worldPosition.xy).x);
        shading2 = texture2D(shadowcolor0, worldPosition.xy);
        finalShading = mix(shading2.rgb * shading1, vec3(1.0), shading);
    #endif

    return finalShading;
}

void main(){
    vec3 color = texture2D(colortex0, texCoord).rgb;
    if (depth0 != 1) color = color * (getLightmap(lightmap) + lambert(normal, lightVector) * lightColor * getShadow() * (1.0 - (rainStrength * 0.75)) + ambientStrength);
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
    //gl_FragData[1] = vec4(lightmap, vec2(1.0));
}