#ifndef ATMOSPHERE_LUT_GLSL
#define ATMOSPHERE_LUT_GLSL

// Hillaire 2020 atmosphere LUT pack — build kernels + sample helpers.
//
// Buffer layout in colortex12 (256×256 RGBA16F, set in shaders.properties):
//   (0..255, 0..63)   T-LUT       transmittance T(mu, r)             RGB
//   (0..31,  64..95)  MS-LUT      isotropic multi-scatter Psi_ms     RGB
//   (0..255, 96..255) Sky-View    sampled per camera-local lat/long  RGB (160 rows)
//
// Reference: "A Scalable and Production Ready Sky and Atmosphere Rendering
// Technique" — Sébastien Hillaire, EGSR 2020 (Listings 3, 5, 6, §5.4).
//
// To avoid in-pass read-modify-write on colortex12, the MS-LUT and Sky-View
// builds compute transmittance INLINE rather than sampling the T-LUT region
// being written this frame. Cost difference is negligible (~0.3ms).
//
// All sample helpers apply 0.5-texel inset into their region so bilinear
// filtering never bleeds into adjacent (different-meaning) regions.

#include "/lib/options.glsl"

#include "/lib/fragment/atmosphereConstants.glsl"

const vec2  LUT_PACK_SIZE = vec2(256.0, 256.0);
const float T_LUT_W = 256.0;
const float T_LUT_H = 64.0;
const float MS_LUT_W = 32.0;
const float MS_LUT_H = 32.0;
const float MS_LUT_Y_OFFSET = 64.0;
const float SV_LUT_W = 256.0;
const float SV_LUT_H = 160.0;
const float SV_LUT_Y_OFFSET = 96.0;


// =============================================================================
// Internal helpers
// =============================================================================

// 20-step inline transmittance from (r, mu) to top of atmosphere (or planet
// hit, whichever first). Used by MS and SkyView builds without sampling LUT.
vec3 _inlineTransmittanceToTOA(float r, float mu) {
    // Ray-sphere with planet first (gives ground shadowing for sun visibility).
    float discriminantTOA = r*r * (mu*mu - 1.0) + ATMOSPHERE_RADIUS_SQUARED;
    if (discriminantTOA < 0.0) return vec3(0.0);
    float dTOA = max(-r*mu + sqrt(discriminantTOA), 0.0);

    // Planet intersection (negative discriminant ⇒ ray misses planet, full T)
    float discriminantGround = r*r * (mu*mu - 1.0) + PLANET_RADIUS * PLANET_RADIUS;
    bool hitsGround = (mu < 0.0) && (discriminantGround >= 0.0);
    if (hitsGround) return vec3(0.0);  // Sun below horizon ⇒ no light

    // Soft atmospheric shadow/penumbra blend near the horizon
    float shadowFade = 1.0;
    if (mu < 0.0) {
        float d_min = r * sqrt(1.0 - mu*mu);
        float h_min = d_min - PLANET_RADIUS;
        // Smoothly fade between 2km and 12km to simulate realistic soft horizon shadow
        shadowFade = smoothstep(2000.0, 12000.0, h_min);
        if (shadowFade == 0.0) return vec3(0.0);
    }

    const int N = 10;  // quadratic spacing: 10 steps clusters samples near the ground for perfect low-sun accuracy
    vec3 opticalDepth = vec3(0.0);
    float tLast = 0.0;
    for (int i = 0; i < N; ++i) {
        float x = float(i + 1) / float(N);
        float tEdge = x * x * dTOA;
        float t = 0.5 * (tLast + tEdge);
        float ds = tEdge - tLast;
        tLast = tEdge;

        float dist = sqrt(r*r + 2.0 * r * mu * t + t*t);
        vec3 density = GetAtmosphereDensity(dist);
        opticalDepth += (COEFF_ATTENUATION * density) * ds;
    }
    return exp(-opticalDepth) * shadowFade;
}

// Hammersley sequence in 2D for low-discrepancy sphere sampling (no texture).
float _radicalInverse_VdC(uint bits) {
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10;
}

vec2 _hammersley(uint i, uint N) {
    return vec2(float(i) / float(N), _radicalInverse_VdC(i));
}

// Uniform direction on unit sphere from (u1, u2) ∈ [0,1]².
vec3 _uniformSphere(vec2 u) {
    float z   = 1.0 - 2.0 * u.x;
    float r2  = sqrt(max(0.0, 1.0 - z*z));
    float phi = 2.0 * pi * u.y;
    return vec3(r2 * cos(phi), z, r2 * sin(phi));
}


// =============================================================================
// SAMPLE helpers (called by sky.glsl, c_water.glsl, d0_restir.glsl, etc.)
// =============================================================================

