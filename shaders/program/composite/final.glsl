#ifdef VERTEX

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FRAGMENT

in vec2 texCoord;

void main() {
    gl_FragColor = vec4(clamp(texture(colortex0, texCoord).rgb, 0.0, 1.0), 1.0);
}

#endif
