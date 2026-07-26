#ifdef VERTEX

#include "/lib/options.glsl"



/*
Shadow Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

out vec2 texCoord;
flat out vec2 vMidTexCoord;
flat out vec3 voxelCenter;
flat out vec3 voxelNormal;
flat out uint voxelBlockCategory;
flat out int biomeTintedBlock;
flat out float isBlockGeom; // 1 = real block (at_midBlock valid -> mid-texcoord write gate usable)
out float skyLight;



attribute vec4 mc_Entity;
attribute vec3 at_midBlock;
attribute vec2 mc_midTexCoord;

vec3 wind(vec3 position) {
    position.xy += abs(sin(2.0 * PI * (frameTimeCounter * 0.7 + position.x /  11.0 + position.y / 5.0)) * 0.0015);
    return position;
}

void main() {
    texCoord = gl_MultiTexCoord0.xy;
    vMidTexCoord = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0.0, 1.0)).st;
    gl_Position = ftransform();

    // Use the projection inverse to recover world-space position.
    // Adding at_midBlock/64.0 snaps the sample point to the exact block center.
    vec4 position = gl_Position;
	position = shadowProjectionInverse * position;
	position = shadowModelViewInverse * position;
	position.xyz += cameraPosition.xyz;

    voxelCenter = position.xyz + at_midBlock / 64.0;

    // Entities/block-entities run through this same shadow program but get
    // default-zero block attributes (at_midBlock == 0, mc_midTexCoord == 0).
    // For them the mid-texcoord write gate in the fragment stage would be
    // meaningless and silently drop their voxels — flag real block geometry
    // (at_midBlock is the vertex->block-center offset: nonzero for blocks).
    isBlockGeom = any(notEqual(at_midBlock, vec3(0.0))) ? 1.0 : 0.0;


    voxelNormal = normalize(mat3(shadowModelViewInverse) * (gl_NormalMatrix * gl_Normal));

    // Classify block category from entity ID
    float eid = mc_Entity.x;
    if      (eid == 10000.0) voxelBlockCategory = 2u; // foliage 2 (leaves) - Voxelized
    #ifdef EXCLUDE_BLOCKLIGHTS_VOXELIZATION
    else if (eid >= 10100.0 && eid <= 10199.0) voxelBlockCategory = 0u; // excluded from voxel grid entirely
    #else
    else if (eid >= 10100.0 && eid <= 10199.0) voxelBlockCategory = 100u + uint(round(eid - 10100.0)); // special block light (mat stored as 100 + mat)
    #endif
    else if (eid == 10001.0) voxelBlockCategory = 3u; // emissive (fallback)
    #ifdef VOXEL_SHAPES
    // sub-block shaped opaque blocks: block id 20000+N -> shape id N packed
    // into the category byte (see lib/pt/voxelData.glsl shape enum)
    else if (eid >= 20001.0 && eid <= 20066.0) voxelBlockCategory = 4u + uint(round(eid - 20000.0));
    else if (blockEntityId >= 20001 && blockEntityId <= 20066) voxelBlockCategory = 4u + uint(blockEntityId - 20000);
    // packed per-material shaped ids (30000 + materialClass*100 + shapeId): the SHAPE
    // is the low 2 digits, so it voxelizes identically to the matching 20xxx shape;
    // the high digits carry the PBR material (read in terrain.glsl, ignored here).
    else if (eid >= 30101.0 && eid <= 31666.0) voxelBlockCategory = 4u + uint(round(mod(eid - 30000.0, 100.0)));
    else if (blockEntityId >= 30101 && blockEntityId <= 31666) voxelBlockCategory = 4u + uint((blockEntityId - 30000) % 100);
    #else
    else if (eid >= 20001.0 && eid <= 20066.0) voxelBlockCategory = 0u; // shapes disabled -> excluded, like the old block.10002
    else if (blockEntityId >= 20001 && blockEntityId <= 20066) voxelBlockCategory = 0u;
    else if (eid >= 30101.0 && eid <= 31666.0) voxelBlockCategory = 0u;
    else if (blockEntityId >= 30101 && blockEntityId <= 31666) voxelBlockCategory = 0u;
    #endif
    else if (eid == 10002.0 || eid == 10004.0 || eid == 10005.0 || eid == 10006.0 || eid == 10007.0 || entityId == 10002 || blockEntityId == 10002) voxelBlockCategory = 0u; // excluded (entities, grass, flowers, transparents, water, etc.) -> VOXEL_AIR
    else if (eid >= 22001.0 && eid <= 22008.0) voxelBlockCategory = 0u; // integrated-PBR but voxel-EXCLUDED (rails/bars): reflective yet must not occlude GI
    else                     voxelBlockCategory = 1u; // opaque (default); 21001-21016 land here (PBR + normal voxel)

    // Flag blocks that need special voxel coloring or face skipping.
    // 1 = grass_block (10003), 2 = leaves (10000)
    biomeTintedBlock = (eid == 10003.0) ? 1 : ((eid == 10000.0) ? 2 : 0);

    position.xyz -= cameraPosition.xyz;
	position = shadowModelView * position;
	position = shadowProjection * position;

	gl_Position = position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	gl_Position.xy *= 1.0 / distortFactor;

    gl_FrontColor = gl_Color;
    skyLight = gl_MultiTexCoord1.y * (1.0 / 240.0);
}

#endif

#ifdef FRAGMENT

/*
Shadow Source Code By saada2006:
https://github.com/saada2006/MinecraftShaderProgramming
*/

