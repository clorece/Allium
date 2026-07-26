#ifndef DIRECT_SPECULAR_GLSL
#define DIRECT_SPECULAR_GLSL

// Direct sun / moon specular highlight (GGX glint) for the integrated-PBR passes.
// Added ON TOP of the environment reflection, so it works for both metal-replace
// and dielectric-add without touching d7_composite.
//
// The shadow is passed IN (sunShadow) — it is the SAME filtered PCSS + screen-space
// contact + cloud + sky-access term the diffuse sun uses, forwarded from
// d7_composite through colortex14. This replaces the old cheap single shadow-map
// tap, which revealed the raw shadow map (no PCF), ignored the screen-space
// contact shadows, and returned 1.0 outside the shadow frustum — so it lit up
// caves. Requires: /lib/fragment/pbrCommon.glsl (ggxSpecular).

// N, V, viewPos: view space. roughness: perceptual (1 - smoothness). f0: metal
// albedo or dielectric F0. sunShadow: precomputed sun visibility [0,1]. Returns
// the shadowed sun/moon highlight.
vec3 sunMoonSpecular(vec3 N, vec3 V, vec3 viewPos, float roughness, vec3 f0, float sunShadow) {
    if (sunShadow <= 0.0) return vec3(0.0);
    vec3  sunView = normalize(sunPosition);
    vec3  wSun    = mat3(gbufferModelViewInverse) * sunView;
    bool  day     = wSun.y > -0.04;

    vec3  Lview = day ? sunView : -sunView; // active light (sun by day, moon by night)
    float upY   = day ? wSun.y : -wSun.y;
    float horiz = smoothstep(-0.04, 0.08, upY); // fade out across the horizon
    if (horiz <= 0.0) return vec3(0.0);

    // Light colour: warm low sun -> neutral high; cool dim moon.
    vec3 sunCol  = mix(vec3(1.0, 0.55, 0.28), vec3(1.0, 0.96, 0.90), clamp(upY, 0.0, 1.0));
    vec3 moonCol = vec3(0.55, 0.66, 0.95) * 0.05;
    vec3 lightCol = (day ? sunCol : moonCol) * SPECULAR_SUN_STRENGTH * horiz;

    // Cap the roughness used for the GLINT so even matte surfaces (wood, dirt,
    // wool) show a visible soft sun sheen — a roughness-0.9 GGX lobe is too spread
    // to read. The environment reflection still uses the true roughness.
    float gRough = min(roughness, 0.5);
    vec3 spec = ggxSpecular(N, V, Lview, gRough, f0, lightCol);
    if (spec == vec3(0.0)) return spec;
    spec = min(spec, vec3(8.0)); // cap so the glint blooms but doesn't nuke
    return spec * sunShadow;
}

#endif
