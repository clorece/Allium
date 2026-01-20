/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Shadowcomp 1//////////Shadowcomp 1//////////Shadowcomp 1//////////
#if defined SHADOWCOMP && COLORED_LIGHTING_INTERNAL > 0 && COLORED_LIGHTING > 0

#define OPTIMIZATION_ACL_HALF_RATE_UPDATES
#define OPTIMIZATION_ACL_BEHIND_PLAYER

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
#if COLORED_LIGHTING_INTERNAL == 128
	const ivec3 workGroups = ivec3(16, 8, 16);
#elif COLORED_LIGHTING_INTERNAL == 192
	const ivec3 workGroups = ivec3(24, 12, 24);
#elif COLORED_LIGHTING_INTERNAL == 256
	const ivec3 workGroups = ivec3(32, 16, 32);
#elif COLORED_LIGHTING_INTERNAL == 384
	const ivec3 workGroups = ivec3(48, 24, 48);
#elif COLORED_LIGHTING_INTERNAL == 512
	const ivec3 workGroups = ivec3(64, 32, 64);
#elif COLORED_LIGHTING_INTERNAL == 768
	const ivec3 workGroups = ivec3(96, 32, 96);
#elif COLORED_LIGHTING_INTERNAL == 1024
	const ivec3 workGroups = ivec3(128, 32, 128);
#endif

//Common Variables//
ivec3[6] face_offsets = ivec3[6](
	ivec3( 1,  0,  0),
	ivec3( 0,  1,  0),
	ivec3( 0,  0,  1),
	ivec3(-1,  0,  0),
	ivec3( 0, -1,  0),
	ivec3( 0,  0, -1)
);

// Tint colors for stained glass and similar blocks (voxel IDs 200+)
// Index 0 = voxelID 200 (White Stained Glass), etc.
// Based on Minecraft stained glass colors
const vec3[] specialTintColor = vec3[](
	vec3(1.0, 1.0, 1.0),       // 200: White Stained Glass
	vec3(0.95, 0.65, 0.2),     // 201: Orange Stained Glass
	vec3(0.9, 0.2, 0.9),       // 202: Magenta Stained Glass
	vec3(0.4, 0.6, 0.85),      // 203: Light Blue Stained Glass
	vec3(0.9, 0.9, 0.2),       // 204: Yellow Stained Glass
	vec3(0.5, 0.8, 0.2),       // 205: Lime Stained Glass
	vec3(1.0, 0.4, 0.7),       // 206: Pink Stained Glass
	vec3(0.3, 0.3, 0.3),       // 207: Gray Stained Glass
	vec3(0.6, 0.6, 0.6),       // 208: Light Gray Stained Glass
	vec3(0.3, 0.5, 0.6),       // 209: Cyan Stained Glass
	vec3(0.5, 0.25, 0.7),      // 210: Purple Stained Glass
	vec3(0.2, 0.25, 0.7),      // 211: Blue Stained Glass
	vec3(0.45, 0.3, 0.2),      // 212: Brown Stained Glass
	vec3(0.45, 0.75, 0.35),    // 213: Green Stained Glass
	vec3(1.0, 0.05, 0.05),     // 214: Red Stained Glass
	vec3(0.1, 0.1, 0.1),       // 215: Black Stained Glass
	vec3(0.6, 0.8, 1.0),       // 216: Ice
	vec3(1.0, 1.0, 1.0),       // 217: Glass (clear)
	vec3(1.0, 1.0, 1.0),       // 218: Glass Pane (clear)
	vec3(1.0, 1.0, 1.0),       // 219
	vec3(0.95, 0.65, 0.2),     // 220: Honey Block
	vec3(0.45, 0.75, 0.35),    // 221: Slime Block
	vec3(1.0, 1.0, 1.0),       // 222
	vec3(1.0, 1.0, 1.0),       // 223
	vec3(1.0, 1.0, 1.0),       // 224
	vec3(1.0, 1.0, 1.0),       // 225
	vec3(1.0, 1.0, 1.0),       // 226
	vec3(1.0, 1.0, 1.0),       // 227
	vec3(1.0, 1.0, 1.0),       // 228
	vec3(1.0, 1.0, 1.0),       // 229
	vec3(1.0, 1.0, 1.0),       // 230
	vec3(1.0, 1.0, 1.0),       // 231
	vec3(1.0, 1.0, 1.0),       // 232
	vec3(1.0, 1.0, 1.0),       // 233
	vec3(1.0, 1.0, 1.0),       // 234
	vec3(1.0, 1.0, 1.0),       // 235
	vec3(1.0, 1.0, 1.0),       // 236
	vec3(1.0, 1.0, 1.0),       // 237
	vec3(1.0, 1.0, 1.0),       // 238
	vec3(1.0, 1.0, 1.0),       // 239
	vec3(1.0, 1.0, 1.0),       // 240
	vec3(1.0, 1.0, 1.0),       // 241
	vec3(1.0, 1.0, 1.0),       // 242
	vec3(1.0, 1.0, 1.0),       // 243
	vec3(1.0, 1.0, 1.0),       // 244
	vec3(1.0, 1.0, 1.0),       // 245
	vec3(1.0, 1.0, 1.0),       // 246
	vec3(1.0, 1.0, 1.0),       // 247
	vec3(1.0, 1.0, 1.0),       // 248
	vec3(1.0, 1.0, 1.0),       // 249
	vec3(1.0, 1.0, 1.0),       // 250
	vec3(1.0, 1.0, 1.0),       // 251
	vec3(1.0, 1.0, 1.0),       // 252
	vec3(1.0, 1.0, 1.0),       // 253
	vec3(0.15, 0.15, 0.15)     // 254: Tinted Glass (dark)
);

