#ifdef VERTEX

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FRAGMENT

#include "/lib/options.glsl"

in vec2 texCoord;

// LUT code/asset credit: Query. Ported from Luts2.png color-grading path.
void applyLookupTable(inout vec3 color) {
    const vec2 inverseSize = vec2(1.0 / 512.0, 1.0 / 5120.0);

    const mat2 correctGrid = mat2(
        vec2(1.0, inverseSize.y * 512.0),
        vec2(0.0, float(OVERWORLD_LUT) * inverseSize.y * 512.0)
    );

    vec3 originalColor = color;
    color = clamp(color, 0.0, 1.0);

    float blueColor = color.b * 63.0;

    vec4 quad = vec4(0.0);
    quad.y = floor(floor(blueColor) * 0.125);
    quad.x = floor(blueColor) - (quad.y * 8.0);
    quad.w = floor(ceil(blueColor) * 0.125);
    quad.z = ceil(blueColor) - (quad.w * 8.0);

    vec4 texPos = (quad * 0.125) + (0.123046875 * color.rg).xyxy + 0.0009765625;

    vec3 lutColor1 = texture(colortex6, texPos.xy * correctGrid[0] + correctGrid[1]).rgb;
    vec3 lutColor2 = texture(colortex6, texPos.zw * correctGrid[0] + correctGrid[1]).rgb;
    vec3 lutColor = mix(lutColor1, lutColor2, fract(blueColor));

    color = mix(originalColor, lutColor, OVERWORLD_LUT_I);
}

#include "/lib/util/common.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/post/tonemap.glsl"
#include "/lib/post/sharpen.glsl"

void main() {
    #if defined(TAA) && TAA_SHARPNESS > 0.0
    vec4 sceneColor = vec4(casSharpen(colortex0, texCoord, vec2(viewWidth, viewHeight), TAA_SHARPNESS), texture(colortex0, texCoord).a);
    #else
    vec4 sceneColor = texture(colortex0, texCoord);
    #endif

    // Film grain moved to the end of the post-processing chain for advanced simulation

    vec3 color = sceneColor.rgb;

    float totalExposure = EXPOSURE;
    #ifdef AUTO_EXPOSURE
    float autoExposure = texelFetch(colortex0, ivec2(0), 0).a;
    if (autoExposure > 0.001 && !isnan(autoExposure) && !isinf(autoExposure)) {
        totalExposure *= autoExposure;
    }
    #endif

    color *= totalExposure;

    #ifdef BLOOM
    vec3 bloomColor = ReadBloomAtlas(colortex3, texCoord) * totalExposure;
    color = mix(color, bloomColor, BLOOM_STRENGTH);
    
    #ifdef HALATION
        // Extract the brightest parts of the bloom for halation (red/orange film bleed)
        vec3 halationColor = pow(bloomColor, vec3(1.5)) * vec3(1.0, 0.2, 0.05);
        color += halationColor * HALATION_STRENGTH;
    #endif
    #endif

    vec3 tempShift = vec3(1.0);
    if (COLOR_TEMP > 0.0) {
        tempShift = vec3(1.0 + COLOR_TEMP * 0.25, 1.0 + COLOR_TEMP * 0.08, 1.0 - COLOR_TEMP * 0.25);
    } else {
        tempShift = vec3(1.0 + COLOR_TEMP * 0.25, 1.0 + COLOR_TEMP * 0.08, 1.0 - COLOR_TEMP * 0.35);
    }
    color = clamp(color * tempShift, 0.0, 10.0);

    #ifdef VIGNETTE
    vec2 vignCoord = texCoord * (1.0 - texCoord.yx);
    float vign = vignCoord.x * vignCoord.y * 15.0;
    vign = clamp(pow(vign, 0.25), 0.0, 1.0);
    color *= vign;
    #endif

    color = applyTonemap(color);

    color = clamp((color - vec3(0.5)) * COLOR_CONTRAST + vec3(0.5), 0.0, 1.0);

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = clamp(mix(vec3(luma), color, COLOR_SATURATION), 0.0, 1.0);

    #ifdef SPLIT_TONING
        // Cinematic Teal & Orange split-toning
        float splitMask = smoothstep(0.2, 0.8, luma);
        
        vec3 shadowTint = vec3(0.5, 0.8, 1.0); // Deep Teal
        vec3 highlightTint = vec3(1.0, 0.8, 0.5); // Warm Orange
        
        vec3 targetTint = mix(shadowTint, highlightTint, splitMask);
        vec3 splitColor = color * targetTint;
        
        // Preserve original luminance so the image doesn't darken/brighten
        float splitLuma = dot(splitColor, vec3(0.2126, 0.7152, 0.0722));
        splitColor *= luma / max(splitLuma, 1e-5);
        
        color = mix(color, clamp(splitColor, 0.0, 1.0), SPLIT_TONING_STRENGTH);
    #endif

    #ifdef PURKINJE_EFFECT
        // The darker the scene, the higher autoExposure gets. 
        // We use this to detect if the player is in a dark environment (e.g. night or deep cave).
        #ifdef AUTO_EXPOSURE
            float ambientDarkness = clamp((autoExposure - 1.0) / 4.0, 0.0, 1.0); 
        #else
            float ambientDarkness = 0.5; 
        #endif
        
        // Only affect the darker tones of the image, scaled by how dark the environment is
        float purkinjeMask = clamp(1.0 - (luma * 8.0), 0.0, 1.0) * ambientDarkness;
        
        // Scotopic vision (cyan/blue shift, desaturated)
        float scotopicLuma = dot(color, vec3(0.1, 0.5, 0.4)); // Human eye is most sensitive to green/blue at night
        vec3 scotopicColor = vec3(0.1, 0.35, 0.5) * scotopicLuma * 2.5; 
        
        color = mix(color, scotopicColor, purkinjeMask * PURKINJE_STRENGTH);
    #endif

    color = pow(color, vec3(1.0 / 2.09));

    if (OVERWORLD_LUT_I > 0.0) {
        applyLookupTable(color);
    }

    #if FILM_GRAIN_I > 0
        // Advanced 35mm Film Grain Simulation
        float noise = fract(sin(dot((texCoord * RENDER_SCALE) * sin(frameTimeCounter) + 1.0, vec2(12.9898, 78.233) * 2.0)) * 43758.5453);
        noise = noise - 0.5; // shift to -0.5 .. 0.5
        
        // Grain is strongest in midtones, and vanishes in pure black or pure white (physically accurate film stock)
        float finalLuma = dot(color, vec3(0.2126, 0.7152, 0.0722));
        float grainWeight = 1.0 - abs(finalLuma - 0.5) * 2.0; 
        grainWeight = smoothstep(0.0, 1.0, grainWeight);
        
        color += noise * grainWeight * (float(FILM_GRAIN_I) / 20.0);
    #endif

    color += vec3(dither) / 255.0;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(clamp(color, 0.0, 1.0), 1.0);
}

#endif