// Manual bilinear from colortex12 with explicit clamp to a packed region.
// Necessary because `textureLod(c, uv, 0)` on a non-mipmapped render target
// can fall back to NEAREST under Iris depending on the configured MIN filter,
// which causes visible LUT-row banding in the sky. This forces LINEAR
// regardless of the sampler's filter state and prevents bilinear from
// bleeding across region boundaries (T → MS → SkyView).
vec3 _bilinearLUT(vec2 uv_global, ivec2 regionMin, ivec2 regionMaxExclusive) {
    vec2 px  = uv_global * LUT_PACK_SIZE - 0.5;
    vec2 frc = fract(px);
    ivec2 base = ivec2(floor(px));
    // Clamp so base..base+1 stays inside [regionMin, regionMaxExclusive-1].
    base = clamp(base, regionMin, regionMaxExclusive - 2);

    vec3 c00 = texelFetch(colortex12, base + ivec2(0, 0), 0).rgb;
    vec3 c10 = texelFetch(colortex12, base + ivec2(1, 0), 0).rgb;
    vec3 c01 = texelFetch(colortex12, base + ivec2(0, 1), 0).rgb;
    vec3 c11 = texelFetch(colortex12, base + ivec2(1, 1), 0).rgb;
    vec3 c0 = mix(c00, c10, frc.x);
    vec3 c1 = mix(c01, c11, frc.x);
    return mix(c0, c1, frc.y);
}

vec2 _transmittanceLUT_UV(float mu, float r) {
    float H_top = sqrt(ATMOSPHERE_RADIUS_SQUARED - PLANET_RADIUS * PLANET_RADIUS);
    float rho   = sqrt(max(0.0, r*r - PLANET_RADIUS * PLANET_RADIUS));
    float discriminant = r*r * (mu*mu - 1.0) + ATMOSPHERE_RADIUS_SQUARED;
    float d = max(-r*mu + sqrt(max(0.0, discriminant)), 0.0);
    float d_min = ATMOSPHERE_RADIUS - r;
    float d_max = rho + H_top;
    float x_mu = (d_max > d_min) ? clamp((d - d_min) / (d_max - d_min), 0.0, 1.0) : 0.0;
    float x_r  = (H_top > 0.0) ? clamp(rho / H_top, 0.0, 1.0) : 0.0;
    // Region (0..255, 0..63) with 0.5-texel inset, packed in 256×256.
    return vec2(
        (0.5 + x_mu * (T_LUT_W - 1.0)) / LUT_PACK_SIZE.x,
        (0.5 + x_r  * (T_LUT_H - 1.0)) / LUT_PACK_SIZE.y
    );
}

vec3 sampleTransmittanceLUT(float mu, float r) {
    // T-LUT region: (0..255, 0..63), clamp base index so bilinear stays inside.
    return _bilinearLUT(_transmittanceLUT_UV(mu, r), ivec2(0, 0), ivec2(int(T_LUT_W), int(T_LUT_H)));
}

// Single-tap T-LUT for hot paths (per-step VL / AP integration). T-LUT values
// vary smoothly with (mu, r) so NEAREST quantization is averaged out across
// the 8–16 integration steps; using textureLod cuts 4 texelFetch → 1 per call.
// Reserve `sampleTransmittanceLUT` (bilinear) for one-shot uses like sun-disc
// extinction in sampleSky where the result is read directly per pixel.
vec3 sampleTransmittanceLUT_fast(float mu, float r) {
    return textureLod(colortex12, _transmittanceLUT_UV(mu, r), 0.0).rgb;
}

vec2 _multiScatterLUT_UV(float mu_s, float r) {
    float x_ms = clamp(0.5 * mu_s + 0.5, 0.0, 1.0);
    float x_r  = clamp((r - PLANET_RADIUS) / (ATMOSPHERE_RADIUS - PLANET_RADIUS), 0.0, 1.0);
    // Region (0..31, 64..95) with 0.5-texel inset.
    return vec2(
        (0.5 + x_ms * (MS_LUT_W - 1.0)) / LUT_PACK_SIZE.x,
        (MS_LUT_Y_OFFSET + 0.5 + x_r * (MS_LUT_H - 1.0)) / LUT_PACK_SIZE.y
    );
}

vec3 sampleMultiScatterLUT(float mu_s, float r) {
    // MS-LUT region: (0..31, 64..95).
    int yMin = int(MS_LUT_Y_OFFSET);
    int yMaxExcl = int(MS_LUT_Y_OFFSET + MS_LUT_H);
    return _bilinearLUT(_multiScatterLUT_UV(mu_s, r), ivec2(0, yMin), ivec2(int(MS_LUT_W), yMaxExcl));
}

// Single-tap MS-LUT for hot paths (per-step inside SkyView build). MS values
// are smooth in (mu_s, r) so single-tap quantization is averaged across the
// 32 SkyView integration steps and invisible.
vec3 sampleMultiScatterLUT_fast(float mu_s, float r) {
    return textureLod(colortex12, _multiScatterLUT_UV(mu_s, r), 0.0).rgb;
}

vec2 _skyViewLUT_UV(vec3 worldDir) {
    // Camera-local lat/long. elevation ∈ [-π/2, π/2], azimuth ∈ [-π, π].
    float elevation = asin(clamp(worldDir.y, -1.0, 1.0));
    float azimuth   = atan(worldDir.z, worldDir.x);

    // Hillaire sqrt warp around horizon: v_warped = 0.5 ± 0.5·sqrt(|e|/(π/2))
    float e_norm = elevation / (0.5 * pi);                       // -1..+1
    float v_warped = 0.5 + 0.5 * sign(e_norm) * sqrt(abs(e_norm));

    float u_warped = (azimuth / (2.0 * pi)) + 0.5;               // 0..1

    // Region (0..255, 96..255) with 0.5-texel inset.
    return vec2(
        (0.5 + clamp(u_warped, 0.0, 1.0) * (SV_LUT_W - 1.0)) / LUT_PACK_SIZE.x,
        (SV_LUT_Y_OFFSET + 0.5 + clamp(v_warped, 0.0, 1.0) * (SV_LUT_H - 1.0)) / LUT_PACK_SIZE.y
    );
}

