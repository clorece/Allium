#version 130

#include "/lib/options.glsl"

float exposure = 1.75;
float gamma = 1.33;
float contrast = 0.2;

in vec2 texCoord;
uniform float viewWidth;                    
uniform float viewHeight;
uniform float aspectRatio;
uniform ivec2 eyeBrightnessSmooth;
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

const float PI = 3.14159265359;

#include "/lib/util/common.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/post/tonemap.glsl"
#include "/lib/post/bloom.glsl"


void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;

    #ifdef bloom
        color = mix(color, getBloom(), 0.01);
    #endif

    color = getTonemap(color);
    //color = vec3(dot(color, vec3(0.333))); // greyscale
    gl_FragColor = vec4(color, 1.0);
}