#ifndef DDA_TRACE_GLSL
#define DDA_TRACE_GLSL

#include "/lib/pt/voxelData.glsl"

// World-space voxel DDA (empty-space-skipping via super-brick/brick occupancy).
// The old screen-space fallback (screenSpaceRayTrace) was a Serie remnant that only
// added extra detail to the world-space path tracer; it is removed for the
// screen-space path-tracing rewrite. A ray that exits the voxel grid now simply
// misses (returns false) — screen-space bounce detail is the SSPT pass's job.
bool traceVoxelRay(
    usampler3D atlas,
    vec3 worldPos,
    vec3 rayDir,
    float maxDist,
    vec3 camPos
) {
    vec3 gridOrigin = floor(camPos) - VOXEL_RADIUS_VEC;
    vec3 localPos   = worldPos - gridOrigin;

    if (any(lessThan(localPos, vec3(-2.0))) || any(greaterThanEqual(localPos, vec3(VOXEL_DIMS) + 2.0))) {
        return false;
    }

    ivec3 vox     = ivec3(floor(localPos));
    ivec3 stepDir = ivec3(sign(rayDir));


    vec3 invRayDir = 1.0 / (rayDir + 1e-8);
    vec3 tDelta = abs(invRayDir);

    vec3 t0 = (vec3(0.0) - localPos) * invRayDir;
    vec3 t1 = (vec3(VOXEL_DIMS) - localPos) * invRayDir;
    vec3 tMaxBox = max(t0, t1);
    float tExit = min(tMaxBox.x, min(tMaxBox.y, tMaxBox.z));

    // ray-direction sign as a 0/1 selector for the brick exit face
    vec3 dirPos = step(0.0, rayDir);

    vec3 tMax = (vec3(vox) + max(vec3(stepDir), 0.0) - localPos) * invRayDir;

    float tEntry = 0.0;
    ivec3 lastBrick = ivec3(-1);

    for (int i = 0; i < 768; i++) {
        if (tEntry >= maxDist) return false;

        if (tEntry > tExit) return false;

        if (all(greaterThanEqual(vox, ivec3(0))) && all(lessThan(vox, VOXEL_DIMS))) {
            ivec3 curBrick = vox >> 3;
            if (curBrick != lastBrick) {
                if (texelFetch(superBrickSampler, vox >> 6, 0).r == 0u) {
                    vec3 cellMin = vec3((vox >> 6) << 6);
                    vec3 tb = (mix(cellMin, cellMin + float(VOXEL_SUPER), dirPos) - localPos) * invRayDir;
                    float tCellExit = min(tb.x, min(tb.y, tb.z));
                    tEntry = tCellExit;
                    // land just past the exit face, then reseed the fine DDA from there
                    vox  = ivec3(floor(localPos + rayDir * (tCellExit + 1e-3)));
                    tMax = (vec3(vox) + max(vec3(stepDir), 0.0) - localPos) * invRayDir;
                    continue;
                }
                if (texelFetch(brickSampler, curBrick, 0).r == 0u) {
                    vec3 brickMin = vec3(curBrick << 3);
                    vec3 tb = (mix(brickMin, brickMin + float(VOXEL_BRICK), dirPos) - localPos) * invRayDir;
                    float tBrickExit = min(tb.x, min(tb.y, tb.z));
                    tEntry = tBrickExit;
                    vox  = ivec3(floor(localPos + rayDir * (tBrickExit + 1e-3)));
                    tMax = (vec3(vox) + max(vec3(stepDir), 0.0) - localPos) * invRayDir;
                    continue;
                }
                lastBrick = curBrick;
            }
        }

        uint vt = sampleVoxel(atlas, vox);

        if (vt != VOXEL_AIR) {
            #ifdef VOXEL_SHAPES
            uint shapeId = voxelShapeId(vt);
            if (shapeId != 0u) {
                float tS; vec3 nS;
                if (intersectVoxelShape(shapeId, localPos - vec3(vox), rayDir, i == 0, tS, nS)
                    && tS < maxDist) return true;
                // miss / origin-self-hit: keep marching
            } else if (i > 0) return true;
            #else
            if (i > 0) return true;
            #endif
        }

        bvec3 mask = lessThanEqual(tMax.xyz, min(tMax.yzx, tMax.zxy));
        tEntry = min(tMax.x, min(tMax.y, tMax.z));
        tMax  += vec3(mask) * tDelta;
        vox   += stepDir * ivec3(mask);
    }
    return false;
}

#endif
