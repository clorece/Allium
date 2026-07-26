// d0_sspt : screen-space path-traced GI producer (Phase 2)
//
// Runs at deferred1 (before the SVGF chain, before d7_composite). Per opaque
// pixel it fires SSPT_SAMPLES cosine-weighted hemisphere rays and marches them
// through the opaque depth buffer (depthtex1). A HIT reads the previous frame's
// lit radiance (colortex5, full-res) — which already contains last frame's
// indirect, so temporal feedback gives near-free multibounce. A MISS is sky. The
// gather is split into three independently-scaled terms — GI (SSPT_GI_STRENGTH:
// bounce+emissive hits), skylight (SSPT_SKY_STRENGTH: sky-miss ambient), and AO
// (SSPT_AO_STRENGTH: openness^n contrast on the skylight) — baked here, so d7 uses
// the result directly (NOT the rasterized LIGHTING_INDIRECT). Cosine-importance
// sampling makes the per-term estimator a plain mean of incoming radiance (the cos/π
// pdf cancels the Lambertian cosine), so d7's `albedo * indirect` stays consistent.
//
// Writes GI to colortex8 (.rgb) + history length (.a), and the linear-depth reproject
// key to colortex9.r. When SSPT_ACCUM is on it temporally accumulates a reprojected
// running average in place (first stage of the denoiser pipeline); the temporal +
// spatial filters are a later phase. SVGF (GI_DENOISE) stays off.

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

// positions.glsl's getFragPosition()/getWorldPosition() reference a free global
// `clipSpace` (declared per-TU, as in d7_composite). We only call the standalone
// convertScreenSpaceToWorldSpace(), but the others still compile — so declare it.
vec3 clipSpace;
#include "/lib/util/positions.glsl"
#include "/lib/fragment/sky.glsl"
#include "/lib/pt/sspt.glsl"

in vec2 texCoord;
in vec3 lightColor;
in vec3 ambientColor;
in vec3 lightVector;
in vec3 upVector;
in vec3 sunVector;
in vec3 moonVector;

