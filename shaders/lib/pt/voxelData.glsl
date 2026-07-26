#ifndef VOXEL_DATA_GLSL
#define VOXEL_DATA_GLSL

#include "/lib/options.glsl"


// #if VOXEL_DISTANCE chain — keep them in sync.
#define VOXEL_DIM_X (VOXEL_DISTANCE * 32)
#define VOXEL_DIM_Y 128
#define VOXEL_DIM_Z (VOXEL_DISTANCE * 32)
const ivec3 VOXEL_DIMS       = ivec3(VOXEL_DIM_X, VOXEL_DIM_Y, VOXEL_DIM_Z);
// half-extent (radius) per axis; the camera sits at the grid centre
const vec3  VOXEL_RADIUS_VEC = vec3(VOXEL_DIM_X / 2, VOXEL_DIM_Y / 2, VOXEL_DIM_Z / 2);

// block categories stored in the voxel grid (.r channel of each RGBA8UI texel)
// 0-3 = simple categories, [4..70] = opaque with sub-block shape (shape id =
// category - VOXEL_SHAPED_BASE), 100+ = special blocklight (100 + mat).
#define VOXEL_AIR      0u
#define VOXEL_OPAQUE   1u
#define VOXEL_FOLIAGE  2u
#define VOXEL_EMISSIVE 3u
#define VOXEL_SHAPED_BASE 4u
#define VOXEL_SHAPE_MAX   66u

// ----------------------------------------------------------------------------
// Shape id enum (block.properties id = 20000 + shapeId):
//   0        full cube (never stored as shaped)
//   1..15    bottom-aligned full-footprint box, height N/16
//            (1 carpet/pressure plate, 2 repeater, 3 bottom trapdoor,
//             7 campfire, 8 bottom slab/cake, 9 bed/stonecutter, 12 enchanting
//             table/hopper, 14 chest/lectern, 15 dirt path/cauldron, ...)
//   16+N     top-aligned box, height N/16 (N=1..15: 19 top trapdoor,
//            24 top slab, 18 scaffolding platform, ...)
//   31..34   wall plane pressed against the N/S/W/E face, 3/16 thick
//            (doors, ladders, open trapdoors)
//   35       centered wall running X (east-west, 4/16 thick: gates facing N/S)
//   36       centered wall running Z (north-south: gates facing E/W)
//   37       fence cross (two crossing 4/16 walls, full height)
//   38       pane cross  (two crossing 2/16 walls, full height: iron bars)
//   39       wall cross  (two crossing 8/16 walls, 14/16 tall)
//   40       center post (torch:  4/16 sq, 10/16 tall)
//   41       small centered box (lantern/candles/pots: 6/16 sq, 9/16 tall)
//   42       thin column (chain/end rod/dripstone/bamboo: 2/16 sq, full height)
//   43..66   stairs: 43 + group*8 + (half==top ? 4 : 0) + orient
//            group 0 straight: orient 0..3 = riser on N,S,W,E half
//            group 1 outer:    orient 0..3 = quarter-riser in NW,NE,SW,SE
//            group 2 inner:    orient 0..3 = L-riser wrapping NW,NE,SW,SE
//            (north = -Z, west = -X; "riser" = the half-height step part,
//             the slab part is implied by half)
// ----------------------------------------------------------------------------

// Shapes for special blocklights (category 100+mat), derived from the light
// material — no storage needed. mat numbers follow block.properties 101xx ids.
uint lightVoxelShape(uint mat) {
    if (mat ==  2u || mat == 28u || mat == 35u) return 40u; // torch / soul / redstone torch
    if (mat == 12u || mat == 29u || mat ==  6u || mat == 36u ||
        mat == 38u || mat == 40u || mat == 24u ||
        (mat >= 70u && mat <= 80u))             return 41u; // lanterns, sea pickle, amethyst, dragon egg, brewing stand, candles
    if (mat ==  3u || mat == 20u || mat == 65u) return 42u; // end rod, cave/weeping/twisting vines
    if (mat == 15u || mat == 30u)               return  7u; // campfires
    if (mat == 33u)                             return 12u; // enchanting table
    if (mat == 66u)                             return  1u; // redstone wire
    if (mat == 67u)                             return  2u; // powered repeater/comparator
    return 0u;
}