vec3 sampleSkyViewLUT(vec3 worldDir, float eyeAltitude) {
    // SkyView region: (0..255, 96..255).
    int yMin = int(SV_LUT_Y_OFFSET);
    int yMaxExcl = int(SV_LUT_Y_OFFSET + SV_LUT_H);
    return _bilinearLUT(_skyViewLUT_UV(worldDir), ivec2(0, yMin), ivec2(int(SV_LUT_W), yMaxExcl));
}

#if SKY_DEBUG != 0
// Hard NEAREST tap of the SkyView LUT (debug mode 2): rounds to the owning
// texel via texelFetch, bypassing any filtering, to expose whether the layers
// are an upscale/filter artifact vs already baked into the LUT.
vec3 _nearestSkyViewLUT(vec3 worldDir) {
    vec2 px = _skyViewLUT_UV(worldDir) * LUT_PACK_SIZE;
    ivec2 t = ivec2(floor(px));
    t.x = clamp(t.x, 0, int(SV_LUT_W) - 1);
    t.y = clamp(t.y, int(SV_LUT_Y_OFFSET), int(SV_LUT_Y_OFFSET + SV_LUT_H) - 1);
    return texelFetch(colortex12, t, 0).rgb;
}

// Tints the raw LUT sample wherever we are near a SkyView texel boundary, so
// the LUT grid is visible over the sky (debug mode 3): if the "layers" snap to
// these lines the problem is LUT resolution; if they sit between lines it isn't.
vec3 _skyViewGridOverlay(vec3 worldDir, float eyeAltitude) {
    vec3 base = sampleSkyViewLUT(worldDir, eyeAltitude);
    vec2 px   = _skyViewLUT_UV(worldDir) * LUT_PACK_SIZE;
    vec2 f    = abs(fract(px) - 0.5);          // ->0.5 at texel boundary, 0 at center
    float line = smoothstep(0.44, 0.5, f.x) + smoothstep(0.44, 0.5, f.y);
    return mix(base, vec3(1.0, 0.0, 1.0), clamp(line, 0.0, 1.0) * 0.6);
}
#endif

// Transmittance from camera through atmosphere along worldDir for the given
// path length (in meters). Approximated via T-LUT ratio:
//   T_path = T(r_cam, mu) / T(r_end, mu_end)
// where r_end and mu_end are derived from advancing along the ray.
// For atmospheric perspective (terrain-distance scattering).
vec3 sampleTransmittanceAlong(vec3 worldDir, float eyeAltitude, float pathLength) {
    float r0 = PLANET_RADIUS + max(eyeAltitude, 0.0);
    vec3  pos0 = vec3(0.0, r0, 0.0);
    vec3  pos1 = pos0 + worldDir * pathLength;
    float r1 = length(pos1);

    float mu0 = clamp(dot(normalize(pos0), worldDir), -1.0, 1.0);
    float mu1 = clamp(dot(normalize(pos1), worldDir), -1.0, 1.0);

    vec3 T0 = sampleTransmittanceLUT(mu0, r0);
    vec3 T1 = sampleTransmittanceLUT(mu1, r1);
    // Avoid div-by-zero at horizon
    return clamp(T0 / max(T1, vec3(1e-5)), vec3(0.0), vec3(1.0));
}


// =============================================================================
// LUT BUILD kernels (called from prepare.fsh per-texel)
// =============================================================================

// T-LUT region. px ∈ (0..255, 0..63). Returns RGB transmittance to TOA.
// Parameterization: Bruneton/Hillaire (Hillaire 2020 Listing 3).
vec3 computeTransmittanceLUT(ivec2 px) {
    vec2 uv_local = (vec2(px) + 0.5) / vec2(T_LUT_W, T_LUT_H);
    float x_mu = uv_local.x;
    float x_r  = uv_local.y;

    float H_top = sqrt(ATMOSPHERE_RADIUS_SQUARED - PLANET_RADIUS * PLANET_RADIUS);
    float rho   = H_top * x_r;
    float r     = sqrt(rho * rho + PLANET_RADIUS * PLANET_RADIUS);
    float d_min = ATMOSPHERE_RADIUS - r;
    float d_max = rho + H_top;
    float d     = d_min + x_mu * (d_max - d_min);
    float mu    = (d > 0.0)
                ? clamp((H_top*H_top - rho*rho - d*d) / (2.0 * r * d), -1.0, 1.0)
                : 1.0;

    const int N = 16;  // quadratic spacing: 16 steps gives ground precision equivalent to >100 linear steps
    vec3 opticalDepth = vec3(0.0);
    float tLast = 0.0;
    for (int i = 0; i < N; ++i) {
        float x = float(i + 1) / float(N);
        float tEdge = x * x * d;
        float t = 0.5 * (tLast + tEdge);
        float ds = tEdge - tLast;
        tLast = tEdge;

        float dist = sqrt(r*r + 2.0 * r * mu * t + t*t);
        vec3 density = GetAtmosphereDensity(dist);
        opticalDepth += (COEFF_ATTENUATION * density) * ds;
    }
    return exp(-opticalDepth);
}

