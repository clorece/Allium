#ifndef DH_LIGHTING_GLSL
#define DH_LIGHTING_GLSL

// Forward lighting shared by the Distant Horizons LOD passes (dh_terrain /
// dh_water). DH geometry lives beyond the voxel-GI range, so it gets a cheap
// raster fallback that mirrors d7_composite's look: lightmap torch + sky-tint
// ambient, plus a shadow-mapped direct sun term wherever the LOD falls inside
// the (small) shadow distance — everything farther is assumed sunlit and the
// atmosphere (d8 aerial perspective) takes over.
//
// Requires: positions.glsl (toShadowSpace) and the shadow uniforms. The caller
// passes player-space position, world-space normal, light/ambient colours and
// the light vector (computed in the vertex stage via vectors.glsl/colors.glsl).

float dhShadow2D(sampler2D tex, vec2 uv, float receiverDepth) {
    ivec2 ts = textureSize(tex, 0);
    vec2 f = fract(uv * vec2(ts) - 0.5);
    vec4 d = textureGather(tex, uv);
    vec4 c = step(receiverDepth, d);
    return mix(mix(c.w, c.z, f.x), mix(c.x, c.y, f.x), f.y);
}

// Returns the (possibly coloured) sun shadow for a distant LOD fragment.
vec3 dhSunShadow(vec3 playerPos, vec3 worldNormal, float skyLight,
                 float NdotL, float material) {
    float dist = length(playerPos.xz);
    // Beyond the shadow map there is no occluder data — fade to fully lit so the
    // far LODs don't snap dark at the shadow-distance boundary.
    float coverage = 1.0 - smoothstep(shadowDistance * 0.85, shadowDistance, dist);
    if (coverage <= 0.0) return vec3(1.0);

    // Match getShadow()'s bounded normal/voxel-edge bias.  The previous DH bias
    // grew by 0.05 blocks per block of distance (5+ whole blocks at LOD range),
    // moving the receiver off its real surface and causing pervasive light leaks.
    float playerDist = length(playerPos);
    vec3 bias = 0.25 * worldNormal
              * clamp(0.12 + 0.01 * playerDist, 0.0, 1.0)
              * (2.0 - clamp(NdotL, 0.0, 1.0));
    vec3 edge = (0.1 - 0.2 * fract(playerPos + cameraPosition + worldNormal * 0.01))
              * (1.0 - skyLight);
    vec4 shadowPos = toShadowSpace(vec4(playerPos + bias + edge, 1.0));
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 ||
        shadowPos.y < 0.0 || shadowPos.y > 1.0 ||
        shadowPos.z < 0.0 || shadowPos.z > 1.0) return vec3(1.0);

    float resScale = 4096.0 / float(shadowMapResolution);
    float receiverDepth = shadowPos.z - 0.00006 * resScale;
    if (material > 0.16 && material < 0.83) receiverDepth -= 0.000175;

    float s0 = dhShadow2D(shadowtex0, shadowPos.xy, receiverDepth);
    float s1 = dhShadow2D(shadowtex1, shadowPos.xy, receiverDepth);
    vec3 col = texture(shadowcolor0, shadowPos.xy).rgb;
    vec3 shadow = mix(col * s1, vec3(1.0), s0);

    return mix(vec3(1.0), shadow, coverage);
}

// Lightmap ambient: torch glow (suppressed in open daylight, like getLightmap in
// d7) + sky-tint ambient. lm = vanilla lightmap (.x torch, .y sky).
vec3 dhLightmap(vec2 lm, vec3 ambientColor, vec3 sunVec, vec3 upVec) {
    float torch = pow(lm.x, 5.06);
    float sunUp = clamp(dot(sunVec, upVec), 0.0, 1.0);
    float skyExposure = smoothstep(0.75, 0.9, lm.y);
    float blocklightSuppression = mix(1.0, 0.05, sunUp * skyExposure);

    vec3 torchLighting = torch * torchColor * blocklightSuppression;
    vec3 skyLighting   = lm.y * ambientColor;
    return torchLighting + skyLighting;
}

#endif // DH_LIGHTING_GLSL
