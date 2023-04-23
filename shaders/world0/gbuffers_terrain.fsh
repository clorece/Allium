#version 130

/*
Normal and Lightmap Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

in float material;
in float foliage;
in vec2 texCoord;
in vec2 lightmapCoord;
in vec3 normal;
in vec4 color;

uniform sampler2D texture; // gbuffers color channel 0

void main() {
    vec4 albedo = texture2D(texture, texCoord) * color;
    
    /* DRAWBUFFERS:0124 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
    gl_FragData[2] = vec4(lightmapCoord, 0.0, 1.0);
    gl_FragData[3] = vec4(material);
    gl_FragData[6] = color;
}