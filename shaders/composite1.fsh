#version 130

in vec2 texCoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;

float depth0 = texture2D(depthtex0, texCoord).r;

float weight[5] = float[] (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
vec3 normal = normalize(texture2D(colortex1, texCoord).rgb * 2.0 - 1.0);

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
    vec3 blur = normal;

    bool bright = isBright(color);
    if (bright) {
        blur = color;
    } else {
        blur = vec3(0.0);
    }

    /* DRAWBUFFERS:3 */
    gl_FragData[0] = vec4(blur, 1.0);
}