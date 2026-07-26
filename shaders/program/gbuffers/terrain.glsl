#include "/lib/options.glsl"

#ifdef VERTEX

#include "/lib/util/jitter.glsl"
#ifdef SPECIAL_BLOCKLIGHT
#include "/lib/blocklightColors.glsl"
#endif



out float material;
out vec2 texCoord;
out vec2 lightmapCoord;
out vec3 normal;
out vec4 color;
flat out float isSolidIce;
flat out float emissiveIntensity; // per-material self-emission scale (0 = not a special light)
flat out int   emissiveMat;       // special-light material id (mc_Entity-10100), or -1
out vec3 viewTangent;
out float tangentW;
flat out float pbrClass; // integrated PBR (v2): 0 none, 1 metal, 2 polished, 3 gem

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

vec3 wind(vec3 position) {
    position.xy -= abs(sin(2.0 * PI * (frameTimeCounter * 0.7 + position.x /  11.0 + position.y / 5.0)) * 0.015);
    return position;
}

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;

    material = 0.0;
    
    color = gl_Color;

    if (mc_Entity.x == 10000) material = 1.0; // foliage 2 (leaves) - wrap-around NdotL
    if (mc_Entity.x == 10001 || (mc_Entity.x >= 10100 && mc_Entity.x <= 10199)) material = 2.0; // emissive
    if (mc_Entity.x == 10002) material = 0.0; // structural excluded (slabs, fences) - normal shading
    if (mc_Entity.x == 10005) material = 1.1; // grass, flowers (soft constant NdotL)

    pbrClass = 0.0;
    #ifdef INTEGRATED_PBR
        // 21001-21016 (opaque) and 22001-22008 (voxel-excluded) -> class = id mod 1000
        if      (mc_Entity.x >= 21001.0 && mc_Entity.x <= 21016.0) pbrClass = mc_Entity.x - 21000.0;
        else if (mc_Entity.x >= 22001.0 && mc_Entity.x <= 22008.0) pbrClass = mc_Entity.x - 22000.0;
        // grass_block keeps its 10003 biome-tint voxel role but also reads as a
        // matte ground PBR block (class 14) — special-cased so it isn't dual-listed.
        else if (mc_Entity.x == 10003.0) pbrClass = 14.0;
        // Foliage (10000 leaves, 10005 grass/flowers/crops) keeps its voxel/wind
        // role but also reads as PBR with the SAME matte class as grass_block (14),
        // so leaves/grass get a faint sheen instead of being fully flat. Special-
        // cased here (not dual-listed) exactly like grass_block.
        else if (mc_Entity.x == 10000.0 || mc_Entity.x == 10005.0) pbrClass = 14.0;
        // Packed shaped-block ids (30000 + materialClass*100 + shapeId): the voxel
        // SHAPE comes from the low 2 digits (shadow.glsl), the MATERIAL from the high
        // digits. So stairs/slabs/walls/fences/etc. get their REAL per-material class
        // (copper stairs read metal, quartz glossy, blackstone dark, wood matte) while
        // still voxelizing as their sub-block shape. block.properties is generated so
        // each (shape x material) pair owns a distinct id. See the header ID map.
        else if (mc_Entity.x >= 30101.0 && mc_Entity.x <= 31666.0) pbrClass = floor((mc_Entity.x - 30000.0) / 100.0);
        // Leftover shaped blocks with no clean material (snow/cake/candles/pots/...)
        // stay on the 20xxx shape ids -> one generic rough-dielectric class.
        else if (mc_Entity.x >= 20001.0 && mc_Entity.x <= 20066.0) pbrClass = 12.0;
    #endif

    // Per-material self-emission scale for the special blocklight path. Known
    // light blocks (10100-10199) carry an id; map it to an HDR intensity so lava
    // blazes and faint emitters only glimmer. The legacy emissive flag (10001)
    // has no id, so give it a generic mid intensity.
    emissiveIntensity = 0.0;
    emissiveMat = -1;
    #ifdef SPECIAL_BLOCKLIGHT
        if (mc_Entity.x >= 10100 && mc_Entity.x <= 10199) {
            emissiveMat = int(mc_Entity.x) - 10100;
            emissiveIntensity = specialLightIntensity(emissiveMat);
        } else if (mc_Entity.x == 10001) {
            emissiveIntensity = 0.5; // legacy emissive flag: generic mask (mat = -1)
        }
    #endif

    #ifdef WIND_MOVEMENT
        if (mc_Entity.x == 10000 || mc_Entity.x == 10005) gl_Position.xyz = wind(gl_Position.xyz);
    #endif

    /*
    Normal and Lightmap Source Code By saada2006:
    https://github.com/saada2006/MinecraftShaderProgramming
    */
    normal = normalize(gl_NormalMatrix * gl_Normal);
    isSolidIce = (mc_Entity.x == 10008.0) ? 1.0 : 0.0; // packed_ice / blue_ice (opaque)
    viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    tangentW = at_tangent.w;
    lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;

    #ifdef TAA
        gl_Position.xy += getTaaJitter() * 2.0 * gl_Position.w / vec2(viewWidth, viewHeight);
    #endif

    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
}

