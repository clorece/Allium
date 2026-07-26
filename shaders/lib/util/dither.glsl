#ifndef DITHER_GLSL
#define DITHER_GLSL

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
#ifdef FRAGMENT
float dither = dither32(gl_FragCoord.xy);

float cosTheta = cos(dither);
float sinTheta = sin(dither);
mat2 rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
#endif

float interleavedGradientNoise(vec2 position, int frame) {
    float n = 52.9829189 * fract(dot(position, vec2(0.06711056, 0.00583715)));
    return fract(n + 1.6180339887 * mod(float(frame), 3600.0));
}

#endif