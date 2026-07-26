#ifdef VERTEX

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"
#include "/lib/util/common.glsl"
#include "/lib/post/bloom.glsl"

in vec2 texCoord;

float getEdgeFade(vec2 uv) {
    vec2 window = smoothstep(vec2(0.0), vec2(0.12), uv) * smoothstep(vec2(1.0), vec2(0.88), uv);
    return window.x * window.y;
}

vec3 sampleBloomTileThreshold(vec2 uv, int index) {
    #ifdef LENS_FLARE_THRESHOLD
    float threshold = LENS_FLARE_THRESHOLD;
    #else
    float threshold = 0.5;
    #endif
    
    // Scale down threshold for blurrier LODs because light energy spreads out
    float currentThreshold = threshold * exp2(-float(index) * 0.5);
    
    vec2 rescale = bloomAtlasRescale();
    vec3 bloom = SampleBloomTile(colortex3, bloomTileLods[index], bloomTileOffsets[index], uv, rescale);
    
    // Convert to linear luminance
    float luma = dot(bloom, vec3(0.2126, 0.7152, 0.0722));
    float weight = smoothstep(currentThreshold, currentThreshold * 2.0, luma);
    weight = pow(weight, 2.0); // Suppress lower values aggressively
    return bloom * weight;
}

vec3 calculateStreak(vec2 uv) {
    vec2 dir = vec2(1.0, 0.0); 
    vec3 streak = vec3(0.0);
    
    int taps = 16;
    float stepSize = 0.015; // Wider step size to cover same distance with fewer taps
    float dither = fract(sin(dot(uv, vec2(78.233, 12.9898))) * 43758.5453);
    
    for (int i = 1; i <= taps; i++) {
        float dist = (float(i) - 0.5 + dither) * stepSize;
        
        float distNorm = float(i) / float(taps);
        // Exponential decay for a natural, gradual fade
        float weight = max(0.0, exp(-distNorm * 4.0) - exp(-4.0));
        
        int lod = (i <= 6) ? 1 : 2; // Fall back to blurrier LOD to fill the larger gaps seamlessly
        
        streak += sampleBloomTileThreshold(uv + dir * dist, lod) * weight;
        streak += sampleBloomTileThreshold(uv - dir * dist, lod) * weight;
    }
    
    streak /= float(taps) * 0.4;
    
    vec3 streakTint = vec3(0.2, 0.5, 1.0);
    return streak * streakTint * 2.5;
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 getGhost(vec2 uv, float S, int lod, vec3 tint, float ca) {
    vec2 C = vec2(0.5);
    vec2 offset = C + (uv - C) / S;
    float fade = getEdgeFade(offset);
    
    vec2 dir = C - uv;
    dir.x /= aspectRatio;
    vec2 uvDir = normalize(dir);
    
    vec3 ghost;
    ghost.r = sampleBloomTileThreshold(offset + uvDir * ca, lod).r;
    ghost.g = sampleBloomTileThreshold(offset, lod).g;
    ghost.b = sampleBloomTileThreshold(offset - uvDir * ca, lod).b;
    
    return ghost * tint * fade;
}

vec3 calculateGhosts(vec2 uv) {
    vec3 color = vec3(0.0);
    float ca = 0.002; // Tiny offset just for subtle chromatic edges
    
    const float scales[14] = float[](-0.5, -1.0, -1.5, -2.0, -2.5, -3.0, 0.3, 0.6, 0.9, 1.2, 1.6, 2.0, 2.5, 3.0);
    
    for (int i = 0; i < 14; i++) {
        float S = scales[i];
        
        // Pseudo-random properties based on index
        float seed = float(i + 1);
        int lod = 2 + int(fract(sin(seed * 12.9898) * 43758.5453) * 3.0); // LOD 2 to 4
        
        // Distinct rainbow hues for each ghost along the stride
        float hue = fract(float(i) * 0.15 + 0.3);
        vec3 tint = hsv2rgb(vec3(hue, 0.6, 1.0));
        
        float intensity = 0.3 + 0.3 * fract(sin(seed * 93.989) * 43758.5453);
        
        color += getGhost(uv, S, lod, tint, ca) * intensity;
    }
    
    return color * 0.6;
}

vec3 calculateHalo(vec2 uv) {
    vec2 C = vec2(0.5);
    vec2 ghostVec = C - uv;
    
    // Make the halos elliptical so they adjust in shape based on angle
    vec2 ellipticalVec = ghostVec;
    ellipticalVec.x *= aspectRatio * 0.75; 
    float distToCenter = length(ellipticalVec);
    
    if (distToCenter < 0.001) return vec3(0.0);
    
    // Calculate global halo scale based on the sun/moon's position
    // This allows the halos to dynamically grow/shrink as the main light source changes angle!
    vec4 projectedSun = gbufferProjection * vec4(sunPosition, 1.0);
    vec2 sunScreenPos = (projectedSun.xy / projectedSun.w) * 0.5 + 0.5;
    float sunDist = length(sunScreenPos - C);
    float dynamicScale = 1.0 + min(sunDist, 1.5) * 0.8; // Halos grow up to 120% larger when light is off-axis
    
    vec3 totalHalo = vec3(0.0);
    
    // Halo 1 (Main Ring)
    float S1 = -1.0;
    vec2 offset1 = C + ghostVec / S1;
    vec3 halo1 = sampleBloomTileThreshold(offset1, 4);
    float r1 = 0.35 * dynamicScale;
    float t1 = 0.03 * dynamicScale;
    float norm1 = clamp((distToCenter - (r1 - t1)) / (t1 * 2.0), 0.0, 1.0);
    vec3 tint1 = hsv2rgb(vec3(norm1 * 0.8, 0.8, 1.0)); // Single smooth rainbow gradient
    float w1 = smoothstep(t1, 0.0, abs(distToCenter - r1));
    totalHalo += halo1 * tint1 * w1 * getEdgeFade(offset1) * 3.0;

    // Halo 2 (Wider, outer ring)
    float S2 = -0.6;
    vec2 offset2 = C + ghostVec / S2;
    vec3 halo2 = sampleBloomTileThreshold(offset2, 3);
    float r2 = 0.55 * dynamicScale;
    float t2 = 0.05 * dynamicScale;
    float norm2 = clamp((distToCenter - (r2 - t2)) / (t2 * 2.0), 0.0, 1.0);
    vec3 tint2 = hsv2rgb(vec3(norm2 * 0.7 + 0.3, 0.7, 1.0));
    float w2 = smoothstep(t2, 0.0, abs(distToCenter - r2));
    totalHalo += halo2 * tint2 * w2 * getEdgeFade(offset2) * 1.5;

    // Halo 3 (Tighter, inner ring)
    float S3 = -1.8;
    vec2 offset3 = C + ghostVec / S3;
    vec3 halo3 = sampleBloomTileThreshold(offset3, 4);
    float r3 = 0.20 * dynamicScale;
    float t3 = 0.02 * dynamicScale;
    float norm3 = clamp((distToCenter - (r3 - t3)) / (t3 * 2.0), 0.0, 1.0);
    vec3 tint3 = hsv2rgb(vec3(norm3 * 0.9 + 0.1, 0.9, 1.0));
    float w3 = smoothstep(t3, 0.0, abs(distToCenter - r3));
    totalHalo += halo3 * tint3 * w3 * getEdgeFade(offset3) * 2.0;
    
    // Add scratchy noise to all halos
    float angle = atan(ghostVec.y, ghostVec.x * aspectRatio);
    float noise = fract(sin(angle * 50.0) * 43758.5453) * 0.5 + 
                  fract(sin(angle * 200.0) * 43758.5453) * 0.5;
                  
    totalHalo *= (0.3 + 0.7 * noise);
    
    return totalHalo;
}

vec3 calculateStarburst(vec2 uv) {
    vec3 star = vec3(0.0);
    
    int numSpikes = 4; // 8-point star (4 axes)
    int numTaps = 12; // Halved tap count for massive performance gain
    float stepSize = 0.015; // Doubled step size to maintain long spike length
    
    float dither = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
    
    for (int s = 0; s < numSpikes; s++) {
        float angle = (PI * float(s) / 4.0) + 0.15;
        vec2 dir = vec2(cos(angle) / aspectRatio, sin(angle));
        
        vec3 lineBloom = vec3(0.0);
        
        for (int i = 1; i <= numTaps; i++) {
            float dist = (float(i) - 0.5 + dither) * stepSize;
            
            // Shifted LODs to blurrier mipmaps to perfectly cover the larger step size gap
            int lod = (i <= 4) ? 1 : 2;
            
            float distNorm = float(i) / float(numTaps);
            // Exponential decay for a natural, gradual fade
            float weight = max(0.0, exp(-distNorm * 5.0) - exp(-5.0));
            
            lineBloom += sampleBloomTileThreshold(uv + dir * dist, lod) * weight;
            lineBloom += sampleBloomTileThreshold(uv - dir * dist, lod) * weight;
        }
        
        float spikeIntensity = (s % 2 == 0) ? 1.0 : 0.4;
        star += lineBloom * spikeIntensity;
    }
    
    star /= float(numTaps) * 0.4; 
    
    vec3 starTint = vec3(1.0, 0.9, 0.7);
    return star * starTint * 2.5; 
}

void main() {
    #ifdef CHROMATIC_ABERRATION
        vec2 C = vec2(0.5);
        vec2 d = texCoord - C;
        
        // Squared distance for physically accurate edge-heavy distortion
        float r2 = dot(d, d); 
        
        // Fancy Niche Effect: Anamorphic CA. 
        // It fringes more aggressively on the horizontal axis than the vertical axis, simulating a cinema lens.
        vec2 caOffset = d * r2 * vec2(0.015, 0.005) * 1.0 * CHROMATIC_ABERRATION_STRENGTH;
        
        // Extremely lightweight: 3 taps total.
        float r = texture(colortex0, texCoord - caOffset).r;
        vec4 g_a = texture(colortex0, texCoord); // Green and Alpha (autoExposure)
        float b = texture(colortex0, texCoord + caOffset).b;
        
        vec4 sceneColor = vec4(r, g_a.g, b, g_a.a);
    #else
        vec4 sceneColor = texture(colortex0, texCoord);
    #endif

    #if defined(LENS_FLARE_STREAK) || defined(LENS_FLARE_GHOSTS) || defined(LENS_FLARE_HALO) || defined(LENS_FLARE_STARBURST)
    vec3 flareColor = vec3(0.0);
    float strength = LENS_FLARE_STRENGTH * 1.5;

    // We only calculate flares if there are bright enough pixels
    // Since we can't easily skip pixels in a screen-space convolution without artefacts, 
    // we evaluate it globally but the threshold inside the sampler keeps it clean.
    if (strength > 0.0) {
        #ifdef LENS_FLARE_STREAK
        flareColor += calculateStreak(texCoord) * LENS_FLARE_STREAK_STRENGTH;
        #endif

        #ifdef LENS_FLARE_GHOSTS
        flareColor += calculateGhosts(texCoord) * LENS_FLARE_GHOSTS_STRENGTH;
        #endif

        #ifdef LENS_FLARE_HALO
        flareColor += calculateHalo(texCoord) * LENS_FLARE_HALO_STRENGTH;
        #endif

        #ifdef LENS_FLARE_STARBURST
        flareColor += calculateStarburst(texCoord) * LENS_FLARE_STARBURST_STRENGTH;
        #endif

        #ifdef AUTO_EXPOSURE
        float autoExposure = texelFetch(colortex0, ivec2(0), 0).a;
        if (autoExposure > 0.001 && !isnan(autoExposure) && !isinf(autoExposure)) {
            // Counteract auto-exposure darkening so the flare remains blinding when looking at the sun
            float exposureBoost = max(1.0, 1.0 / autoExposure);
            flareColor *= pow(exposureBoost, 0.75); 
        }
        #endif

        sceneColor.rgb += flareColor * strength;
    }
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = sceneColor;
}

#endif
