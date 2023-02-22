#version 130

/*
Shadow Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

in vec2 texCoord;

uniform sampler2D texture;
uniform sampler2D colortex4;

void main() {
    vec4 tex = texture2D(texture, texCoord);

    gl_FragData[0] = tex;
}