// d7b_reflections : opaque integrated-PBR specular reflections (v2, metals first).
// Runs after d7_composite (lit scene in colortex0) and before d8_fog_sky.
//
// Reads the persistent PBR material from colortex7 (.rgb metal albedo/F0, .a
// smoothness). For metal pixels it fires VNDF importance-sampled rays, marches
// the depth buffer, and reflects the PREVIOUS frame (colortex5) reprojected to
// the hit point — a clean, already-denoised source. Misses fall
// back to the room GI ambient blended to sky by a steep skylight gate, so indoor
// metals reflect the room, not the sky. Metals have no diffuse: the surface IS
// the albedo-tinted reflection. Non-metal pixels pass through untouched.

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
#include "/lib/util/jitter.glsl"

vec3 clipSpace; // referenced by positions.glsl (unused here); must precede the include

#include "/lib/util/positions.glsl"
#include "/lib/fragment/sky.glsl"
#include "/lib/fragment/reflections.glsl"
#include "/lib/fragment/pbrCommon.glsl"
#include "/lib/fragment/directSpecular.glsl"
#include "/lib/pt/rand.glsl"

in vec2 texCoord;

vec3 viewToWorldRel(vec3 viewPos) {
    return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz; // camera-relative world
}

void main() {
    vec2 uv = texCoord;
    vec3 color = texture(colortex0, uv * renderScale).rgb;

    /* RENDERTARGETS: 0,4 */

    vec4  mat        = texture(colortex7, uv * renderScale);
    float smoothness = pbrSmoothness(mat.a);
    bool  isMetal    = pbrIsMetal(mat.a);
    vec3  tintCol    = mat.rgb; // metal albedo(F0), or dielectric F0 (grey)

    #if PBR_DEBUG == 1
        gl_FragData[0] = vec4(vec3(pbrIsPBR(mat.a) ? smoothness : 0.0), 1.0); gl_FragData[1] = vec4(0.0); return;
    #elif PBR_DEBUG == 2
        gl_FragData[0] = vec4(pbrIsPBR(mat.a) ? tintCol : vec3(0.0), 1.0); gl_FragData[1] = vec4(0.0); return;
    #endif

    float depth = texture(depthtex0, uv * renderScale).r;

    // Only PBR pixels that are smooth enough to show a reflection do work
    // (REFLECTION_SMOOTHNESS_MIN doubles as the perf cutoff: raise it to skip the
    // matte families — dirt/wood/wool/rough-stone — when full parity is too heavy).
    if (depth >= 1.0 || !pbrIsPBR(mat.a) || smoothness < REFLECTION_SMOOTHNESS_MIN) {
        gl_FragData[0] = vec4(color, 1.0);
        gl_FragData[1] = vec4(0.0); // reset reflection history
        return;
    }

    vec2 unjit = uv;
    #ifdef TAA
        unjit -= getTaaJitter() / vec2(viewWidth, viewHeight);
    #endif

    vec3 viewPos = convertScreenSpaceToWorldSpace(unjit, depth); // view space
    vec3 N = normalize(texture(colortex1, uv * renderScale).rgb * 2.0 - 1.0);
    vec3 V = normalize(-viewPos);  // surface -> camera
    vec3 I = normalize(viewPos);   // camera -> surface

    float roughness = 1.0 - smoothness;
    float alpha     = max(roughness * roughness, 1e-4);
    float alphaSq   = alpha * alpha;
    float NoV       = clamp(dot(N, V), 1e-3, 1.0);

    // Steep skylight gate: indoor metals reflect ambient, not sky.
    float skylight = clamp(texture(colortex2, uv * renderScale).g, 0.0, 1.0);
    float skyGate  = pow(clamp(skylight / 0.75, 0.0, 1.0), REFLECTION_SKY_FADE);

    // Sun visibility from d7_composite (colortex6): the real filtered PCSS +
    // screen-space contact + cloud + sky-access shadow. Used to shadow the sun
    // glint and to dim reflections in shadow / dim areas (caves) — combats the
    // unnatural shine without a raw shadow-map tap. reflShade keeps a floor so
    // shadowed surfaces still reflect, just dimmer.
    float sunVis    = clamp(texture(colortex6, uv * renderScale).r, 0.0, 1.0);
    float reflShade = 1.0 - PBR_REFLECT_SHADE * (1.0 - sunVis);

    // Room ambient (this surface's indirect GI) for missed rays / no sky access.
    vec3 giAmbient = vec3(0.0);
    #if defined(VOXEL_GI)
        giAmbient = texture(colortex8, unjit * renderScale).rgb; // accumulated per-pixel GI
    #endif

    float eyeAltitude = cameraPosition.y - 64.0;
    mat3  tbn  = tbnFromNormal(N);
    vec3  Vt   = V * tbn; // view dir in tangent space

    vec3  reflection = vec3(0.0);
    float reflWsum   = 0.0;
    uint  seed = pixelSeed(ivec2(gl_FragCoord.xy), frameCounter);

    for (int s = 0; s < REFLECTION_RAYS; s++) {
        vec2 hash = vec2(randFloat(seed), randFloat(seed));
        vec3 Ht   = sampleGGXVNDF(Vt, alpha, hash);
        vec3 H    = tbn * Ht;                 // microfacet normal, view space
        vec3 rdir = reflect(I, H);            // reflected ray, view space

        float NoL = dot(N, rdir);
        if (NoL <= 1e-3) continue;

        // Environment for this ray: GI ambient indoors -> sky outdoors.
        vec3 worldRdir = mat3(gbufferModelViewInverse) * rdir;
        // Sky reflection: globally scaled, and reduced further for non-metals so
        // dielectrics keep their (F0-driven) scene reflection without the sky wash.
        float skyMul   = REFLECTION_SKY_STRENGTH * (isMetal ? 1.0 : PBR_DIELECTRIC_REFLECT);
        vec3 radiance  = mix(giAmbient, getSkyReflection(worldRdir, eyeAltitude) * skyMul, skyGate);

        #ifdef SPECULAR_REFLECTIONS
        {
            vec2 hitUV;
            if (traceReflectionSSR(viewPos + N * 0.05, rdir, randFloat(seed), hitUV)) {
                // Reconstruct the hit, reproject into last frame, sample colortex5
                // (previous full-res HDR scene — already clean / temporally stable).
                float hitDepth = texture(depthtex1, hitUV * renderScale).r;
                vec3  hitWorldRel = viewToWorldRel(convertScreenSpaceToWorldSpace(hitUV, hitDepth));
                vec3  prevRel = hitWorldRel + (cameraPosition - previousCameraPosition);
                vec4  clipPrev = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevRel, 1.0));
                vec2  prevUV = (clipPrev.xy / clipPrev.w) * 0.5 + 0.5;
                if (clamp(prevUV, 0.0, 1.0) == prevUV) {
                    radiance = texture(colortex5, prevUV).rgb; // colortex5 is FULL-RES (no renderScale)
                }
            }
        }
        #endif

        // Hard ceiling: catches pathological HDR spikes (the sun disc in colortex5).
        radiance = min(radiance, vec3(REFLECTION_FIREFLY_CLAMP));

        // DEMODULATED: accumulate the environment reflection WITHOUT the metal
        // albedo tint (just the VNDF geometry weight). The per-texel albedo tint
        // (= the block texture) is re-applied sharp at composite, AFTER the temporal
        // + spatial denoise — so blurring the reflection never smears the texture.
        // The weight = G2/G1 (height-correlated Smith), bounded <=1; F is the tint.
        float v1 = smithGGX_v1(NoV, alphaSq);
        float v2 = smithGGX_v2(NoL, NoV, alphaSq);
        vec3  sampleRefl = radiance * (2.0 * NoL * v2 / max(v1, 1e-6));

        // Karis firefly-free averaging: weight each ray by inverse luma so a single
        // ray that catches a bright emissive texel (lava/torch/glowstone — these are
        // pre-exposure amplified, so they spike hard) can't dominate the mean as a
        // sparkle. Self-correcting: on smooth/coherent surfaces every ray hits the
        // same thing → equal weights → no dimming of a legit bright reflection; only
        // on rough surfaces, where rays diverge, is the lone outlier suppressed.
        float w = 1.0 / (1.0 + dot(sampleRefl, vec3(0.2126, 0.7152, 0.0722)) * REFLECTION_FIREFLY_WEIGHT);
        reflection += sampleRefl * w;
        reflWsum   += w;
    }
    reflection /= max(reflWsum, 1e-6);
    if (any(isnan(reflection))) reflection = vec3(0.0);

    // --- Temporal accumulation (reflection denoise) ---------------------------
    // The stochastic VNDF rays are noisy per frame; blend the reflection across
    // frames in colortex4, reprojecting this surface by camera motion (mirrors the
    // GI accum in d0_accum). This is what removes the ray noise.
    float histLenOut = 1.0;
    #ifdef REFLECTION_DENOISE
    {
        vec3 worldRel     = viewToWorldRel(viewPos);
        vec3 worldPrevRel = worldRel + (cameraPosition - previousCameraPosition);
        vec4 clipPrev = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(worldPrevRel, 1.0));
        vec2 uvPrev   = (clipPrev.xy / clipPrev.w) * 0.5 + 0.5;

        float histLen = 0.0;
        vec3  histRefl = reflection;
        vec2  pad = 1.5 / vec2(viewWidth, viewHeight);
        if (all(greaterThanEqual(uvPrev, pad)) && all(lessThan(uvPrev, 1.0 - pad))) {
            // Disocclusion: surface now at uvPrev must match this one.
            float dPrev = texture(depthtex0, uvPrev * renderScale).r;
            if (dPrev < 1.0) {
                vec3 prevWorldRel = viewToWorldRel(convertScreenSpaceToWorldSpace(uvPrev, dPrev));
                if (distance(prevWorldRel, worldRel) < 0.05 * length(viewPos) + 0.25) {
                    vec4 h = texture(colortex4, uvPrev * renderScale);
                    histRefl = h.rgb;
                    histLen  = h.a;
                }
            }
        }

        // Reflections are view-dependent, so the reflected content changes as the
        // view changes even when the surface reprojects perfectly — accumulating
        // stale reflections is what smears. Reject history by how far this surface
        // moved ON SCREEN (captures camera ROTATION + translation parallax, which a
        // world-position delta misses). Smoother (more mirror-like) reflections are
        // more view-dependent, so reject harder for them.
        float velPx = length((uvPrev - unjit) * vec2(viewWidth, viewHeight));
        float reject = smoothstep(2.0, mix(16.0, 7.0, smoothness), velPx);
        histLen *= 1.0 - reject;

        histLen    = min(histLen + 1.0, float(REFLECTION_ACCUM_FRAMES));
        reflection = mix(histRefl, reflection, 1.0 / histLen);
        histLenOut = histLen;
    }
    #endif

    #if PBR_DEBUG == 3
        gl_FragData[0] = vec4(vec3(skyGate), 1.0); gl_FragData[1] = vec4(reflection, histLenOut); return;
    #elif PBR_DEBUG == 4
        gl_FragData[0] = vec4(reflection, 1.0); gl_FragData[1] = vec4(reflection, histLenOut); return;
    #endif

    // colortex4 stores the DEMODULATED env reflection (no tint) for d7c to blur.
    #ifdef REFLECTION_DENOISE
        // Denoise on: d7c composites after the spatial blur — leave the lit scene
        // (the diffuse) here so d7c can add/replace correctly.
        gl_FragData[0] = vec4(color, 1.0);
    #else
        // Denoise off: composite immediately, sharp tint over the demodulated env.
        // Metal -> no diffuse, surface IS the albedo-tinted reflection.
        // Dielectric -> keep diffuse, ADD a weak untinted Fresnel reflection.
        // Metals: full env reflection. Non-metals: weak env (less sky wash).
        // reflShade dims the env reflection in shadow / low sky-access.
        vec3 env = reflection * reflShade;
        vec3 outColor = isMetal
            ? env * pbrFresnel(NoV, tintCol)
            : color + env * pbrFresnel(NoV, vec3(tintCol.r));
        #if SPECULAR_SUN == 1
            // Non-metals: boosted sun glint (strong highlight, little sky). Shadowed
            // by the real sun visibility so it never overpowers the screen-space shadows.
            outColor += sunMoonSpecular(N, V, viewPos, roughness, isMetal ? tintCol : vec3(tintCol.r), sunVis)
                      * (isMetal ? 1.0 : PBR_DIELECTRIC_SUN);
        #endif
        gl_FragData[0] = vec4(outColor, 1.0);
    #endif
    gl_FragData[1] = vec4(reflection, histLenOut); // colortex4: untinted env reflection + history
}

#endif
