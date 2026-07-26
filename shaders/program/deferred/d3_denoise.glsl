
#define DENOISE_SRC  colortex3
#define DENOISE_STEP 8.0
#define DENOISE_WIDE // center-only variance + SVGF_ADAPTIVE_SKIP eligible
/* RENDERTARGETS: 6 */
#include "/program/deferred/d_denoise_common.glsl"
