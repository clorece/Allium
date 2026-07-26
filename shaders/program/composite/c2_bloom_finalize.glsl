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
    /* DRAWBUFFERS:3 */
    gl_FragData[0] = texture(colortex3, texCoord);
}

#endif
