#version 130

#include "/lib/options.glsl"

float blendWeight = TAA_BLEND_WEIGHT;

in vec2 texCoord;

uniform float viewWidth;                    
uniform float viewHeight;       
uniform sampler2D colortex0;
uniform sampler2D colortex5;

#include "/lib/util/common.glsl"
#include "/lib/post/taa.glsl"

void main() {

    #ifdef TAA
        vec4 finalColor = temporalAA(texelSize);
    #else
        vec4 finalColor = texture2D(colortex0, texCoord);
    #endif

    gl_FragData[0] = finalColor;
}