#version 130

/*
Normal and Lightmap Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

in vec2 texCoord;
in vec2 lightmapCoord;
in vec3 normal;
in vec4 color;
in vec4 position;

uniform sampler2D texture; // gbuffers color channel 0
uniform sampler2D shadowtex0;

void main() {
    vec4 albedo = texture2D(texture, texCoord) * color;
    
    /* DRAWBUFFERS:01 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
    //gl_FragData[2] = vec4(lightmapCoord, 0.0, 1.0);
}