writeonly uniform image3D floodfill_img;
writeonly uniform image3D floodfill_img_copy;

//Common Functions//
vec4 GetLightSample(sampler3D lightSampler, ivec3 pos) {
	return texelFetch(lightSampler, pos, 0);
}

vec4 GetLightAverage(sampler3D lightSampler, ivec3 pos, ivec3 voxelVolumeSize) {
	vec4 light_old = GetLightSample(lightSampler, pos);
	vec4 light_px  = GetLightSample(lightSampler, clamp(pos + face_offsets[0], ivec3(0), voxelVolumeSize - 1));
	vec4 light_py  = GetLightSample(lightSampler, clamp(pos + face_offsets[1], ivec3(0), voxelVolumeSize - 1));
	vec4 light_pz  = GetLightSample(lightSampler, clamp(pos + face_offsets[2], ivec3(0), voxelVolumeSize - 1));
	vec4 light_nx  = GetLightSample(lightSampler, clamp(pos + face_offsets[3], ivec3(0), voxelVolumeSize - 1));
	vec4 light_ny  = GetLightSample(lightSampler, clamp(pos + face_offsets[4], ivec3(0), voxelVolumeSize - 1));
	vec4 light_nz  = GetLightSample(lightSampler, clamp(pos + face_offsets[5], ivec3(0), voxelVolumeSize - 1));

	vec4 light = light_old + light_px + light_py + light_pz + light_nx + light_ny + light_nz;
    return light / 7.2; // Slightly higher than 7 to prevent the light from travelling too far
}

//Includes//
#include "/lib/misc/voxelization.glsl"

