// d9_vl : atmospheric volumetric light. Per-pixel shadowmap-aware raymarch
// that replaces d8's flat aerial perspective for terrain pixels when
// VOLUMETRIC_LIGHT is enabled. Sky pixels (depth==1) are passed through —
// d8 already wrote the sky color.
//
// Integration is identical to computeAerialPerspective() except sun in-scatter
// is multiplied by a single shadowmap tap per step. Moon stays unshadowed
// (cheap, MC nights don't need crepuscular rays through clouds).

/* RENDERTARGETS: 0 */

#ifdef VERTEX

#include "/lib/options.glsl"

out vec2 texCoord;
out vec3 sunVector;
out vec3 moonVector;
out vec3 lightVector;
out vec3 upVector;
out vec3 lightColor;
out vec3 ambientColor;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;

    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
    #include "/lib/vectors.glsl"
    #include "/lib/colors.glsl"
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"
#include "/lib/util/common.glsl"
#include "/lib/util/jitter.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/time.glsl"

in vec2 texCoord;
in vec3 sunVector;
in vec3 moonVector;
in vec3 lightVector;
in vec3 upVector;
in vec3 lightColor;

vec3 clipSpace;

#include "/lib/util/positions.glsl"
#include "/lib/fragment/atmosphereLUT.glsl"
#include "/lib/dh/dh.glsl"


void main() {
#ifndef VOLUMETRIC_LIGHT
    gl_FragData[0] = vec4(texture(colortex0, texCoord * renderScale).rgb, 1.0);
    return;
#else
    vec3 sceneColor = texture(colortex0, texCoord * renderScale).rgb;

    vec2 unjit = texCoord;
    #ifdef TAA
    unjit -= getTaaJitter() / vec2(viewWidth, viewHeight);
    #endif

    float depth = texture(depthtex0, unjit * renderScale).r;

    // Distant Horizons: a vanilla-sky pixel with DH LOD terrain behind it gets the SAME
    // volumetric march as near terrain (d8 deliberately skips its flat fog for DH
    // when VL is on). True sky still passes through — d8 already drew it.
    vec3 fragPosition;
    bool vanillaSky = isVanillaSkyDepth(depth);

    #ifdef DISTANT_HORIZONS
    float dhd = 1.0;
    bool  dhGeom = false;
    if (vanillaSky) {
        dhd = dhSampleDepth(unjit * renderScale);
        float dhFlag = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0).b;
        dhGeom = isDhDepthValue(dhd) && isDhTerrainFlag(dhFlag);
    }
    #else
    bool  dhGeom = false;
    #endif

    if (vanillaSky && !dhGeom) {
        // Sky pixel — d8's sampleSky() already handled it.
        gl_FragData[0] = vec4(sceneColor, 1.0);
        return;
    }

    // Water pixels: the colortex0 here is the SEABED (opaque, behind the water
    // surface). It is underwater, so it must NOT get AIR volumetric fog — that
    // washed distant submerged terrain to the bright atmosphere scatter colour
    // (e.g. far seaweed turning solid cyan). c_water applies the WATER fog (depth
    // absorption + in-scatter) and the surface's own atmospheric fog instead.
    if (texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0).b > 0.875) {
        gl_FragData[0] = vec4(sceneColor, 1.0);
        return;
    }

    #ifdef DISTANT_HORIZONS
    if (dhGeom) {
        fragPosition = dhViewPos(unjit, dhd);
    } else
    #endif
    {
        clipSpace = vec3(unjit, depth) * 2.0 - 1.0;
        fragPosition = getFragPosition().xyz;
    }

    vec3  viewDir      = normalize(fragPosition);
    vec3  worldDir     = mat3(gbufferModelViewInverse) * viewDir;
    vec3  worldSunDir  = mat3(gbufferModelViewInverse) * sunVector;

    TimeState t = getTimeState();

    float vlMultiplier = t.timeNoon * VL_NOON_STRENGTH + (t.timeSunrise + t.timeSunset) * VL_SUN_RISE_SET_STRENGTH + t.timeMidnight * VL_NIGHT_STRENGTH;
    vlMultiplier *= t.shadowFade;

    if (vlMultiplier < 0.001) {
        gl_FragData[0] = vec4(sceneColor, 1.0);
        return;
    }

    vec3  worldLightDir = mat3(gbufferModelViewInverse) * lightVector;

    if (worldLightDir.y < -0.2) {
        gl_FragData[0] = vec4(sceneColor, 1.0);
        return;
    }

    float dist   = length(fragPosition);
    float eyeAlt = cameraPosition.y - 64.0;

    int   N       = VL_STEPS;
    float stepLen = dist / float(N);
    float dither  = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

    float r0  = PLANET_RADIUS + max(eyeAlt, 0.0);
    vec3  posCenter = vec3(0.0, r0, 0.0);

    vec2 phaseLight = GetPhase(dot(worldDir, worldLightDir), MIE_G);

    vec3 trans   = vec3(1.0);
    vec3 scatter = vec3(0.0);

    float lightFade = t.shadowFade;
    // Use the exact terrain direct-light color; SUN_ILLUMINANCE remains only
    // the medium's exposure scale, not a separate day/night color system.
    vec3 lightColorBase = lightColor * SUN_ILLUMINANCE;

    for (int i = 0; i < N; ++i) {
        float t = (float(i) + dither) * stepLen;

        vec4 shadowPos = toShadowSpace(vec4(worldDir * t, 1.0));
        float shadow = 1.0;
        if (shadowPos.x >= 0.0 && shadowPos.x <= 1.0 &&
            shadowPos.y >= 0.0 && shadowPos.y <= 1.0)
        {
            float receiverDepth = shadowPos.z - 0.0001;
            shadow = step(receiverDepth, texture(shadowtex0, shadowPos.xy).r);
        }
        vec3  p_t      = posCenter + worldDir * t;
        float altitude = length(p_t);
        vec3  density  = GetAtmosphereDensity(altitude);

        vec3 sigma_s_r = COEFF_RAYLEIGH * density.x;
        vec3 sigma_s_m = COEFF_MIE * density.y;
        vec3 sigma_s   = sigma_s_r + sigma_s_m;
        vec3 sigma_e   = sigma_s + COEFF_OZONE * density.z;

        float mu_light = dot(normalize(p_t), worldLightDir);
        vec3  lightT = sampleTransmittanceLUT_fast(mu_light, altitude);

        vec3  psi_ms_light = sampleMultiScatterLUT_fast(mu_light, altitude);

        const float phaseIsotropic = 1.0 / (4.0 * pi);
        const vec3 lumaWeights = vec3(0.2126, 0.7152, 0.0722);

        // Terrain lightColor already carries the elevation-dependent amber ->
        // golden tint. Applying the RGB atmosphere LUT to Mie as well warmed it
        // a second time, producing a mid-elevation red lobe. Mie is effectively
        // achromatic here: retain the LUT's attenuation/energy as luminance and
        // take its chroma from the shared terrain light. Rayleigh remains fully
        // spectral, as does any user-configured wavelength dependence in sigma_s_m.
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

    scatter = pow(max(scatter, 0.0), vec3(1.0 / 1.35));

    vec3 finalColor = sceneColor * trans + scatter * (VL_INTENSITY * vlMultiplier);
    gl_FragData[0] = vec4(finalColor, 1.0);
#endif
}

#endif
