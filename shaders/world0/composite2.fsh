#version 130

in vec2 texCoord;

uniform int frameCounter;
uniform sampler2D colortex0;

const bool colortex0Clear = false;


void main() {
    vec4 color = texture2D(colortex0, texCoord);

    /* DRAWBUFFERS:5 */
    gl_FragData[0] = color;
}