#include "/lib/options.glsl"

#ifdef VERTEX

#include "/lib/util/jitter.glsl"

out vec2 texCoord;
out vec2 lightmapCoord;
out vec3 normal;
out vec4 color;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;

    color = gl_Color;

    /*
    Normal and Lightmap Source Code By saada2006:
    https://github.com/saada2006/MinecraftShaderProgramming
    */
    normal = normalize(gl_NormalMatrix * gl_Normal);
    lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;

    #ifdef TAA
        gl_Position.xy += getTaaJitter() * 2.0 * gl_Position.w / vec2(viewWidth, viewHeight);
    #endif

    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
}

#endif

#ifdef FRAGMENT

/*
Normal and Lightmap Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

in vec2 texCoord;
in vec2 lightmapCoord;
in vec3 normal;
in vec4 color;


void main() {
    vec4 albedo = texture(texture, texCoord) * color;

    /* DRAWBUFFERS:012 */
    gl_FragData[0] = albedo;    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 0.0); // .a = 0 (default material; see terrain.glsl colortex1.a packing)
    gl_FragData[2] = vec4(lightmapCoord, 0.0, 1.0);
}

#endif