// MS-LUT region. px ∈ (0..31, 0..31). Returns Psi_ms (isotropic infinite-bounce
// multi-scatter) per Hillaire 2020 §3.3.
vec3 computeMultiScatterLUT(ivec2 px_local) {
    vec2 uv_local = (vec2(px_local) + 0.5) / vec2(MS_LUT_W, MS_LUT_H);
    float mu_s = 2.0 * uv_local.x - 1.0;   // -1..+1
    float r    = mix(PLANET_RADIUS, ATMOSPHERE_RADIUS, uv_local.y);

    vec3 pos    = vec3(0.0, r, 0.0);
    vec3 sunDir = vec3(sqrt(max(0.0, 1.0 - mu_s * mu_s)), mu_s, 0.0);

    const uint N_SPHERE = 64u;
    const int  N_RAY    = 20;
    const float invSphere = 1.0 / float(N_SPHERE);
    const float phaseIsotropic = 1.0 / (4.0 * pi);

    vec3 L2_acc   = vec3(0.0);
    vec3 f_ms_acc = vec3(0.0);

    for (uint s = 0u; s < N_SPHERE; ++s) {
        vec3 w = _uniformSphere(_hammersley(s, N_SPHERE));

        // Distance along w from pos to TOA (or planet, whichever first).
        vec2 aid = GetRaySphereIntersection(pos, w, ATMOSPHERE_RADIUS);
        vec2 pid = GetRaySphereIntersection(pos, w, PLANET_RADIUS);
        float tEnd = (pid.x > 0.0) ? pid.x : aid.y;
        if (tEnd <= 0.0) continue;

        float ds = tEnd / float(N_RAY);
        vec3 transRay = vec3(1.0);

        for (int i = 0; i < N_RAY; ++i) {
            float t = (float(i) + 0.5) * ds;
            vec3  p_t      = pos + w * t;
            float altitude = length(p_t);
            vec3  density  = GetAtmosphereDensity(altitude);

            vec3 sigma_s = COEFF_RAYLEIGH * density.x + COEFF_MIE * density.y;
            vec3 sigma_e = sigma_s + COEFF_OZONE * density.z;

            // Sun visibility at this sample
            float mu_s_local = dot(normalize(p_t), sunDir);
            vec3  sunT = _inlineTransmittanceToTOA(altitude, mu_s_local);

            vec3 stepT = exp(-sigma_e * ds);
            // Energy-conserving step accumulation (Hillaire eq. integration)
            vec3 inscatterStep = transRay * (sigma_s * sunT * phaseIsotropic) * (1.0 - stepT) / max(sigma_e, vec3(1e-7));
            vec3 fmsStep       = transRay * (sigma_s * phaseIsotropic)        * (1.0 - stepT) / max(sigma_e, vec3(1e-7));

            L2_acc   += inscatterStep;
            f_ms_acc += fmsStep;
            transRay *= stepT;
        }
    }

    vec3 L2   = L2_acc   * invSphere;
    vec3 fms  = f_ms_acc * invSphere;
    // Sun illuminance is factored at consumption time, not here. L2 here is
    // L2 per unit sun illuminance (i.e. divided by sun base color).
    vec3 psi_ms = L2 / max(vec3(1.0) - fms, vec3(1e-3));
    return psi_ms;
}

// SkyView LUT region. px ∈ (0..255, 0..159). Returns RGB radiance for the
// camera-local view direction encoded as (azimuth, elevation_warped).
//
// Uncomment LUT_DEBUG_GRADIENT to re-enable the smooth red/green debug pattern
// (used to verify the build/sample chain).
//#define LUT_DEBUG_GRADIENT

