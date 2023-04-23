#version 130

#include "/lib/options.glsl"

in vec2 texCoord;
   
uniform sampler2D colortex0;
uniform sampler2D colortex5;

#include "/lib/util/common.glsl"
#include "/lib/post/taa.glsl"

void main() {

    // Get the current pixel's position
    vec2 currentPos = texCoord / texelSize;

    #ifdef TAA
        vec4 finalColor = taa(currentPos, vec2(viewWidth, viewHeight), colortex0, colortex5);
    #else
        vec4 finalColor = texture2D(colortex0, texCoord);
    #endif
    
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = finalColor;
}