//Program//
void main() {
	ivec3 pos = ivec3(gl_GlobalInvocationID);
	vec3 posM = vec3(pos) / vec3(voxelVolumeSize);
	vec3 posOffset = floor(previousCameraPosition) - floor(cameraPosition);
	ivec3 previousPos = ivec3(vec3(pos) - posOffset);

	ivec3 absPosFromCenter = abs(pos - voxelVolumeSize / 2);
	if (absPosFromCenter.x + absPosFromCenter.y + absPosFromCenter.z > 16) {
	#ifdef OPTIMIZATION_ACL_BEHIND_PLAYER
		vec4 viewPos = gbufferProjectionInverse * vec4(0.0, 0.0, 1.0, 1.0);
		viewPos /= viewPos.w;
		vec3 nPlayerPos = normalize(mat3(gbufferModelViewInverse) * viewPos.xyz);
		if (dot(normalize(posM - 0.5), nPlayerPos) < 0.0) {
			#ifdef COLORED_LIGHT_FOG
				if ((frameCounter & 1) == 0) {
					imageStore(floodfill_img_copy, pos, GetLightSample(floodfill_sampler, previousPos));
				} else {
					imageStore(floodfill_img, pos, GetLightSample(floodfill_sampler_copy, previousPos));
				}
			#endif
			return;
		}
	#endif
	}

	vec4 light = vec4(0.0);
	uint voxel = texelFetch(voxel_sampler, pos, 0).x;

	if ((frameCounter & 1) == 0) {
		if (voxel == 1u) {
			imageStore(floodfill_img_copy, pos, vec4(0.0));
			return;
		}
		#ifdef OPTIMIZATION_ACL_HALF_RATE_UPDATES
			if (posM.x < 0.5) {
				imageStore(floodfill_img_copy, pos, GetLightSample(floodfill_sampler, previousPos));
				return;
			}
		#endif
		light = GetLightAverage(floodfill_sampler, previousPos, voxelVolumeSize);
	} else {
		if (voxel == 1u) {
			imageStore(floodfill_img, pos, vec4(0.0));
			return;
		}
		#ifdef OPTIMIZATION_ACL_HALF_RATE_UPDATES
			if (posM.x > 0.5) {
				imageStore(floodfill_img, pos, GetLightSample(floodfill_sampler_copy, previousPos));
				return;
			}
		#endif
		light = GetLightAverage(floodfill_sampler_copy, previousPos, voxelVolumeSize);
	}

	if (voxel == 0u || voxel >= 200u) {
		if (voxel >= 200u) {
			vec3 tint = specialTintColor[min(voxel - 200u, specialTintColor.length() - 1u)];
			light.rgb *= tint;
		}
		
		// ============ SKYLIGHT INJECTION ============
		// Trace upward to check if this voxel can see the sky
		#if defined OVERWORLD
			bool canSeeSky = true;
			int maxTraceHeight = min(voxelVolumeSize.y - pos.y - 1, 64);
			
			for (int i = 1; i <= maxTraceHeight; i++) {
				ivec3 checkPos = pos + ivec3(0, i, 0);
				if (checkPos.y >= voxelVolumeSize.y) break;
				
				uint checkVoxel = texelFetch(voxel_sampler, checkPos, 0).x;
				// If we hit a solid block, no sky visibility
				if (checkVoxel == 1u) {
					canSeeSky = false;
					break;
				}
				// Transparent blocks reduce but don't block
				if (checkVoxel >= 200u && checkVoxel < 254u) {
					// Continue but sky will be tinted
				}
			}
			
			if (canSeeSky) {
				// Inject skylight - use a sky blue color that matches ambient
				vec3 skylightColor = vec3(0.6, 0.75, 1.0) * 0.8; // Daylight blue-white (reduced)
				
				// Lower intensity at direct injection points
				float heightFactor = float(pos.y) / float(voxelVolumeSize.y);
				float skylightIntensity = 0.15 * (0.3 + heightFactor * 0.7);
				
				// Blend skylight with existing light (don't override emissive)
				light.rgb = max(light.rgb, skylightColor * skylightIntensity);
				light.a = max(light.a, skylightIntensity * 0.15);
			}
		#endif
		// ============ END SKYLIGHT INJECTION ============
		
	} else {
		vec4 color = GetSpecialBlocklightColor(int(voxel));
		color.rgb *= 4.0 * PT_EMISSIVE_I;
		
		#if defined OVERWORLD
			int solidBlocksAbove = 0;
			int maxTraceHeight = min(voxelVolumeSize.y - pos.y - 1, 32);
			for (int i = 1; i <= maxTraceHeight; i++) {
				ivec3 checkPos = pos + ivec3(0, i, 0);
				if (checkPos.y >= voxelVolumeSize.y) break;
				uint checkVoxel = texelFetch(voxel_sampler, checkPos, 0).x;
				if (checkVoxel == 1u) {
					solidBlocksAbove++;
				}
			}
			
			float daytimeFactor = 1.0 - nightFactor;
			float coverFactor = clamp(float(solidBlocksAbove), 0.1, 1.0);
			float skySuppress = (1.0 - coverFactor) * daytimeFactor * (1.0 - isEyeInCave);
			color.rgb *= 1.0 - skySuppress;
		#endif
		
		light = max(light, vec4(pow2(color.rgb), color.a));
	}

	if ((frameCounter & 1) == 0) {
		imageStore(floodfill_img_copy, pos, light);
	} else {
		imageStore(floodfill_img, pos, light);
	}
}

#else
// Fallback: minimal compute shader when colored lighting is disabled
#ifdef SHADOWCOMP
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);
void main() {}
#endif

#endif