vec3 computeSkyViewLUT(ivec2 px_local, float eyeAltitude, vec3 sunDir, vec3 moonDir) {
    vec2 uv_local = (vec2(px_local) + 0.5) / vec2(SV_LUT_W, SV_LUT_H);

#ifdef LUT_DEBUG_GRADIENT
    return vec3(uv_local.x, uv_local.y, 0.5);
#endif

    // Hillaire's sqrt warp: v ∈ [0,1] with horizon at v=0.5
    float v_centered = 2.0 * uv_local.y - 1.0;                 // -1..+1
    float elevation = sign(v_centered) * v_centered * v_centered * (0.5 * pi);
    float azimuth   = 2.0 * pi * (uv_local.x - 0.5);            // -π..+π

    float cosE = cos(elevation);
    vec3 worldDir = vec3(
        cosE * cos(azimuth),
        sin(elevation),
        cosE * sin(azimuth)
    );

    float r = PLANET_RADIUS + max(eyeAltitude, 0.0);
    vec3 pos = vec3(0.0, r, 0.0);

    vec2 aid = GetRaySphereIntersection(pos, worldDir, ATMOSPHERE_RADIUS);
    // Intentionally shrink the planet (0.998·R_p) so near-horizon rays graze a
    // little atmosphere BELOW the geometric horizon — that soft sub-horizon glow
    // is what keeps the limb from cutting to black. (The faint dawn/dusk seam
    // this shell used to cause came from sub-surface density blowing up; that is
    // handled by clamping the marched radius to >= PLANET_RADIUS in the loop.)
    vec2 pid = GetRaySphereIntersection(pos, worldDir, PLANET_RADIUS * 0.998);
    if (aid.y < 0.0) return vec3(0.0);

    bool planetHit = pid.y >= 0.0 && pid.x > 0.0;
    float tStart = max(aid.x, 0.0);
    float tEnd   = planetHit ? pid.x : aid.y;

    // Uniform stepping per Hillaire 2020 Listing 5. Quadratic spacing was
    // tried as an "adaptive" optimization, but for SkyView it clusters all
    // samples near the camera and leaves the last step covering ~19% of the
    // ray — for horizon-grazing rays (dEnd ~100km) that's a single ~19km
    // segment carrying a large chunk of inscatter. dEnd varies with
    // elevation, so the discretization error varies row-to-row, producing
    // the visible elevation-banded stripes above the horizon.
    // (Quadratic spacing is still correct for the T-LUT and MS-LUT inline
    // marches because those integrate a monotonic smooth quantity.)
    const int N = SKY_LUT_STEPS;
    float dEnd = tEnd - tStart;
    if (dEnd <= 0.0) return vec3(0.0);
    float ds = dEnd / float(N);

    vec3 scatter = vec3(0.0);
    vec3 trans   = vec3(1.0);

#if SKY_DEBUG >= 10
    // Per-term accumulators so the debug modes can show exactly one physical
    // contribution in isolation (see SKY_DEBUG in options.glsl).
    vec3 dbgSunRay = vec3(0.0);   // sun Rayleigh
    vec3 dbgSunMie = vec3(0.0);   // sun Mie
    vec3 dbgMS     = vec3(0.0);   // multi-scatter (sun)
    vec3 dbgSunT   = vec3(0.0);   // sun transmittance (sunT), step-weighted
    vec3 dbgMoon   = vec3(0.0);   // moon total
#endif

    vec2 phaseSun  = GetPhase(dot(worldDir, sunDir),  MIE_G);
    vec2 phaseMoon = GetPhase(dot(worldDir, moonDir), MIE_G);

    float sunFade  = smoothstep(-0.2, 0.05, sunDir.y);
    float moonFade = smoothstep(-0.2, 0.05, moonDir.y);

    // View-space Earth-shadow anchor (see BELT_VIEW_SHADOW in options.glsl). The
    // forward Mie phase peaks toward the just-set sun (below the horizon), so the
    // DIRECT warm glow would otherwise pool below worldDir.y = 0 as a misaligned
    // band. Fade the direct term out just below the view horizon so the warm glow
    // hugs the horizon line; multi-scatter is left untouched (soft sub-horizon
    // limb glow stays). Constant per view direction -> computed once, not per step.
    float sunViewBelt  = 1.0;
    float moonViewBelt = 1.0;
#ifdef BELT_OF_VENUS
    float viewHorizon = smoothstep(-0.03, 0.02, worldDir.y);   // 0 below horizon -> 1 above
    sunViewBelt  = mix(1.0, viewHorizon, (1.0 - smoothstep(0.0, 0.12, sunDir.y))  * BELT_VIEW_SHADOW);
    moonViewBelt = mix(1.0, viewHorizon, (1.0 - smoothstep(0.0, 0.12, moonDir.y)) * BELT_VIEW_SHADOW);
#endif

    for (int i = 0; i < N; ++i) {
        float t = tStart + (float(i) + 0.5) * ds;

        vec3  p_t      = pos + worldDir * t;
        // Clamp to the surface. The planet intersection above uses
        // PLANET_RADIUS*0.998, so horizon-grazing rays in that 0.2% shell are
        // treated as misses and keep marching, but their samples dip just below
        // the real surface. GetAtmosphereDensity() grows as exp((R_p-r)/H_mie)
        // with H_mie=1.2km, so a sample 0.2% below R_p is ~40000x surface
        // density — a spurious bright band exactly at the horizon. Never sample
        // sub-surface. No-op for every above-surface ray.
        float altitude = max(length(p_t), PLANET_RADIUS);
        vec3  density  = GetAtmosphereDensity(altitude);

        vec3 sigma_s_r = COEFF_RAYLEIGH * density.x;
        vec3 sigma_s_m = COEFF_MIE * density.y;
        vec3 sigma_s   = sigma_s_r + sigma_s_m;
        vec3 sigma_e   = sigma_s + COEFF_OZONE * density.z;

        vec3  upAtP      = normalize(p_t);
        float mu_s_local = dot(upAtP, sunDir);
        float mu_m_local = dot(upAtP, moonDir);
        // Smooth sun/moon visibility from the bilinear T-LUT (prev frame, like
        // the MS-LUT read below). The old inline _inlineTransmittanceToTOA had a
        // HARD planet-shadow terminator (hitsGround / shadowFade==0 → return 0);
        // sampled at each discrete march step that produced the concentric
        // hard-edged shadow "shells" that slid out from the sun at dawn/dusk
        // (debug isolated the artifact to sunT, present in the Rayleigh AND Mie
        // sun terms but absent from multi-scatter). The T-LUT encodes the same
        // extinction but continuously — grazing/sub-horizon rays fall to ~0 via
        // the long optical path, with no discontinuity to alias.
        // NOTE arg order: sampleTransmittanceLUT(mu, r), not (r, mu).
        vec3  sunT  = sampleTransmittanceLUT(mu_s_local, altitude);
        vec3  moonT = sampleTransmittanceLUT(mu_m_local, altitude);

        // Multiple scattering term (isotropic approximation)
        vec3  psi_ms_sun  = sampleMultiScatterLUT_fast(mu_s_local, altitude);
        vec3  psi_ms_moon = sampleMultiScatterLUT_fast(mu_m_local, altitude);

        vec3 stepT = exp(-sigma_e * ds);

        const float phaseIsotropic = 1.0 / (4.0 * pi);
        vec3 phaseScatterSun  = sigma_s_r * phaseSun.x  + sigma_s_m * phaseSun.y;
        vec3 phaseScatterMoon = sigma_s_r * phaseMoon.x + sigma_s_m * phaseMoon.y;

        // Earth's shadow / Belt of Venus: smooth per-sample planet shadow on the
        // DIRECT sun in-scatter only (multi-scatter stays, so the shadowed band
        // is bluish-grey, not black — pink belt above, blue band below). A sample
        // at radius r is lit when the sun is above ITS astronomical horizon,
        // mu_s_local > muSunHorizon = -sqrt(1 - (R_p/r)^2). Higher samples have a
        // lower horizon, so they stay lit further past sunset → the lit band sits
        // above the shadowed one. Smooth + wide (BELT_SHADOW_SOFTNESS) and a
        // function of mu_s_local (continuous, no hard cutoff) so it can't alias
        // into the march "shells" the old hard terminator produced.
        float eShadow = 1.0;
#ifdef BELT_OF_VENUS
        float muSunHorizon = -sqrt(max(0.0, 1.0 - (PLANET_RADIUS * PLANET_RADIUS) / (altitude * altitude)));
        eShadow = smoothstep(muSunHorizon - BELT_SHADOW_SOFTNESS, muSunHorizon + BELT_SHADOW_SOFTNESS, mu_s_local);
#endif

        // Gate the WHOLE sun/moon contribution (direct + multi-scatter) by the
        // global day/night fade. The T-LUT we now use for sunT has no planet
        // occlusion, so the direct term would otherwise keep lighting the sky
        // below the horizon (orange "sunset" glow at night). sunFade depends only
        // on the global sun elevation, so it is identical for every march step
        // and view direction — it cannot reintroduce the per-step shadow shells
        // the inline terminator caused (that is why this gate is safe here).
        vec3 inscatter = sunFade  * (sunT  * phaseScatterSun * eShadow * sunViewBelt  + psi_ms_sun  * sigma_s * phaseIsotropic) * SUN_COLOR_BASE
                       + moonFade * (moonT * phaseScatterMoon          * moonViewBelt + psi_ms_moon * sigma_s * phaseIsotropic) * MOON_COLOR_BASE;

        // Energy-conserving step
        vec3 stepW = trans * (1.0 - stepT) / max(sigma_e, vec3(1e-7));
        scatter += inscatter * stepW;

#if SKY_DEBUG >= 10
        dbgSunRay += sunFade  * (sunT * sigma_s_r * phaseSun.x * eShadow * sunViewBelt)  * SUN_COLOR_BASE  * stepW;
        dbgSunMie += sunFade  * (sunT * sigma_s_m * phaseSun.y * eShadow * sunViewBelt)  * SUN_COLOR_BASE  * stepW;
        dbgMS     += sunFade  * (psi_ms_sun * sigma_s * phaseIsotropic)      * SUN_COLOR_BASE  * stepW;
        dbgSunT   += sunT * stepW;   // raw transmittance (un-faded), diagnostic only
        dbgMoon   += moonFade * (moonT * phaseScatterMoon * moonViewBelt + psi_ms_moon * sigma_s * phaseIsotropic) * MOON_COLOR_BASE * stepW;
#endif

        trans   *= stepT;

        // Saturated-transmittance early-out. For horizon-grazing rays through
        // the dense lower atmosphere, trans drops near zero within a handful
        // of steps; the remaining sparse-tail steps contribute nothing visible
        // but cost the same. Bail so we don't waste the step budget.
        if (max(trans.r, max(trans.g, trans.b)) < 0.001) break;
    }

    // Match legacy GetAtmosphere() tonemap softening so LUT values land in the
    // same range the rest of the pack was already tuned against.
#if   SKY_DEBUG == 10
    return pow(max(dbgSunRay * SKY_DEBUG_GAIN, 0.0), vec3(1.0 / 1.35));
#elif SKY_DEBUG == 11
    return pow(max(dbgSunMie * SKY_DEBUG_GAIN, 0.0), vec3(1.0 / 1.35));
#elif SKY_DEBUG == 12
    return pow(max(dbgMS     * SKY_DEBUG_GAIN, 0.0), vec3(1.0 / 1.35));
#elif SKY_DEBUG == 13
    return pow(max(dbgSunT   * SKY_DEBUG_GAIN, 0.0), vec3(1.0 / 1.35));
#elif SKY_DEBUG == 14
    return pow(max(dbgMoon   * SKY_DEBUG_GAIN, 0.0), vec3(1.0 / 1.35));
#else
    return pow(max(scatter, 0.0), vec3(1.0 / 1.35));
#endif
}


