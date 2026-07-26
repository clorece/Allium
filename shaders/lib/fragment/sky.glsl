// sky.glsl — thin forwarding shim onto the LUT-backed atmosphere.
//
// Phase 1d migration: getSky() now resolves to atmosphereLUT.glsl::sampleSky,
// which samples the packed Hillaire 2020 LUTs in colortex12 (rebuilt every
// frame by world0/prepare.fsh). Sun/moon discs and the noon-ground blend are
// preserved inside sampleSky() so all three legacy call sites
// (d8_fog_sky.glsl:76, c_water.glsl:266, c_water.glsl:386) stay unchanged.

#include "/lib/fragment/atmosphereLUT.glsl"


vec3 getSky(vec3 rd, vec3 sunDir, vec3 moonDir, float eyeAltitude) {
    return sampleSky(rd, sunDir, moonDir, eyeAltitude);
}

// Forward to the ultra-optimized single-tap reflection sky sampler
vec3 getSkyReflection(vec3 rd, float eyeAltitude) {
    return sampleSky_fast(rd, eyeAltitude);
}