#endif

#ifdef FRAGMENT

/*
Normal and Lightmap Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

in float material;
in vec2 texCoord;
in vec2 lightmapCoord;
in vec3 normal;
in vec4 color;
flat in float isSolidIce;
flat in float emissiveIntensity;
flat in int   emissiveMat;
in vec3 viewTangent;
in float tangentW;
flat in float pbrClass;

#ifdef SPECIAL_BLOCKLIGHT
#include "/lib/blocklightColors.glsl"
#endif
#ifdef INTEGRATED_PBR
#include "/lib/fragment/pbrCommon.glsl"
#endif

void main() {
    vec4 albedo = texture(texture, texCoord) * color;
    
    // Material packed into colortex1.a (RGB10_A2 -> 2-bit alpha = 4 codes):
    //   material == 0.0 -> alpha 0    (normal/excluded)
    //   material == 1.0 -> alpha 1/3  (foliage leaves)
    //   material == 1.1 -> alpha 2/3  (grass / flowers)
    //   material == 2.0 -> alpha 3/3  (emissive)
    // Decoded in d7_composite. RGB10_A2 alpha rounds writes to {0, 1/3, 2/3, 1.0}
    // exactly, so the four codes survive storage.
    float matAlpha = (material >= 1.95) ? 1.0
                   : (material >= 1.05) ? (2.0 / 3.0)
                   : (material >= 0.95) ? (1.0 / 3.0)
                   :                       0.0;


    vec3  outNormal = normal;
    float iceFlag   = 0.0;
    if (isSolidIce > 0.5) {
        const float ICE_NORMAL_STRENGTH = 2.0;
        const vec3  LUMA = vec3(0.2126, 0.7152, 0.0722);
        vec2  atlasTexel = 1.0 / vec2(textureSize(texture, 0));
        float l  = dot(albedo.rgb, LUMA);
        float lu = dot((texture(texture, texCoord + vec2(atlasTexel.x, 0.0)) * color).rgb, LUMA);
        float lv = dot((texture(texture, texCoord + vec2(0.0, atlasTexel.y)) * color).rgb, LUMA);
        vec3 T = normalize(viewTangent);
        vec3 B = normalize(cross(normal, T) * tangentW);
        outNormal = normalize(normal - ICE_NORMAL_STRENGTH * ((lu - l) * T + (lv - l) * B));
        iceFlag = 0.25;
    }

    // Per-texel self-emission strength -> colortex2.a (free for opaque terrain;
    // c_water only reads .a on translucent/ice pixels, gated by .b). The mask
    // isolates the glowing texels (flame, hot lava) from the structural ones
    // (stick, cage); intensity scales it per material. Solid ice keeps .a = 1.0
    // because c_water reads it as a packed color for that .b flag.
    float emissionStrength = 0.0;
    #ifdef SPECIAL_BLOCKLIGHT
        if (emissiveIntensity > 0.0 && iceFlag <= 0.0) {
            emissionStrength = clamp(emissiveMaskForMat(emissiveMat, albedo.rgb) * emissiveIntensity, 0.0, 1.0);
        }
    #endif
    float c2a = (iceFlag > 0.0) ? 1.0 : emissionStrength;

    // Integrated PBR material -> colortex7. Metals only (v2): store raw albedo
    // (= F0 for the metal Fresnel tint) and a per-texel smoothness derived from
    // the albedo's HSL lightness (bright facets smoother than dark
    // wear). Non-metals write 0 -> non-reflective.
    vec4 pbrOut = vec4(0.0);
    #ifdef INTEGRATED_PBR
    if (pbrClass > 0.5) {
        // Auto-generated bump normal from the albedo (same finite-difference as
        // ice): the texture's luminance gradient perturbs the surface normal, so
        // the reflection picks up the texture's relief. Stored in colortex1.
        #ifdef PBR_GEN_NORMALS
        {
            const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
            vec2  px = 1.0 / vec2(textureSize(texture, 0));
            // Central difference on the BASE mip (textureLod 0) -> crisp, centred
            // bump (texture() would use the blurred mipmap = soft normals).
            float lr = dot(textureLod(texture, texCoord + vec2(px.x, 0.0), 0.0).rgb, LUMA);
            float ll = dot(textureLod(texture, texCoord - vec2(px.x, 0.0), 0.0).rgb, LUMA);
            float lu = dot(textureLod(texture, texCoord + vec2(0.0, px.y), 0.0).rgb, LUMA);
            float ld = dot(textureLod(texture, texCoord - vec2(0.0, px.y), 0.0).rgb, LUMA);
            vec3 T = normalize(viewTangent);
            vec3 B = normalize(cross(normal, T) * tangentW);
            // Non-metals (class >= 3) get a stronger bump than metals.
            float nMul = (pbrClass < 2.5) ? 1.0 : PBR_DIELECTRIC_NORMAL;
            outNormal = normalize(outNormal - PBR_NORMAL_STRENGTH * 0.5 * nMul * ((lr - ll) * T + (lu - ld) * B));
        }
        #endif

        float L = pbrLightness(albedo.rgb);
        float t = clamp((L - 0.1) / 0.8, 0.0, 1.0); // per-texel brightness 0..1

        // Class -> (base smoothness, isMetal, dielectric F0). Distinct bases give
        // each material family its own gloss level; the per-texel DARKEN-ONLY
        // variation roughens the darker texels (floor 0.30 keeps it reflective,
        // ceiling = base so bright flecks don't pop into harsh mirrors).
        float base; bool metal; float f0 = 0.04;
        if      (pbrClass < 1.5)  { base = METAL_SMOOTHNESS; metal = true;  }            // 1 metal
        else if (pbrClass < 2.5)  { base = 0.50; metal = true;  }                        // 2 raw/rough metal
        else if (pbrClass < 3.5)  { base = 0.85; metal = false; f0 = 0.25; }             // 3 polished stone (smooth, glossy)
        else if (pbrClass < 4.5)  { base = 0.78; metal = false; f0 = 0.22; }             // 4 quartz/ceramic
        else if (pbrClass < 5.5)  { base = 0.85; metal = false; f0 = 0.28; }             // 5 gem
        else if (pbrClass < 6.5)  { base = 0.62; metal = false; f0 = 0.14; }             // 6 dark glossy (polished blackstone/deepslate)
        else if (pbrClass < 7.5)  { base = 0.72; metal = false; f0 = 0.20; }             // 7 prismarine (polished-like)
        else if (pbrClass < 8.5)  { base = 0.80; metal = false; f0 = 0.22; }             // 8 glazed terracotta
        else if (pbrClass < 9.5)  { base = 0.42; metal = false; f0 = 0.04; }             // 9 concrete
        else if (pbrClass < 10.5) { base = 0.34; metal = false; f0 = 0.04; }             // 10 terracotta
        else if (pbrClass < 11.5) { base = 0.38; metal = false; f0 = 0.04; }             // 11 bricks
        else if (pbrClass < 12.5) { base = 0.28; metal = false; f0 = 0.04; }             // 12 rough stone
        else if (pbrClass < 13.5) { base = 0.30; metal = false; f0 = 0.04; }             // 13 wood
        else if (pbrClass < 14.5) { base = 0.18; metal = false; f0 = 0.04; }             // 14 dirt/ground
        else if (pbrClass < 15.5) { base = 0.24; metal = false; f0 = 0.04; }             // 15 sand/gravel
        else                      { base = 0.15; metal = false; f0 = 0.03; }             // 16 wool

        // Per-texel darken-only variation, scaled by the class's own [floor, base]
        // range so VARIATION=1 just REACHES the floor at the darkest texels. (The
        // old absolute subtraction crushed every dielectric texel to the floor at
        // VARIATION 1, killing their reflection/glint/normals.)
        // Floor is PROPORTIONAL to the base so smooth classes (polished/gem) keep a
        // high minimum and don't average out matte; matte classes stay low.
        float floorS = metal ? 0.35 : max(0.10, base * 0.65);
        float smoothness = base - METAL_ROUGHNESS_VARIATION * (base - floorS) * (1.0 - t);
        smoothness = clamp(smoothness, floorS, 0.95);
        pbrOut = metal ? vec4(albedo.rgb, pbrPackA(smoothness, true))
                       : vec4(vec3(f0),   pbrPackA(smoothness, false));
    }
    #endif

    /* DRAWBUFFERS:0127 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(outNormal * 0.5 + 0.5, matAlpha);
    gl_FragData[2] = vec4(lightmapCoord, iceFlag, c2a);
    gl_FragData[3] = pbrOut; // colortex7: .rgb metal albedo(F0), .a smoothness
}

#endif
