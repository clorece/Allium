#ifndef VL_FOG_GLSL
#define VL_FOG_GLSL

// Shared volumetric-fog integration.
//
// d9_vl applies this to the OPAQUE scene (in the deferred stage, before
// translucents are drawn). c_water applies the SAME function to translucent
// surfaces (glass / ice / portal / water) so they fog identically and don't pop
// out of the volumetric haze. Keeping a single implementation guarantees the
// two stages match — the whole reason transparents previously stuck out is that
// the flat aerial-perspective they got was far weaker than this shadow-aware,
// VL_INTENSITY-scaled scatter.
//
// Math is a verbatim copy of d9_vl's per-step integration; the shadow-space
// transform is inlined (mirrors lib/util/positions.glsl::toShadowSpace) so this
// header has no dependency on the `clipSpace` global that positions.glsl needs.

#include "/lib/options.glsl"
#include "/lib/fragment/atmosphereLUT.glsl"
#include "/lib/util/time.glsl"

struct VolFog {
    vec3 transmittance;
    vec3 scatter;
};

// worldDir : normalized camera->fragment direction (world space)
// dist     : path length camera->fragment (blocks)
// eyeAlt   : camera altitude above sea level (cameraPosition.y - 64.0)
// dither   : [0,1) per-pixel jitter to break up step banding
VolFog computeVolumetricFog(vec3 worldDir, float dist, float eyeAlt, float dither) {
    VolFog vf;
    vf.transmittance = vec3(1.0);
    vf.scatter       = vec3(0.0);

    if (dist <= 0.0) return vf;

    TimeState t = getTimeState();

    float vlMultiplier = t.timeNoon * VL_NOON_STRENGTH
                       + (t.timeSunrise + t.timeSunset) * VL_SUN_RISE_SET_STRENGTH
                       + t.timeMidnight * VL_NIGHT_STRENGTH;
    vlMultiplier *= t.shadowFade;
    if (vlMultiplier < 0.001) return vf;

    vec3 worldLightDir = t.activeLightDir;
    // Light-below-horizon early-out (matches d9_vl).
    if (worldLightDir.y < -0.2) return vf;

    int   N       = VL_STEPS;
    float stepLen = dist / float(N);

    float r0  = PLANET_RADIUS + max(eyeAlt, 0.0);
    vec3  posCenter = vec3(0.0, r0, 0.0);

    vec2 phaseLight = GetPhase(dot(worldDir, worldLightDir), MIE_G);

    vec3 trans   = vec3(1.0);
    vec3 scatter = vec3(0.0);

    float lightFade = t.shadowFade;
    // Same direct-light palette and moon/sun balance as terrain. The physical
    // illuminance multiplier controls fog exposure only.
    vec3  lightColorBase = t.lightColor * SUN_ILLUMINANCE;

    for (int i = 0; i < N; ++i) {
        float ti = (float(i) + dither) * stepLen;

        // Inlined toShadowSpace(vec4(worldDir * ti, 1.0)).
        vec4 shadowPos = shadowProjection * shadowModelView * vec4(worldDir * ti, 1.0);
        shadowPos /= shadowPos.w;
        float distb = length(shadowPos.xy);
        float distortFactor = (1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
        shadowPos.xy /= distortFactor;
        shadowPos = shadowPos * 0.5 + 0.5;

        float shadow = 1.0;
        if (shadowPos.x >= 0.0 && shadowPos.x <= 1.0 &&
            shadowPos.y >= 0.0 && shadowPos.y <= 1.0)
        {
            float receiverDepth = shadowPos.z - 0.0001;
            shadow = step(receiverDepth, texture(shadowtex0, shadowPos.xy).r);
        }

        vec3  p_t      = posCenter + worldDir * ti;
        float altitude = length(p_t);
        vec3  density  = GetAtmosphereDensity(altitude);

        vec3 sigma_s_r = COEFF_RAYLEIGH * density.x;
        vec3 sigma_s_m = COEFF_MIE * density.y;
        vec3 sigma_s   = sigma_s_r + sigma_s_m;
        vec3 sigma_e   = sigma_s + COEFF_OZONE * density.z;

        float mu_light = dot(normalize(p_t), worldLightDir);
        vec3  lightT       = sampleTransmittanceLUT_fast(mu_light, altitude);
        vec3  psi_ms_light = sampleMultiScatterLUT_fast(mu_light, altitude);

        const float phaseIsotropic = 1.0 / (4.0 * pi);
        const vec3 lumaWeights = vec3(0.2126, 0.7152, 0.0722);

        // lightColorBase already contains the terrain elevation tint. Preserve
        // atmospheric LUT energy but neutralize its second chroma tint on Mie;
        // Rayleigh remains wavelength-dependent.
        float mieLightT = dot(lightT, lumaWeights);
        float mieMulti  = dot(psi_ms_light, lumaWeights);
        vec3 directScatter = lightT * (sigma_s_r * 0.02) * phaseLight.x
                           + sigma_s_m * (mieLightT * phaseLight.y);
        vec3 multiScatter  = psi_ms_light * (sigma_s_r * 0.02)
                           + sigma_s_m * mieMulti;
        vec3 inscatter = (directScatter
                       + multiScatter * (phaseIsotropic * lightFade))
                       * lightColorBase * shadow;

        vec3 stepT = exp(-sigma_e * stepLen);
        vec3 inscatterStep = trans * inscatter * (1.0 - stepT) / max(sigma_e, vec3(1e-7));
        scatter += inscatterStep;
        trans   *= stepT;
    }

    // Match SkyView LUT tone space (matches d9_vl).
    scatter = pow(max(scatter, 0.0), vec3(1.0 / 1.35));

    vf.transmittance = trans;
    vf.scatter       = scatter * (VL_INTENSITY * vlMultiplier);
    return vf;
}

#endif
