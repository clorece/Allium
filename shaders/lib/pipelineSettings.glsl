#ifndef PIPELINE_SETTINGS_GLSL
#define PIPELINE_SETTINGS_GLSL

const int RGBA8 = 0;
const int RGB10_A2 = 1;
const int RGBA16 = 3;
const int RGBA16F = 5;
const int RGBA32F = 7;
const int RGBA8UI = 11;

const int colortex0Format = RGBA16F; // lit HDR scene (tonemapped in final.glsl). MUST be float: d7 writes albedo*(direct+indirect)+emission > 1.0 and final.glsl tonemaps it. Default RGBA8 clips to 1.0 before the tonemapper -> flat/desaturated "no HDR" look on drivers whose default colortex0 isn't float-backed (e.g. Mesa/radeonsi on Linux).
const int colortex1Format = RGB10_A2; // .rgb = view normals, .a = material code (2-bit: 0=normal, 1/3=foliage, 2/3=grass, 1=emissive)
const int colortex2Format = RGBA16;   // Lightmap data
const int colortex3Format = RGBA16F; // bloom atlas (composite). (Former SVGF a-trous role removed with the IRC migration.)
const int colortex4Format = RGBA16F; // reflection temporal history (.rgb accumulated reflection, .a history length); d7b_reflections
const int colortex5Format = RGBA16F; // TAA history + auto exposure (alpha) / prev-frame HDR scene
const int colortex6Format = RGBA16F; // FREE (was SVGF a-trous ping-pong B; SVGF removed by the IRC migration)
// colortex7 = PBR material G-buffer (persistent, written by opaque gbuffers, read
// by the d7b_reflections pass). Metals-first layout:
//   .rgb = raw metal albedo (= F0 for the metal Fresnel tint)
//   .a   = perceptual smoothness (0 = non-reflective; metal pixels > 0)
// RGBA8 is enough; cleared to 0 so any pixel that doesn't write it is non-metal.
const int colortex7Format = RGBA8;
const int colortex8Format = RGBA16F; // temporally-accumulated per-pixel GI (.rgb); written by d0_accum, denoised toward colortex3, read by d7_composite
const int colortex9Format = RGBA16F; // .r = linear depth (reproject key), .g/.b = luminance moments (SVGF), .a = accumulated GTAO; written by d0_accum
const int colortex10Format = RGBA16F; // ReSTIR reservoir: radiance (.rgb) + M (.a)
const int colortex11Format = RGBA16F; // ReSTIR reservoir: samplePos (.xyz) + W (.a)
const int colortex12Format = RGBA16F;
const int colortex13Format = RGBA16F;
const int colortex14Format = RGBA16F; // ReSTIR reservoir: sample-hit normal (.xy octahedral)
const int colortex15Format = RGBA16F; // ReSTIR: packed G-buffer/normal history (.xy oct world normal, .z linear depth)

const bool colortex3Clear = true;
const bool colortex5Clear = false;
const bool colortex4Clear = false; // reflection history must persist across frames
const bool colortex6Clear = true;
const bool colortex7Clear = true; // clear -> 0 = non-metal (no reflection)
const bool colortex8Clear = false;
const bool colortex9Clear = false;
const bool colortex10Clear = false;
const bool colortex11Clear = false;
const bool colortex12Clear = false;  // prepare.fsh fully overwrites it every frame
const bool colortex13Clear = false;  // prepare1.fsh fully overwrites it every frame
const bool colortex12Nearest = false;
const bool colortex13Nearest = false;
const bool colortex14Clear = false;
const bool colortex15Clear = false;

const int shadowMapResolution = SHADOW_RESOLUTION;

const float shadowDistance = VOXEL_SHADOW_DISTANCE;
const float sunPathRotation = -40.0; // [10.0 20.0 30.0 40.0 50.0 60.0]
const float ambientOcclusionLevel = 0.5;
const float ambientStrength = 0.0;
const vec3 torchColor = vec3(0.9922, 0.6471, 0.1922);

const bool shadowHardwareFiltering = false;
const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;

const bool colortex0MipmapEnabled = true;
#endif