// Emissive sub-box (local 0..1) for a special-light material (category 100+mat).
// Concentrating the emission inside the block lets the occluder shape cast a real
// shadow: a torch emits only from a flame box at the top of its post, so surfaces
// low and behind the stick fall into the post's shadow. Defaults to the full cube
// for area emitters (lava, glowstone, froglight, end rod, vines).
void lightEmissiveAabb(uint mat, out vec3 bmin, out vec3 bmax) {
    bmin = vec3(0.0); bmax = vec3(1.0); // full-cube emitter fallback
    if (mat == 2u || mat == 28u || mat == 35u) {           // torch / soul / redstone torch: flame cap above the post
        bmin = vec3(5.0 / 16.0, 7.0 / 16.0, 5.0 / 16.0);
        bmax = vec3(11.0 / 16.0, 13.0 / 16.0, 11.0 / 16.0);
    } else if (mat == 15u || mat == 30u) {                 // campfire / soul campfire: low central embers
        bmin = vec3(3.0 / 16.0, 1.0 / 16.0, 3.0 / 16.0);
        bmax = vec3(13.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0);
    } else if (mat == 12u || mat == 29u || mat == 40u ||   // lantern / soul lantern / brewing stand
               (mat >= 70u && mat <= 80u)) {               // candles
        bmin = vec3(5.0 / 16.0, 1.0 / 16.0, 5.0 / 16.0);
        bmax = vec3(11.0 / 16.0, 9.0 / 16.0, 11.0 / 16.0);
    }
}

// Ray/AABB entry-exit test that does NOT disturb any running best-hit state.
// tn is the entry distance (clamped to >= 0 for an origin inside the box).
bool aabbEntry(vec3 ro, vec3 rd, vec3 bmin, vec3 bmax, out float tn, out float tf) {
    vec3 ird = 1.0 / (rd + vec3(1e-8));
    vec3 t0  = (bmin - ro) * ird;
    vec3 t1  = (bmax - ro) * ird;
    tn = max(max(min(t0.x, t1.x), min(t0.y, t1.y)), min(t0.z, t1.z));
    tf = min(min(max(t0.x, t1.x), max(t0.y, t1.y)), max(t0.z, t1.z));
    return tf >= max(tn, 0.0);
}

uint voxelShapeId(uint cat) {
    if (cat >= VOXEL_SHAPED_BASE && cat <= VOXEL_SHAPED_BASE + VOXEL_SHAPE_MAX)
        return cat - VOXEL_SHAPED_BASE;
    if (cat >= 100u) return lightVoxelShape(cat - 100u);
    return 0u;
}

bool voxelAabbHit(vec3 ro, vec3 ird, vec3 bmin, vec3 bmax, bool skipInside, inout float tBest, inout vec3 nBest) {
    vec3 t0  = (bmin - ro) * ird;
    vec3 t1  = (bmax - ro) * ird;
    vec3 tn3 = min(t0, t1);
    vec3 tf3 = max(t0, t1);
    float tn = max(tn3.x, max(tn3.y, tn3.z));
    float tf = min(tf3.x, min(tf3.y, tf3.z));
    if (tn > tf || tf < 0.0) return false;
    if (skipInside && tn <= 0.0) return false; // origin inside this box
    float t = max(tn, 0.0);
    if (t >= tBest) return false;
    tBest = t;
    if (tn > 0.0) nBest = -sign(ird) * vec3(equal(vec3(tn), tn3));
    return true;
}

