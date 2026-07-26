// d8_fog_sky : atmosphere — applied AFTER the path-tracing chain
// Replaces sky pixels with the procedural sky and (optionally) applies fog to
// the composited scene colour. Runs last in the deferred stage so the GI/denoise
// passes operate on geometry only and never have to fight the sky.

#ifdef VERTEX

#include "/lib/options.glsl"

out vec2 texCoord;
out vec3 lightColor;
out vec3 ambientColor;
out vec3 lightVector;
out vec3 upVector;
out vec3 sunVector;
out vec3 moonVector;


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
#include "/lib/util/time.glsl"

const int gcolorFormat	= RGBA16F;

in vec2 texCoord;
in vec3 lightColor;
in vec3 ambientColor;
in vec3 lightVector;
in vec3 upVector;
in vec3 sunVector;
in vec3 moonVector;


float depth0 = texture(depthtex0, texCoord * renderScale).x;

#include "/lib/dh/dh.glsl"

vec3 clipSpace;

#include "/lib/util/positions.glsl"
#include "/lib/fragment/sky.glsl"
#include "/lib/fragment/clouds.glsl"

void main() {
    vec2 unjitteredTexCoord = texCoord;
    #ifdef TAA
    unjitteredTexCoord -= getTaaJitter() / vec2(viewWidth, viewHeight);
    #endif
    clipSpace = vec3(unjitteredTexCoord, depth0) * 2.0 - 1.0;

    vec3 color = texture(colortex0, texCoord * renderScale).rgb;


	vec3 fragPosition = getFragPosition().xyz;
    vec3 viewDir = normalize(fragPosition);
    vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;

    vec3 worldSunDir = mat3(gbufferModelViewInverse) * sunVector;
    vec3 worldMoonDir = mat3(gbufferModelViewInverse) * moonVector;

    // Assume sea level is at Y=64
    float eyeAltitude = cameraPosition.y - 64.0;

    float dist = length(fragPosition);

    // Distant Horizons: a vanilla-sky pixel that has DH LOD terrain behind it is
    // NOT sky — dh_terrain/dh_water already shaded it into colortex0. Treat it as
    // distant geometry (aerial perspective) instead of overwriting it with sky.
    bool vanillaSky = isVanillaSkyDepth(depth0);
    bool isDH = false;
    #ifdef DISTANT_HORIZONS
    float dhDepth = 1.0;
    if (vanillaSky) {
        dhDepth = dhSampleDepth(texCoord * renderScale);
        float dhFlag = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0).b;
        isDH = isDhDepthValue(dhDepth) && isDhTerrainFlag(dhFlag);
    }
    #endif

    if (vanillaSky && !isDH) {
        color = getSky(worldDir, worldSunDir, worldMoonDir, eyeAltitude);

        #if defined CLOUDS || defined CLOUDS_ALTO

        float cloudMidAlt = (CLOUDS_LAYER_BOTTOM + CLOUDS_LAYER_TOP) * 0.5;
        vec3  ambient     = getSkyAmbient(cloudMidAlt);

        TimeState t = getTimeState();

        // Clouds can only cone-march one directional light. During twilight the
        // old path combined sun+moon colour, then attached it to activeLightDir,
        // whose fixed world-time switch could put the lingering red sunlight on
        // the opposite (moon) side of the sky. Select one coherent direction /
        // colour pair instead. The sun remains dominant through golden hour, so
        // its warm dawn/dusk glow is preserved in the physically correct place.
        float sunLum  = dot(t.sunColor,  vec3(0.2126, 0.7152, 0.0722));
        float moonLum = dot(t.moonColor, vec3(0.2126, 0.7152, 0.0722));
        bool  useSun  = sunLum >= moonLum;
        vec3  lightDir = useSun ? worldSunDir : worldMoonDir;
        vec3  lightCol = (useSun ? t.sunColor : t.moonColor)
                       * (SUN_ILLUMINANCE * 1.5);

        // Intensify the warm cloud glow only while the sun is near the horizon.
        // The channel-weighted boost makes it richer/redder as well as brighter;
        // it fades out by ordinary daytime and never tints moon-lit clouds.
        float cloudSunsetGlow = useSun
                             ? 1.0 - smoothstep(0.0, 0.35, abs(t.sunUp))
                             : 0.0;
        lightCol *= mix(vec3(1.0), vec3(2.0, 1.75, 1.10), cloudSunsetGlow);

        // Cumulus is the dominant FRONT layer; altocumulus is the high backdrop.
        // Compose sky → altocumulus → cumulus, but GATE the altocumulus by the
        // cumulus's raw (un-AP-inflated) opacity so opaque cumulus bodies fully
        // hide it — otherwise the AP-softened cumulus alpha let the bright alto
        // bleed through even solid cores.
        float cloudOcc = 1.0;   // 1 = no cumulus here, 0 = opaque cumulus here
        #ifdef CLOUDS
        vec4 cloud = raymarchClouds(cameraPosition, worldDir, lightDir, lightCol, ambient, cloudOcc);
        #endif

        #ifdef CLOUDS_ALTO
        // `color` here is still the clear sky (cumulus composites after this), so
        // it doubles as the aerial-perspective haze target for the high layer.
        vec4 alto = altocumulus(cameraPosition, worldDir, lightDir, lightCol, ambient, color);
        alto.rgb *= cloudOcc;                       // cumulus erases alto scattering
        alto.a    = mix(1.0, alto.a, cloudOcc);     // …and stops it occluding the sky there
        color = color * alto.a + alto.rgb;
        #endif

        #ifdef CLOUDS
        color = color * cloud.a + cloud.rgb;        // cumulus over everything (AP alpha for sky blend)
        #endif
        #endif
    }
    #ifdef DISTANT_HORIZONS
    else if (isDH) {
        // Flat aerial perspective for DH LODs — but ONLY when volumetric light is
        // off. When VL is on, d9_vl marches these pixels too (using the DH depth)
        // so they get the same shadowed god-ray fog as the near scene; applying
        // both here and there would double the scattering.
        #if defined(DH_FOG) && !defined(VOLUMETRIC_LIGHT)
        vec3  dhViewP    = dhViewPos(unjitteredTexCoord, dhDepth);
        float dhDist     = length(dhViewP);
        vec3  dhWorldDir = mat3(gbufferModelViewInverse) * normalize(dhViewP);

        AerialPerspective ap = computeAerialPerspective(
            dhWorldDir, worldSunDir, worldMoonDir, eyeAltitude, dhDist);
        color = color * ap.transmittance + ap.scatter;
        #endif
    }
    #endif
    #ifndef VOLUMETRIC_LIGHT
    else if (texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0).b <= 0.875) {
        // (Water pixels skipped: the colortex0 here is the submerged seabed, which
        // must not get AIR aerial perspective — c_water applies the water fog.)
        AerialPerspective ap = computeAerialPerspective(
            worldDir, worldSunDir, worldMoonDir, eyeAltitude, dist);
        color = color * ap.transmittance + ap.scatter;
    }
    #endif

    /* RENDERTARGETS: 0 */
    gl_FragData[0] = vec4(color, 1.0);
}

#endif
