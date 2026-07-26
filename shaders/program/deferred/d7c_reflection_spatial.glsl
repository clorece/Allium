// d7c_reflection_spatial : spatial denoise for the metal reflections.
// Runs after d7b (which wrote the temporally-accumulated reflection + history
// length to colortex4 and composited it into colortex0). A history-driven
// bilateral blur: where the reflection temporal history is SHORT (disocclusion /
// camera motion) the kernel widens to hide the per-frame ray noise; where it has
// converged (standing still) the radius collapses to ~0 so the reflection stays
// sharp. Edge-stopping by normal + depth.

#ifdef VERTEX

#include "/lib/options.glsl"

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;
    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"
#include "/lib/util/common.glsl"
#include "/lib/util/dither.glsl"

vec3 clipSpace; // for positions.glsl (unused); must precede the include
#include "/lib/util/positions.glsl"
#include "/lib/fragment/pbrCommon.glsl"
#include "/lib/fragment/directSpecular.glsl"

in vec2 texCoord;

void main() {
    vec2 uv = texCoord;
    vec3 scene = texture(colortex0, uv * renderScale).rgb; // = the lit diffuse (d7b left it)

    /* RENDERTARGETS: 0 */

    float depth = texture(depthtex0, uv * renderScale).r;
    vec4  mat   = texture(colortex7, uv * renderScale);

    // Non-PBR / sky / debug: leave colortex0 (d7b's output) untouched.
#if PBR_DEBUG != 0
    gl_FragData[0] = vec4(scene, 1.0); return;
#endif
    if (depth >= 1.0 || !pbrIsPBR(mat.a) || pbrSmoothness(mat.a) < REFLECTION_SMOOTHNESS_MIN) {
        gl_FragData[0] = vec4(scene, 1.0); return; // matches d7b's cutoff
    }

#ifndef REFLECTION_DENOISE
    gl_FragData[0] = vec4(scene, 1.0); return; // d7b already composited (no temporal/spatial)
#else
    vec4  c4         = texture(colortex4, uv * renderScale);
    vec3  centerRefl = c4.rgb; // DEMODULATED env reflection (no tint)
    float histLen    = c4.a;

    bool  isMetal    = pbrIsMetal(mat.a);
    float smoothness = pbrSmoothness(mat.a);
    float roughness  = 1.0 - smoothness;

    vec3  N = normalize(texture(colortex1, uv * renderScale).rgb * 2.0 - 1.0);
    vec3  viewPos = convertScreenSpaceToWorldSpace(uv, depth);
    float NoV  = clamp(dot(N, normalize(-viewPos)), 1e-3, 1.0);

    // Sun visibility from d7_composite (colortex6): real filtered PCSS +
    // screen-space contact + cloud + sky-access shadow. Dims reflections in shadow
    // / caves (reflShade, with a floor) and shadows the glint.
    float sunVis    = clamp(texture(colortex6, uv * renderScale).r, 0.0, 1.0);
    float reflShade = 1.0 - PBR_REFLECT_SHADE * (1.0 - sunVis);

    // Sharp per-texel Fresnel, computed at full res and applied AFTER the blur.
    // Metal: F0 = albedo (tints + replaces). Dielectric: F0 = grey scalar (adds).
    // reflShade dims the env reflection in shadow / low sky-access.
    vec3 F = (isMetal ? pbrFresnel(NoV, mat.rgb) : pbrFresnel(NoV, vec3(mat.r))) * reflShade;

    // Direct sun/moon glint, added on top of the reflection composite (sharp,
    // deterministic — not denoised). Shadowed by the real sun visibility so it
    // never overpowers the screen-space shadows or reveals the raw shadow map.
    vec3 specSun = vec3(0.0);
    #if SPECULAR_SUN == 1
        specSun = sunMoonSpecular(N, normalize(-viewPos), viewPos, roughness, isMetal ? mat.rgb : vec3(mat.r), sunVis)
                * (isMetal ? 1.0 : PBR_DIELECTRIC_SUN); // non-metals: stronger sun glint
    #endif

    // Metals: full env reflection. Non-metals: weak env (less sky wash) + boosted glint.
    #define REFL_COMPOSE(env) ((isMetal ? (env) * F : scene + (env) * F) + specSun)

    // Radius: full when fresh (few frames of history), ~0 when converged.
    float conv   = clamp(histLen / 8.0, 0.0, 1.0);
    float radius = mix(REFLECTION_SPATIAL_RADIUS, 0.0, conv) * (0.4 + 0.6 * roughness);

    if (radius < 0.6) {
        gl_FragData[0] = vec4(REFL_COMPOSE(centerRefl), 1.0); return; // converged -> sharp
    }

    vec2  viewSize = vec2(viewWidth, viewHeight) * renderScale;
    float rot = interleavedGradientNoise(gl_FragCoord.xy, frameCounter) * 6.2831853;
    mat2  rm  = mat2(cos(rot), -sin(rot), sin(rot), cos(rot));

    vec3  sum  = centerRefl;
    float wsum = 1.0;
    float centerLuma = dot(centerRefl, vec3(0.2126, 0.7152, 0.0722));

    const int TAPS = 12;
    for (int i = 0; i < TAPS; i++) {
        float fi = (float(i) + 0.5) / float(TAPS);
        float r  = sqrt(fi) * radius;                 // disk, denser center
        float a  = fi * 6.2831853 * 3.0;              // ~3 turns
        vec2  suv = uv + (rm * vec2(cos(a), sin(a)) * r) / viewSize;
        if (clamp(suv, 0.0, 1.0) != suv) continue;

        if (!pbrIsPBR(texture(colortex7, suv * renderScale).a)) continue; // only blur across PBR
        float sd = texture(depthtex0, suv * renderScale).r;
        if (sd >= 1.0) continue;

        vec3  sRefl = texture(colortex4, suv * renderScale).rgb;
        // Firefly-aware: don't let a much-brighter neighbour (an emissive spike that
        // slipped into ct4 at that pixel) bleed in and smear into a streak.
        // (REFLECTION_SPATIAL_FIREFLY is a compile constant; 0.0 folds this away.)
        if (REFLECTION_SPATIAL_FIREFLY > 0.0 &&
            dot(sRefl, vec3(0.2126, 0.7152, 0.0722)) > centerLuma * REFLECTION_SPATIAL_FIREFLY + 1e-3) continue;

        vec3  sN  = normalize(texture(colortex1, suv * renderScale).rgb * 2.0 - 1.0);
        vec3  sVP = convertScreenSpaceToWorldSpace(suv, sd);

        float wN = pow(max(dot(N, sN), 0.0), 32.0);                 // normal edge-stop
        float wD = exp(-abs(sVP.z - viewPos.z) * 4.0);              // depth edge-stop
        float w  = wN * wD;

        sum  += sRefl * w;
        wsum += w;
    }

    // Blurred env reflection, then sharp per-texel composite (texture stays crisp).
    gl_FragData[0] = vec4(REFL_COMPOSE(sum / wsum), 1.0);
#endif
}

#endif
