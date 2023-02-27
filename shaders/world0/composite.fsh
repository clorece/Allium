#version 130

in vec2 texCoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

float depth0 = texture2D(depthtex0, texCoord).r;

bool isBright(vec3 color) {
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));

    //temporary fix to brighten up the sky gradient
    if (depth0 == 1) {
        return luminance > 0.0;
    } else {
        return luminance > 0.5;
    }
}

void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;
    vec3 blur = vec3(0.0);

    bool bright = isBright(color);
    if (bright) {
        blur = color;
    } else {
        blur = vec3(0.0);
    }

    /* DRAWBUFFERS:3 */
    gl_FragData[0] = vec4(blur, 1.0);
}