#ifndef RAND_GLSL
#define RAND_GLSL

// PCG hash (O'Neill 2014) — avoids correlation artifacts of sin-based hashes
uint pcgHash(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word  = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}


float randFloat(inout uint seed) {
    seed = pcgHash(seed);
    return float(seed >> 8u) * (1.0 / float(1u << 24u));
}

uint pixelSeed(ivec2 pixel, int frame) {
    return pcgHash(uint(pixel.x) ^ (uint(pixel.y) << 16u) ^ uint(frame) * 1664525u);
}

#endif