// =============================================================================
// High-level sky API (replaces lib/fragment/sky.glsl::getSky)
// =============================================================================

vec3 _sunDisc_LUT(vec3 rd, vec3 sunDir, vec3 transmittance) {
    const float sunHalfAngle = 0.533333 * pi / 180.0 * 0.5;
    float sunCos = cos(sunHalfAngle);
    float sunViewDot = dot(rd, sunDir);
    float sunDisc = smoothstep(sunCos - 0.0001, sunCos + 0.0001, sunViewDot);
    vec3  discColor = SUN_COLOR_BASE * transmittance * sunDisc * 1000.0;
    return pow(max(discColor, 0.0), vec3(1.0 / 1.2));
}

vec3 _moonDisc_LUT(vec3 rd, vec3 moonDir, vec3 transmittance) {
    const float moonHalfAngle = 0.516667 * pi / 180.0 * 0.5;
    float moonCos = cos(moonHalfAngle);
    float moonViewDot = dot(rd, moonDir);
    float moonDisc = smoothstep(moonCos - 0.0001, moonCos + 0.0001, moonViewDot);
    vec3  discColor = MOON_COLOR_BASE * transmittance * moonDisc * 100.0;
    return pow(max(discColor, 0.0), vec3(1.0 / 1.2));
}