bool intersectVoxelShape(uint shape, vec3 ro, vec3 rd, bool originVoxel, out float tHit, out vec3 nHit) {
    vec3 ird = 1.0 / (rd + vec3(1e-8));
    tHit = 1e30;
    nHit = -rd; // fallback normal when the ray starts inside the shape
    bool hit = false;

    if (shape <= 30u) {
        // bottom- (1..15) or top- (17..31, bit 4) aligned full-footprint box
        float h  = float(shape & 15u) * (1.0 / 16.0);
        bool  ta = shape > 16u;
        hit = voxelAabbHit(ro, ird, vec3(0.0, ta ? 1.0 - h : 0.0, 0.0),
                                    vec3(1.0, ta ? 1.0 : h,       1.0), originVoxel, tHit, nHit);
    } else if (shape <= 34u) {
        // 3/16 wall plane against the N/S/W/E face
        const float T = 3.0 / 16.0;
        vec3 bmin = vec3(0.0), bmax = vec3(1.0);
        if      (shape == 31u) bmax.z = T;
        else if (shape == 32u) bmin.z = 1.0 - T;
        else if (shape == 33u) bmax.x = T;
        else                   bmin.x = 1.0 - T;
        hit = voxelAabbHit(ro, ird, bmin, bmax, originVoxel, tHit, nHit);
    } else if (shape <= 36u) {
        // centered 4/16 wall running X (35) or Z (36) — closed fence gates
        const float T = 2.0 / 16.0;
        vec3 bmin = vec3(0.0), bmax = vec3(1.0);
        if (shape == 35u) { bmin.z = 0.5 - T; bmax.z = 0.5 + T; }
        else              { bmin.x = 0.5 - T; bmax.x = 0.5 + T; }
        hit = voxelAabbHit(ro, ird, bmin, bmax, originVoxel, tHit, nHit);
    } else if (shape == 37u) {
        // fence: 4/16 center post (full height) + two crossing 2/16-thick arm
        // slats at y[6..15]/16. Much less occlusion than full crossing walls —
        // an isolated post no longer shadows like a wall intersection.
        hit = voxelAabbHit(ro, ird, vec3(6.0/16.0, 0.0, 6.0/16.0),
                                    vec3(10.0/16.0, 1.0, 10.0/16.0), originVoxel, tHit, nHit);
        hit = voxelAabbHit(ro, ird, vec3(7.0/16.0, 6.0/16.0, 0.0),
                                    vec3(9.0/16.0, 15.0/16.0, 1.0), originVoxel, tHit, nHit) || hit;
        hit = voxelAabbHit(ro, ird, vec3(0.0, 6.0/16.0, 7.0/16.0),
                                    vec3(1.0, 15.0/16.0, 9.0/16.0), originVoxel, tHit, nHit) || hit;
    } else if (shape == 38u) {
        // pane cross: two crossing 2/16 walls, full height (iron bars)
        hit = voxelAabbHit(ro, ird, vec3(7.0/16.0, 0.0, 0.0),
                                    vec3(9.0/16.0, 1.0, 1.0), originVoxel, tHit, nHit);
        hit = voxelAabbHit(ro, ird, vec3(0.0, 0.0, 7.0/16.0),
                                    vec3(1.0, 1.0, 9.0/16.0), originVoxel, tHit, nHit) || hit;
    } else if (shape == 39u) {
        // wall: 8/16 center post (full height) + two crossing 6/16-thick,
        // 14/16-tall arm walls
        hit = voxelAabbHit(ro, ird, vec3(4.0/16.0, 0.0, 4.0/16.0),
                                    vec3(12.0/16.0, 1.0, 12.0/16.0), originVoxel, tHit, nHit);
        hit = voxelAabbHit(ro, ird, vec3(5.0/16.0, 0.0, 0.0),
                                    vec3(11.0/16.0, 14.0/16.0, 1.0), originVoxel, tHit, nHit) || hit;
        hit = voxelAabbHit(ro, ird, vec3(0.0, 0.0, 5.0/16.0),
                                    vec3(1.0, 14.0/16.0, 11.0/16.0), originVoxel, tHit, nHit) || hit;
    } else if (shape <= 42u) {
        // centered boxes: 40 torch post, 41 small box, 42 thin full-height column
        float W = (shape == 40u) ? 2.0 / 16.0 : (shape == 41u) ? 3.0 / 16.0 : 1.0 / 16.0;
        float H = (shape == 40u) ? 10.0 / 16.0 : (shape == 41u) ? 9.0 / 16.0 : 1.0;
        hit = voxelAabbHit(ro, ird, vec3(0.5 - W, 0.0, 0.5 - W),
                                    vec3(0.5 + W, H,   0.5 + W), originVoxel, tHit, nHit);
    } else {
        // stairs: slab half + riser (straight half / outer quarter / inner L)
        uint  s     = shape - 43u;
        uint  group = s >> 3;
        bool  top   = (s & 4u) != 0u;
        uint  o     = s & 3u;
        float sy0   = top ? 0.5 : 0.0; // slab part y-min
        float ry0   = 0.5 - sy0;       // riser part y-min (the other half)
        hit = voxelAabbHit(ro, ird, vec3(0.0, sy0, 0.0), vec3(1.0, sy0 + 0.5, 1.0), originVoxel, tHit, nHit);
        if (group == 0u) {
            vec2 xr = vec2(0.0, 1.0), zr = vec2(0.0, 1.0);
            if      (o == 0u) zr = vec2(0.0, 0.5);
            else if (o == 1u) zr = vec2(0.5, 1.0);
            else if (o == 2u) xr = vec2(0.0, 0.5);
            else              xr = vec2(0.5, 1.0);
            hit = voxelAabbHit(ro, ird, vec3(xr.x, ry0, zr.x), vec3(xr.y, ry0 + 0.5, zr.y), originVoxel, tHit, nHit) || hit;
        } else {
            vec2 qx = (o & 1u) == 0u ? vec2(0.0, 0.5) : vec2(0.5, 1.0); // W/E half
            vec2 qz = (o & 2u) == 0u ? vec2(0.0, 0.5) : vec2(0.5, 1.0); // N/S half
            if (group == 1u) {
                hit = voxelAabbHit(ro, ird, vec3(qx.x, ry0, qz.x), vec3(qx.y, ry0 + 0.5, qz.y), originVoxel, tHit, nHit) || hit;
            } else {
                hit = voxelAabbHit(ro, ird, vec3(qx.x, ry0, 0.0), vec3(qx.y, ry0 + 0.5, 1.0), originVoxel, tHit, nHit) || hit;
                hit = voxelAabbHit(ro, ird, vec3(0.0, ry0, qz.x), vec3(1.0, ry0 + 0.5, qz.y), originVoxel, tHit, nHit) || hit;
            }
        }
    }
    return hit;
}

