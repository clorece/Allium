#version 130

#include "/lib/options.glsl"

float exposure = 1.3;
float gamma = 1.1;
float contrast = 0.2;

in vec2 texCoord;
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

    //color = pow(color, vec3(2.2));

    #ifdef BLOOM
        color = mix(color, getBloom(), 0.01);
    #endif

    // Sample the texture at the pixel coordinates
    //vec4 color = texture(texture0, vec2(xPixel, yPixel));

    color = getTonemap(color);
    //color = vec3(dot(color, vec3(0.333))); // greyscale

    //color = pow(color, vec3(1.0 / 2.2));
     
    gl_FragColor = vec4(color, 1.0);
}