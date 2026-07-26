// d4_denoise : LAST a-trous iteration (step 16).
// Chain: d1_atrous_first (step1 -> ct3) -> d1 (2 -> ct6) -> d2 (4 -> ct3) ->
// d3 (8 -> ct6) -> THIS (16 -> ct3). d7_composite reads colortex3.
// History feedback is the raw accumulated GI in colortex8 (written by
// d0_accum), so no extra history write is needed here.
#define DENOISE_SRC  colortex6
#define DENOISE_STEP 16.0
#define DENOISE_WIDE // center-only variance + SVGF_ADAPTIVE_SKIP eligible
/* RENDERTARGETS: 3 */
#include "/program/deferred/d_denoise_common.glsl"
