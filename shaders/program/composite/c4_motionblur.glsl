#ifdef VERTEX

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"

in vec2 texCoord;

void main() {
    vec4 sceneColor = texture(colortex0, texCoord);

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = sceneColor;
}

#endif
