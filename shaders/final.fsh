#version 130

//#define BAA
#define bloom

float exposure = 1.75;
float gamma = 1.33;
float contrast = 0.3;

in vec2 texCoord;
uniform float aspectRatio;
uniform ivec2 eyeBrightnessSmooth;
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

const float PI = 3.14159;

float autoExposure(float x) {
    x += x * 8.0 / max(x * 4.0, (eyeBrightnessSmooth.y / 16.0));
    return x;
}

vec3 saturate(vec3 x) {
    return clamp(x, vec3(0.0), vec3(1.0));
}

vec3 getTonemap(vec3 color) {  
    //i think this is filmic tonemap, not really sure
    float adjustedExposure = autoExposure(exposure);


    color = max(vec3(0.0), color - vec3(contrast / adjustedExposure));
	color = (color * (adjustedExposure * color + 0.5)) / (color * (adjustedExposure * color + 1.7) + 0.5);
    color = pow(color, vec3(1.0 / gamma));

    color = saturate(color * 1.33);

    return color;
}

float bayer32(vec2 a){
    uvec2 b = uvec2(a);
    uint x = ((b.x^b.y)&0x1fu) | b.y<<5;
    
    x = (x & 0x048u)
  | ((x & 0x024u) << 3)
  | ((x & 0x002u) << 6)
  | ((x & 0x001u) << 9)
  | ((x & 0x200u) >> 9)
  | ((x & 0x100u) >> 6)
  | ((x & 0x090u) >> 3); // 22 ops
  
    return float(
        x
    )/32./32.;
}

#define dither32(p)  (bayer32( p)-.499511719)
float dither = dither32(gl_FragCoord.xy);

float cosTheta = cos(dither);
float sinTheta = sin(dither);
mat2 rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

vec3 getBloom() {
    vec3 blur = vec3(1.0);
    //int weight = 0;
    int quality = 256;
    
    for(int i = 0; i < 6; i++){
            blur += texture2D(colortex3, texCoord + vec2(i, i) * rotation / quality).rgb;
            blur += texture2D(colortex3, texCoord + vec2(-i, i) * rotation / quality).rgb;
            blur += texture2D(colortex3, texCoord + vec2(i, -i) * rotation / quality).rgb;
            blur += texture2D(colortex3, texCoord + vec2(-i, -i) * rotation / quality).rgb;
    }
    
    return max(vec3(0.0), blur - vec3(1.0));
}


vec3 tonemap(vec3 color) {
  vec3 a = vec3(2.51);
  vec3 b = vec3(0.03);
  vec3 c = vec3(2.43);
  vec3 d = vec3(0.59);
  vec3 e = vec3(0.14);

  return (color * (a * color + b)) / (color * (c * color + d) + e);
}


void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;

    #ifdef bloom
        color = mix(color, getBloom(), 0.01);
    #endif

    color = tonemap(color);
    //color = vec3(dot(color, vec3(0.333))); // greyscale
    gl_FragColor = vec4(color, 1.0);
}