#include "/lib/options.glsl"
#include "/lib/pt/voxelData.glsl"

in vec2 texCoord;
flat in vec2 vMidTexCoord;
flat in vec3 voxelCenter;
flat in vec3 voxelNormal;
flat in uint voxelBlockCategory;
flat in int biomeTintedBlock;
flat in float isBlockGeom;
in float skyLight;

layout(rgba8ui) uniform writeonly uimage3D voxelImg;
layout(r8ui) uniform writeonly uimage3D brickImg;
layout(r8ui) uniform writeonly uimage3D superBrickImg;

void main() {
    // check alpha for discard using per-fragment sampling (needed for leaves/foliage) to maintain the correct block shape in the voxel grid.
    vec4 texFrag = texture(texture, texCoord);
    if (texFrag.a < 0.1) {
        discard;
    }

    vec4 tex = texture(texture, vMidTexCoord);
    bool midTransparent = tex.a < 0.1; // remembered for the voxel-write gate below
    if (midTransparent) {
        // if the tile center is transparent, use the fragment color as a fallback but this should be rare for solid blocks
        tex = texFrag;
    }

    // ---- Voxelization (DISABLED with VOXEL_GI) ------------------------------
    // Kept in-tree for later reuse. When VOXEL_GI is off nothing reads the grid,
    // so the whole write is compiled out — the shadow pass only produces the
    // shadow-colour output (gl_FragData[0] = tex below).
#ifdef VOXEL_GI
    vec3 tint = gl_Color.rgb;
    vec3 albedo = tex.rgb * (all(lessThan(tint, vec3(0.004))) ? vec3(1.0) : tint);

    if (biomeTintedBlock == 1) {

        albedo = all(lessThan(tint, vec3(0.004))) ? vec3(0.48, 0.61, 0.28) : tint;
    } else if (biomeTintedBlock == 2) {

        vec3 leafTint = (all(lessThan(tint, vec3(0.004))) || all(greaterThan(tint, vec3(0.999)))) ? vec3(0.38, 0.58, 0.18) : tint;
        albedo = tex.rgb * leafTint;
    }

    uint finalCategory = voxelBlockCategory;

    // scale down blocklight emission outdoors under the open sky during the day.
    if (finalCategory == 3u || finalCategory >= 100u) {
        vec3 sunVec = normalize(sunPosition);
        vec3 upVec  = normalize(upPosition);
        float sunUp = clamp(dot(sunVec, upVec), 0.0, 1.0);
        if (sunUp > 0.1 && skyLight > 0.85) {
            finalCategory = 0u; // exclude from voxelization / set as AIR (no emission)
        }
    }

    uvec4 voxelData = uvec4(finalCategory, uvec3(clamp(albedo, 0.0, 1.0) * 255.0 + 0.5));

    bool isTopFace = voxelNormal.y > 0.5;

    bool centerFrag = all(lessThanEqual(abs(texCoord - vMidTexCoord), fwidth(texCoord)));
    bool skipVoxelWrite = ((biomeTintedBlock == 1) && !isTopFace) || (finalCategory == 0u)
                       || !(centerFrag || midTransparent || isBlockGeom < 0.5);

    ivec3 voxelCoord;
    vec3 gridOrigin = floor(cameraPosition) - VOXEL_RADIUS_VEC;
    if (!skipVoxelWrite && worldToVoxel(voxelCenter, gridOrigin, voxelCoord)) {
        imageStore(voxelImg, voxelCoord, voxelData);
        imageStore(brickImg,      voxelCoord >> 3, uvec4(1u));
        imageStore(superBrickImg, voxelCoord >> 6, uvec4(1u));
    }
#endif // VOXEL_GI

    gl_FragData[0] = tex;
}

#endif