// Aerial perspective: short raymarch from camera to surface, integrating
// in-scattered sun+moon light with extinction. Returns (T, scatter) the caller
// applies as `finalCol = surfaceCol * T + scatter`.
//
// 8 steps is plenty for the distances typical in Minecraft (≤512 blocks). All
// per-step sun visibility comes from the T-LUT (single tap per step). Match the
// pow(1/1.35) softening of the SkyView LUT so scatter+sky live in the same
// tone space (legacy fog.glsl mixed sky and terrain colors the same way).
struct AerialPerspective {
    vec3 transmittance;
    vec3 scatter;
};

AerialPerspective computeAerialPerspective(
    vec3 worldDir,
    vec3 sunDir,
    vec3 moonDir,   // kept in signature for API stability; moon contribution skipped (perf)
    float eyeAltitude,
    float pathLength
) {
    AerialPerspective ap;
    ap.transmittance = vec3(1.0);
    ap.scatter       = vec3(0.0);
    if (pathLength <= 0.0) return ap;

    float r0  = PLANET_RADIUS + max(eyeAltitude, 0.0);
    vec3  pos = vec3(0.0, r0, 0.0);

    const int N = 8;
    float ds = pathLength / float(N);

    vec2 phaseSun = GetPhase(dot(worldDir, sunDir), MIE_G);

    vec3 trans   = vec3(1.0);
    vec3 scatter = vec3(0.0);

    float sunFade = smoothstep(-0.2, 0.05, sunDir.y);

    for (int i = 0; i < N; ++i) {
        float t        = (float(i) + 0.5) * ds;
        vec3  p_t      = pos + worldDir * t;
        float altitude = length(p_t);
        vec3  density  = GetAtmosphereDensity(altitude);

        vec3 sigma_s_r = COEFF_RAYLEIGH * density.x;
        vec3 sigma_s_m = COEFF_MIE * density.y;
        vec3 sigma_s   = sigma_s_r + sigma_s_m;
        vec3 sigma_e   = sigma_s + COEFF_OZONE * density.z;

        vec3  upAtP = normalize(p_t);
        float mu_s  = dot(upAtP, sunDir);
        // Single-tap T-LUT (averaged across 8 steps — quantization invisible).
        // Moon contribution dropped — nighttime AP is dominated by the
        // moon-illuminated sky-view LUT already applied at depth==1.
        vec3  sunT  = sampleTransmittanceLUT_fast(mu_s, altitude);

        vec3  psi_ms_sun = sampleMultiScatterLUT_fast(mu_s, altitude);

        const float phaseIsotropic = 1.0 / (4.0 * pi);
        vec3 phaseScatterSun = sigma_s_r * phaseSun.x + sigma_s_m * phaseSun.y;
        vec3 inscatter = (sunT * phaseScatterSun + psi_ms_sun * sigma_s * (phaseIsotropic * sunFade)) * SUN_COLOR_BASE;

        vec3 stepT = exp(-sigma_e * ds);
        vec3 inscatterStep = trans * inscatter * (1.0 - stepT) / max(sigma_e, vec3(1e-7));
        scatter += inscatterStep;
        trans   *= stepT;
    }

    ap.transmittance = trans;
    ap.scatter       = pow(max(scatter, 0.0), vec3(1.0 / 1.35));
    return ap;
}


