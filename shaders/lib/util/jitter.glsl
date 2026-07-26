#ifndef JITTER_GLSL
#define JITTER_GLSL

#include "/lib/options.glsl"
#include "/lib/util/common.glsl"

#ifndef FRAME_COUNTER_DECLARE
#define FRAME_COUNTER_DECLARE
#endif

// Radical-inverse Halton term for one base (van der Corput).
float haltonInverse(int i, int base) {
    float f = 1.0;
    float r = 0.0;
    for (int k = 0; k < 12 && i > 0; k++) {   // 12 digits >> enough for a 16-frame cycle
        f /= float(base);
        r += f * float(i - (i / base) * base); // i % base
        i /= base;
    }
    return r;
}

vec2 getTaaJitter(int frame) {
    #ifdef TAA
        int i = (frame % 16) + 1; // skip Halton index 0 (= 0,0 = no offset)
        vec2 h = vec2(haltonInverse(i, 2), haltonInverse(i, 3)) - 0.5; // [-0.5, 0.5)
        return h * (TAA_JITTER_SCALE / (renderScale * renderScale));
    #else
        return vec2(0.0);
    #endif
}

vec2 getTaaJitter() {
    return getTaaJitter(frameCounter);
}

#endif