#define VOXEL_BRICK 8
#define VOXEL_SUPER 64
const ivec3 BRICK_DIMS = VOXEL_DIMS / VOXEL_BRICK; // 64×16×64
const ivec3 SUPER_DIMS = VOXEL_DIMS / VOXEL_SUPER; // 8×2×8

bool brickIsEmpty(ivec3 vox) {
    if (any(lessThan(vox, ivec3(0))) || any(greaterThanEqual(vox, VOXEL_DIMS))) return false;
    return texelFetch(brickSampler, vox >> 3, 0).r == 0u;
}

bool superBrickIsEmpty(ivec3 vox) {
    if (any(lessThan(vox, ivec3(0))) || any(greaterThanEqual(vox, VOXEL_DIMS))) return false;
    return texelFetch(superBrickSampler, vox >> 6, 0).r == 0u;
}


bool worldToVoxel(vec3 worldPos, vec3 gridOrigin, out ivec3 coord) {
    vec3 local = worldPos - gridOrigin;
    coord = ivec3(floor(local));
    return all(greaterThanEqual(coord, ivec3(0))) &&
           all(lessThan(coord, VOXEL_DIMS));
}

uint sampleVoxel(usampler3D atlas, ivec3 coord) {
    return texelFetch(atlas, coord, 0).r;
}


struct VoxelSample {
    uint category;
    vec3 albedo;
};

VoxelSample readVoxel(usampler3D atlas, ivec3 coord) {
    uvec4 v = texelFetch(atlas, coord, 0);
    VoxelSample s;
    s.category = v.r;
    s.albedo   = vec3(v.gba) / 255.0;
    return s;
}

#endif