// Ambient sky radiance for the GI sky probe. Single straight-up SkyView-LUT tap.
// (Previously tilted the sample 0.15 toward the sun, but a single directional
// tap standing in for a hemisphere integral then CHASES the sun: as the sun
// descends from noon the sample slid into the bright, warm circum-solar sky, so
// the GI/cloud/fog ambient brightened and warmed at mid sun elevations. Sampling
// straight up keeps the ambient stable across the day; intentional warmth comes
// from GI_SKY_WARMTH in d0_restir.)
vec3 getSkyAmbient(float eyeAltitude) {
    return textureLod(colortex12, _skyViewLUT_UV(vec3(0.0, 1.0, 0.0)), 0.0).rgb;
}

// Helper to compute the dynamic sun/moon light color inline to avoid circular dependencies
vec3 _computeDynamicLightColor(float sunElevation) {
    float sunUp  = sunElevation;
    float moonUp = -sunElevation;

    float sunActivity  = smoothstep(-0.1, 0.16, sunUp);
    float moonActivity = smoothstep(-0.1, 0.10, moonUp);

    vec3 sunColorBase  = mix(vec3(1.0, 0.65, 0.35) * 0.15, vec3(1.0, 1.0, 1.1), max(sunUp, 0.0));
    vec3 sunColor      = sunColorBase * sunActivity;

    vec3 moonColorBase = vec3(0.65, 0.85, 1.0) * 0.02;
    vec3 moonColor     = moonColorBase * moonActivity;

    return sunColor + moonColor;
}

// LUT-backed replacement for lib/fragment/sky.glsl::getSky.
// Drop-in equivalent contract: returns sky radiance (scattering + sun/moon
// disc with extinction). The horizon-clamp + ground-blend used by the legacy
// path is replaced by the LUT's built-in sub-horizon handling.
vec3 sampleSky(vec3 rd, vec3 sunDir, vec3 moonDir, float eyeAltitude) {
#if SKY_DEBUG == 1 || SKY_DEBUG >= 10
    // Modes 1 and 10-14: raw LUT (bilinear). For 10-14 the build already wrote
    // the isolated term into the LUT, so this just shows it without post terms.
    return sampleSkyViewLUT(rd, eyeAltitude);
#elif SKY_DEBUG == 2
    return _nearestSkyViewLUT(rd);
#elif SKY_DEBUG == 3
    return _skyViewGridOverlay(rd, eyeAltitude);
#else
    // Sky scattering from the lat/long-warped sky-view LUT.
    vec3 skyColor = sampleSkyViewLUT(rd, eyeAltitude);

    // Offset the sky view LUT color with a portion of the dynamic direct lightColor
    vec3 dynamicLightCol = _computeDynamicLightColor(sunDir.y);
    float sunZenith = clamp(sunDir.y, 0.0, 1.0);
    skyColor += dynamicLightCol * 0.20 * (1.0 - sunZenith * 0.7);

    // Sun/moon discs (extinction along view ray to TOA). Bilinear T-LUT here:
    // the disc covers only ~50 pixels on screen and an incorrect single-tap T
    // at edge texels can clamp the disc color to ~0. Cost: 3 extra fetches
    // per sky pixel = trivial since sky is ~30% of screen.
    if (rd.y > 0.0) {
        float r0  = PLANET_RADIUS + max(eyeAltitude, 0.0);
        float mu0 = clamp(rd.y, -1.0, 1.0);
        vec3  T   = sampleTransmittanceLUT(mu0, r0);
        skyColor += _sunDisc_LUT(rd, sunDir, T);
        skyColor += _moonDisc_LUT(rd, moonDir, T);
    }

    // Match legacy noon-ground blend so the world below horizon is bright,
    // not black. The LUT covers below-horizon directions but tonemap
    // expectations downstream want this kick.
    vec3 horizonColor = skyColor;
    vec3 noonGround = vec3(0.9, 0.95, 1.0) * sunZenith;
    vec3 groundColor = mix(horizonColor * 0.4, noonGround, pow(sunZenith, 2.0));
    float horizon = smoothstep(-0.6, 0.05, rd.y);
    return mix(groundColor, skyColor, horizon);
#endif
}

// Ultra-fast sky sampler for reflections (water, glass, ice).
// Uses manual bilinear SkyView LUT filtering to completely avoid concentric nearest-neighbor
// banding rings, but skips sun/moon disc rendering (since specularity is computed
// separately via microfacet BRDF anyway). Cuts texture fetches from 8 -> 4 per pixel.
vec3 sampleSky_fast(vec3 rd, float eyeAltitude) {
    // Bilinear SkyView LUT fetch - completely smooth gradients on waves
    vec3 skyColor = sampleSkyViewLUT(rd, eyeAltitude);

    // Offset the sky view LUT color with a portion of the dynamic direct lightColor for reflections
    vec3 worldSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    vec3 dynamicLightCol = _computeDynamicLightColor(worldSunDir.y);
    float sunZenith  = clamp(worldSunDir.y, 0.0, 1.0);
    skyColor += dynamicLightCol * 0.20 * (1.0 - sunZenith * 0.7);

    // Fast sub-horizon ground blend
    vec3 horizonColor = skyColor;
    vec3 noonGround = vec3(0.9, 0.95, 1.0) * sunZenith;
    vec3 groundColor = mix(horizonColor * 0.4, noonGround, pow(sunZenith, 2.0));
    float horizon = smoothstep(-0.6, 0.05, rd.y);
    return mix(groundColor, skyColor, horizon);
}

#endif
