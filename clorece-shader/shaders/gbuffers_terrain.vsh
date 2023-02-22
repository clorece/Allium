#version 130

out float material;
out float foliage;
out vec2 texCoord;
out vec2 lightmapCoord;
out vec3 normal;
out vec4 color;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
attribute vec4 mc_Entity;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;
    
    color = gl_Color;

    /*
    Normal and Lightmap Source Code By saada2006:
    https://github.com/saada2006/MinecraftShaderProgramming
    */
    normal = normalize(gl_NormalMatrix * gl_Normal);
    // Use the texture matrix instead of dividing by 15 to maintain compatiblity for each version of Minecraft
    lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    // Transform them into the [0, 1] range
    //lightmapCoord = (lightmapCoord * 33.05f / 32.0f) - (1.05f / 32.0f);

}