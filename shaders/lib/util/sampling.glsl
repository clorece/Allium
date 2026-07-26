#ifndef SAMPLING_GLSL
#define SAMPLING_GLSL

vec4 textureCatmullRom(sampler2D colortex, vec2 texcoord, vec2 resolution) {
    vec2 position = texcoord * resolution;
    vec2 centerPosition = floor(position - 0.5) + 0.5;
    vec2 f = position - centerPosition;
    vec2 f2 = f * f;
    vec2 f3 = f * f2;

    float c = 0.6;
    vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
    vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
    vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
    vec2 w3 =         c  * f3 -                c * f2;

    vec2 w12 = w1 + w2;
    vec2 tc12 = (centerPosition + w2 / w12) / resolution;

    vec2 tc0 = (centerPosition - 1.0) / resolution;
    vec2 tc3 = (centerPosition + 2.0) / resolution;
    
    vec4 color = texture(colortex, vec2(tc12.x, tc0.y )) * (w12.x * w0.y ) +
                 texture(colortex, vec2(tc0.x,  tc12.y)) * (w0.x  * w12.y) +
                 texture(colortex, vec2(tc12.x, tc12.y)) * (w12.x * w12.y) +
                 texture(colortex, vec2(tc3.x,  tc12.y)) * (w3.x  * w12.y) +
                 texture(colortex, vec2(tc12.x, tc3.y )) * (w12.x * w3.y );
    return color;
}

#endif