void main() {
    /* RENDERTARGETS: 8,9,15 */

    float depth1 = texture(depthtex1, texCoord * renderScale).r;
    if (depth1 >= 1.0) {           // sky pixel: no GI producer here
        gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
        gl_FragData[1] = vec4(1e5, 0.0, 0.0, 1.0); // far reproject key (never matches, flushes history)
        gl_FragData[2] = vec4(0.0, 0.0, 1e5, 0.0); // colortex15: linDepth=far so the SVGF chain skips sky
        return;
    }

    // Jitter delta: geometry/depth are stored jittered, gbufferProjection is not.
    vec2 cj    = getTaaJitter() / vec2(viewWidth, viewHeight);
    vec2 unjit = texCoord - cj;

    vec3 viewPos  = convertScreenSpaceToWorldSpace(unjit, depth1); // view space
    vec3 normal   = normalize(texture(colortex1, texCoord * renderScale).rgb * 2.0 - 1.0);
    float skyAccess = clamp(texture(colortex2, texCoord * renderScale).g, 0.0, 1.0);

    // Origin bias off the surface to avoid self-shadow acne. Kept small + distance-
    // scaled: too large lifts the ray over the base of nearby occluders and the shadow
    // detaches from the contact (peter-panning). Raise SSPT_BIAS only if acne appears.
    float originBias = SSPT_BIAS * (1.0 + (-viewPos.z) * 0.05);
    vec3  originV = viewPos + normal * originBias;

    // Sky radiance warmed like the DH ambient (used on ray misses).
    vec3 skyWarm = mix(vec3(1.0), vec3(1.25, 1.04, 0.72), GI_SKY_WARMTH);

    uint  seed   = pixelSeed(ivec2(gl_FragCoord.xy), frameCounter);
    vec3  hitAcc = vec3(0.0); // colored surface bounce + emissive (ray hits)
    vec3  skyAcc = vec3(0.0); // raw sky radiance summed over the miss directions
    int   misses = 0;

    for (int s = 0; s < SSPT_SAMPLES; s++) {
        #ifdef SSPT_BLUE_NOISE
            // Walk the STBN sequence per sample+frame so multi-spp stays decorrelated.
            vec3 dir = sspt_stbnHemisphere(normal, ivec2(gl_FragCoord.xy),
                                           frameCounter * SSPT_SAMPLES + s);
        #else
            vec3 dir = sspt_dbgHemisphere(normal, randFloat(seed), randFloat(seed));
        #endif

        vec2 uvh; float rawh;
        if (traceScreenSpace(depthtex1, gbufferProjection, originV, dir,
                             float(SSPT_DIST), SSPT_STEPS, SSPT_THICKNESS,
                             randFloat(seed), cj, uvh, rawh)) {
            // On-screen bounce. colortex5 is LAST frame's scene, so reproject the hit
            // (a static world point) into the previous camera to kill smear/lag when
            // the camera moves. rawh is the hit's window depth from the marcher.
            vec3 hitView = convertScreenSpaceToWorldSpace(uvh, rawh);
            vec3 hitRel  = (gbufferModelViewInverse * vec4(hitView, 1.0)).xyz;
            vec3 prevRel = hitRel + (cameraPosition - previousCameraPosition);
            vec4 clipP   = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevRel, 1.0));
            vec2 prevUV  = (clipP.xy / clipP.w) * 0.5 + 0.5;
            // If the hit was off-screen last frame, fall back to the current-frame tap.
            vec2 radUV   = (clamp(prevUV, 0.0, 1.0) == prevUV) ? prevUV : (uvh + cj);
            hitAcc += texture(colortex5, radUV).rgb;
        } else {
            // Ray reached the sky (or ran off-screen): raw sky radiance in that dir.
            vec3 worldDir = mat3(gbufferModelViewInverse) * dir;
            skyAcc += getSkyReflection(worldDir, cameraPosition.y - 64.0) * skyWarm;
            misses++;
        }
    }

    // --- Three independent SSPT terms -----------------------------------------
    float invS = 1.0 / float(SSPT_SAMPLES);

    // GI: colored surface bounce + emissive hits.
    vec3 bounce = hitAcc * invS * SSPT_GI_STRENGTH;

    // Skylight + AO: `openness` is the fraction of the hemisphere that reached sky
    // (1 = open, 0 = fully occluded). Raising it to SSPT_AO_STRENGTH is a separable
    // ambient-occlusion contrast on the skylight (=1 is the physically-natural amount,
    // >1 deepens contact darkening, 0 = no AO). Gated by the pixel's sky access.
    float openness = float(misses) * invS;
    float ao       = pow(clamp(openness, 0.0, 1.0), SSPT_AO_STRENGTH);
    vec3  avgSky   = (misses > 0) ? skyAcc / float(misses) : vec3(0.0);
    vec3  skylight = avgSky * ao * skyAccess * SSPT_SKY_STRENGTH;

    vec3 gi = bounce + skylight;

    // Source firefly clamp (chroma-preserving): a lone ray catching the bright
    // sun/sky through a gap returns a spike no denoiser can distinguish from signal.
    float lum = dot(gi, vec3(0.2126, 0.7152, 0.0722));
    if (GID_FIREFLY_MAX < 1000.0 && lum > GID_FIREFLY_MAX) {
        gi *= GID_FIREFLY_MAX / lum;
    }

    // Reproject key + SVGF luminance moments. linDepth (view distance) is both the
    // disocclusion key and the geometry depth the a-trous edge-stop reads. m1/m2 are
    // the temporally-accumulated single-sample luma moments; the SVGF filter derives
    // variance = m2 - m1^2 and divides by history length itself (SVGF_VAR_HISTNORM).
    float linDepth = -viewPos.z;
    float curLuma  = dot(gi, vec3(0.2126, 0.7152, 0.0722)); // this frame's estimate
    float m1 = curLuma;
    float m2 = curLuma * curLuma;
    float histLen = 1.0;

    #ifdef SSPT_ACCUM
        // Temporal accumulation: reproject THIS pixel (a static world point) into the
        // previous camera, read the running-average GI (colortex8) + moments (colortex9)
        // + history length, and blend all three. A relative-depth mismatch vs. the stored
        // reproject key (colortex9.r) flushes history so disocclusions don't ghost.
        // colortex8/9 are read-of-previous-frame here (this pass is their only writer).
        vec3 worldRel = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 prevRel  = worldRel + (cameraPosition - previousCameraPosition);
        vec3 prevView = (gbufferPreviousModelView * vec4(prevRel, 1.0)).xyz;
        vec4 clipPrev = gbufferPreviousProjection * vec4(prevView, 1.0);
        vec2 prevUV   = (clipPrev.xy / clipPrev.w) * 0.5 + 0.5;

        if (clamp(prevUV, 0.0, 1.0) == prevUV) {
            float expectedPrevDepth = -prevView.z;
            vec4  h9 = texture(colortex9, prevUV * renderScale);
            if (abs(expectedPrevDepth - h9.r) <= ACCUM_DISOCC_DEPTH * expectedPrevDepth) {
                vec4  hist   = texture(colortex8, prevUV * renderScale);

                // Temporal firefly rejection: a single frame's GI spike (a lone ray
                // catching the bright sky/sun through a gap) is clamped to SSPT_FIREFLY x
                // the accumulated history luma before blending, so it can't smear into a
                // glowing blob. Chroma-preserving; skipped while history is still building.
                float histLuma = dot(hist.rgb, vec3(0.2126, 0.7152, 0.0722));
                if (SSPT_FIREFLY > 0.0 && hist.a > 2.0 && histLuma > 1e-4
                    && curLuma > histLuma * SSPT_FIREFLY) {
                    float k = (histLuma * SSPT_FIREFLY) / curLuma;
                    gi *= k;
                    curLuma *= k;
                }

                float newLen = min(hist.a, float(SSPT_ACCUM_FRAMES)) + 1.0;
                float alpha  = 1.0 / newLen;
                gi      = mix(hist.rgb, gi, alpha);
                m1      = mix(h9.g, curLuma, alpha);
                m2      = mix(h9.b, curLuma * curLuma, alpha);
                histLen = newLen;
            }
        }
    #endif

    // World-space normal packed for the SVGF geometry edge-stop (colortex15).
    vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;

    gl_FragData[0] = vec4(gi, histLen);
    gl_FragData[1] = vec4(linDepth, m1, m2, 0.0);
    gl_FragData[2] = vec4(octEncodeNormal(worldNormal), linDepth, 0.0);
}

#endif
