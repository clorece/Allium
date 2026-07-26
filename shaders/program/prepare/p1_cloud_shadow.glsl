// p1_cloud_shadow : cloud shadow map build pass.
//
// Target: colortex13, 512×512 RGBA16F. Only .r is consumed (cloud
// transmittance from the cloud-layer mid-plane along the sun ray).
//
// Projection (distortion-warped):
//   ndc      = uv * 2 - 1
//   worldXZ  = cameraXZ + (ndc / (1 - |ndc|)) * CLOUDS_SHADOW_EXTENT
// gives infinite world coverage with high precision near camera and
// gracefully decaying precision at distance — the singularity at |ndc|=1
// is exactly at infinity, never reached.
//
// d7_composite samples this with the inverse warp to dim the direct sun
// term on terrain beneath clouds. Phase 5 cost: ~0.3 ms.

#ifdef VERTEX

void main() {
    gl_Position = ftransform();
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"
#include "/lib/fragment/clouds.glsl"

/* RENDERTARGETS: 13 */

void main() {
#ifndef CLOUDS_SHADOW
    // CLOUDS_SHADOW disabled — write full sun visibility so d7_composite
    // multiplies by 1.0 and the result is identical to "no clouds".
    gl_FragData[0] = vec4(1.0);
    return;
#else
    vec2 uv  = gl_FragCoord.xy / 512.0;
    vec2 ndc = uv * 2.0 - 1.0;

    // Distortion warp: ndc/(1-|ndc|) is odd-symmetric and maps |ndc|=1 to
    // infinity, giving infinite world coverage with high near-camera precision.
    // Clamp |ndc| < 0.999 to keep the offset finite at edge texels.
    vec2 ndcAbs = clamp(abs(ndc), vec2(0.0), vec2(0.999));
    vec2 worldXZOffset = (ndc / (1.0 - ndcAbs)) * CLOUDS_SHADOW_EXTENT;

    float cloudMidAlt = (CLOUDS_LAYER_BOTTOM + CLOUDS_LAYER_TOP) * 0.5;

    vec3 worldPos;
    worldPos.x = cameraPosition.x + worldXZOffset.x;
    worldPos.z = cameraPosition.z + worldXZOffset.y;
    worldPos.y = cloudMidAlt;

    vec3 worldSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);

    float od = singleTapCloudOpticalDepth(worldPos, worldSunDir);
    float transmittance = exp(-od);

    gl_FragData[0] = vec4(transmittance, 0.0, 0.0, 1.0);
#endif
}

#endif
