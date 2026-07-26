#include "/lib/options.glsl"

// dh_water : Distant Horizons LOD water G-buffer writer.
//
// Writes the deferred translucent g-buffer (surface normal -> colortex1,
// lightmap + material flag + baked colour -> colortex2), but deliberately leaves
// colortex0 untouched. DH exposes water as a distinct material but currently has
// no ice material ID, so non-water translucent geometry must be retained here and
// classified from its baked colour instead of being discarded.
//
// Occlusion: DH renders beyond the vanilla far plane, so ANY vanilla opaque
// geometry (depthtex1 < 1.0) at this pixel is closer — discard so DH translucent
// surfaces never draw THROUGH near Minecraft chunks.

#ifdef VERTEX

#include "/lib/util/jitter.glsl"

flat out int  mat;
out vec2 lmCoord;
out vec3 viewNormal;
out vec3 worldPos;
out vec3 playerPos;
out vec3 viewPosDH; // view-space position (for the occlusion depth compare)
out vec4 glColor;

void main() {
    gl_Position = ftransform();

#ifndef DISTANT_HORIZONS
    mat        = 0;
    lmCoord    = vec2(0.0);
    viewNormal = vec3(0.0, 1.0, 0.0);
    viewPosDH  = vec3(0.0);
    playerPos  = vec3(0.0);
    worldPos   = vec3(0.0);
    glColor    = vec4(0.0);
    return;
#else
    mat        = dhMaterialId;
    lmCoord    = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    viewPosDH  = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos  = (gbufferModelViewInverse * vec4(viewPosDH, 1.0)).xyz;
    worldPos   = playerPos + cameraPosition;
    glColor    = gl_Color;

    #ifdef TAA
        gl_Position.xy += getTaaJitter() * 2.0 * gl_Position.w / vec2(viewWidth, viewHeight);
    #endif

    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
#endif
}

#endif

#ifdef FRAGMENT

#include "/lib/util/common.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/fragment/water.glsl"

flat in int  mat;
in vec2 lmCoord;
in vec3 viewNormal;
in vec3 worldPos;
in vec3 playerPos;
in vec3 viewPosDH;
in vec4 glColor;

void main() {
#ifndef DISTANT_HORIZONS
    discard;
#else
    bool isWater = mat == DH_BLOCK_WATER;

    // Occlusion by the near scene: compare this DH-water fragment's view-space depth
    // (passed from the vertex stage, so no dhProjectionInverse — Iris doesn't inject
    // it into DH programs) against the vanilla scene depth. If vanilla geometry is
    // nearer, the water is behind it — discard so DH water never draws THROUGH near
    // Minecraft chunks. View space is shared (camera); only the projection differs.
    {
        float backMC = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
        if (backMC < 1.0) {
            vec4 vmc = gbufferProjectionInverse * vec4(0.0, 0.0, backMC * 2.0 - 1.0, 1.0);
            if (vmc.z / vmc.w > viewPosDH.z) discard; // vanilla nearer (less -z) -> occluded
        }
    }

    // Near-edge dither fade for the soft hand-off at the vanilla render boundary.
    float dist     = length(playerPos);
    float dither   = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);
    float nearFade = smoothstep(far * 0.5, far * 0.7, dist);
    if (nearFade < dither) discard;

    // Wave normal (distance-faded like near water so it isn't sub-pixel noise far out).
    // Ice/glass keep the geometric LOD normal; applying water waves to DH's
    // otherwise-unlabelled translucent geometry made frozen lakes visibly swim.
    vec3 worldGeoN = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vec3 worldN    = worldGeoN;
    #ifdef WATER_WAVES
    if (isWater) {
        float t        = frameTimeCounter * WATER_WAVE_SPEED;
        float lod      = clamp(dist / WATER_NORMAL_FADE, 0.0, 1.0);
        float fadeMin  = WATER_NORMAL_FADE_MIN * 0.01;
        float strength = WATER_NORMAL_STRENGTH * mix(1.0, fadeMin, lod);
        float eps      = mix(0.10, 0.45, lod);
        worldN = waterSurfaceNormal(worldPos, worldGeoN, t, WATER_WAVE_AMPLITUDE, strength, eps);
    }
    #endif
    vec3 viewWaveN = normalize(mat3(gbufferModelView) * worldN);

    // DH 3.x has no ICE enum: vanilla ice and glass both arrive as UNKNOWN
    // translucent materials. The baked LOD colour is enough to separate the
    // common cases (ice is blue/cyan; clear glass is neutral). Blue stained glass
    // intentionally takes the ice path, which is a much closer fallback than
    // dropping the surface entirely. These flags match gbuffers_water/c_water.
    float blueLead = glColor.b - max(glColor.r, glColor.g * 0.82);
    bool iceLike   = !isWater && glColor.b > 0.42 && blueLead > 0.025;
    float matFlag  = isWater ? 1.0 : (iceLike ? 0.5 : 0.75);
    float packedColor = isWater ? 0.0 : packColor565(clamp(glColor.rgb, 0.0, 1.0));

    /* DRAWBUFFERS:12 */
    gl_FragData[0] = vec4(viewWaveN * 0.5 + 0.5, 0.0);         // colortex1: normal, alpha marks DH translucent
    gl_FragData[1] = vec4(lmCoord, matFlag, packedColor);      // colortex2: lightmap, material flag, packed colour
#endif
}

#endif
