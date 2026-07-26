// p0_atmosphere_lut : Hillaire 2020 atmosphere LUT pack build pass.
//
// Target: colortex12, 256×256 RGBA16F (set in shaders.properties +
//   pipelineSettings.glsl). One fragment per pixel; dispatch by region.
//
// Layout:
//   (0..255, 0..63)   Transmittance LUT  T(mu, r)
//   (0..31,  64..95)  Multi-Scatter LUT  Psi_ms(mu_s, r) — rest of band = 0
//   (0..255, 96..255) Sky-View LUT       S(azimuth, elevation_warped)
//
// Cost estimate: ~0.5 ms on a mid-range GPU.

#ifdef VERTEX

void main() {
    gl_Position = ftransform();
}

#endif

#ifdef FRAGMENT

#include "/lib/fragment/atmosphereLUT.glsl"

/* RENDERTARGETS: 12 */

void main() {
    ivec2 px = ivec2(gl_FragCoord.xy);

    // World-space sun + moon directions (uniforms are in view space).
    vec3 worldSunDir  = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    vec3 worldMoonDir = mat3(gbufferModelViewInverse) * normalize(moonPosition);

    // Eye altitude above sea level (Y=64 sea level convention used pack-wide).
    float eyeAltitude = cameraPosition.y - 64.0;

    vec3 outRgb;

    if (px.y < 64) {
        // ---- Transmittance LUT region ----
        outRgb = computeTransmittanceLUT(px);
    } else if (px.y < 96) {
        // ---- Multi-Scatter LUT region (32×32) ----
        // Re-enabled: SkyView reads this for the isotropic multi-scattering
        // term that produces the deep-blue twilight sky away from the sun.
        // Reading MS-LUT inside the same prepare pass reads the previous
        // frame's values — atmospheric parameters change slowly enough that
        // the one-frame lag is invisible. (~256M ALU/frame cost accepted.)
        if (px.x < 32) {
            outRgb = computeMultiScatterLUT(px - ivec2(0, 64));
        } else {
            outRgb = vec3(0.0);
        }
    } else {
        // ---- Sky-View LUT region (256×160) ----
        outRgb = computeSkyViewLUT(px - ivec2(0, 96), eyeAltitude, worldSunDir, worldMoonDir);
    }

    gl_FragData[0] = vec4(outRgb, 1.0);
}

#endif
