/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"


// Query's AWESOME LUTs
// LUT DEFAULT SHOULD BE 2
#define Lut_Set                     1           //[1] // technically there should be a 2 for raspberry but ill keep it off for now :3
    #define Overworld_Lut                5          //[0 1 2 3 4 5 6 7 8 9]
    #define Nether_Lut                8          //[0 1 2 3 4 5 6 7 8 9]
    #define End_Lut                 1          //[0 1 2 3 4 5 6 7 8 9]
    #define GBPreset 18 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32]

#define TONEMAP
#define EXPOSURE 1.0
#define SATURATION 1.0
#define CONTRAST 0.999
#define GAMMA 2.2
#define BLACK_DEPTH 0.0001
#define WHITE_CLIP 1.0
#define DESATURATION_AMOUNT 0.35

#define RESATURATION_SATURATION 1.0    // Base saturation multiplier
#define RESATURATION_CONTRAST 1.0      // Contrast multiplier for resaturation step
#define RESATURATION_DESATURATION_AMOUNT 0.35

//#define PURKINJE
#define MIN_EXPOSURE     0.1    // darkest allowed exposure
#define BASE_EXPOSURE    1.0    // base exposure multiplier (normal brightness)
#define MAX_EXPOSURE     5.0    // brightest allowed exposure
#define EXPOSURE_CURVE   0.8    // curve < 1.0 brightens dark scenes more

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

#if defined BLOOM_FOG || LENSFLARE_MODE > 0 && defined OVERWORLD
    flat in vec3 upVec, sunVec;
#endif

//Pipeline Constants//

//Common Variables//
float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

vec2 view = vec2(viewWidth, viewHeight);

#if defined BLOOM_FOG || LENSFLARE_MODE > 0 && defined OVERWORLD
    float SdotU = dot(sunVec, upVec);
    float sunFactor = SdotU < 0.0 ? clamp(SdotU + 0.375, 0.0, 0.75) / 0.75 : clamp(SdotU + 0.03125, 0.0, 0.0625) / 0.0625;
#endif

//Common Functions//
void DoBSLTonemap(inout vec3 color) {
    color = T_EXPOSURE * color;
    color = color / pow(pow(color, vec3(TM_WHITE_CURVE)) + 1.0, vec3(1.0 / TM_WHITE_CURVE));
    color = pow(color, mix(vec3(T_LOWER_CURVE), vec3(T_UPPER_CURVE), sqrt(color)));

    color = pow(color, vec3(1.0 / 2.2));
}

void DoBSLColorSaturation(inout vec3 color) {
    float grayVibrance = (color.r + color.g + color.b) / 3.0;
    float graySaturation = grayVibrance;
    if (T_SATURATION < 1.00) graySaturation = dot(color, vec3(0.299, 0.587, 0.114));

    float mn = min(color.r, min(color.g, color.b));
    float mx = max(color.r, max(color.g, color.b));
    float sat = (1.0 - (mx - mn)) * (1.0 - mx) * grayVibrance * 5.0;
    vec3 lightness = vec3((mn + mx) * 0.5);

    color = mix(color, mix(color, lightness, 1.0 - T_VIBRANCE), sat);
    color = mix(color, lightness, (1.0 - lightness) * (2.0 - T_VIBRANCE) / 2.0 * abs(T_VIBRANCE - 1.0));
    color = color * T_SATURATION - graySaturation * (T_SATURATION - 1.0);
}

float getSceneBrightness() {
    float skyLight = clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.01, 1.0);
    return pow(skyLight, 0.25); // lower = more sensitive to darkness
}

float getAverageSceneBrightness() {
    vec3 color = textureLod(colortex0, vec2(0.5), 8).rgb;
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    luminance = max(luminance, 0.0001); // avoid log(0)

    // Parameters to adjust range — tweak these to increase range sensitivity
    float exposureMin = 0.0001;
    float exposureMax = 1.0;

    // Normalize luminance to [exposureMin, exposureMax] range, then remap [0..1]
    float normalizedLum = clamp((luminance - exposureMin) / (exposureMax - exposureMin), 0.0, 1.0);

    // Apply log average (simulate eye adaptation better)
    return exp(mix(log(exposureMin), log(exposureMax), normalizedLum));
}


vec3 applyPurkinjeEffect(vec3 color, float sceneBrightness) {
    // Shift strength based on how dark the scene is (1.0 = full daylight, 0.0 = full night)
    float shift = smoothstep(0.0, 0.6, 0.5 - sceneBrightness) * 0.5;

    // Adjust RGB channels to simulate scotopic vision
    vec3 purkinje = vec3(
        mix(1.0, 0.6, shift), // red dims
        mix(1.0, 0.8, shift), // green dims
        mix(1.0, 1.2, shift)  // blue boosts
    );

    return color * purkinje;
}

#ifdef TONEMAP
    int maxIdx(vec3 c, out float maxVal) {
        if(c.r > c.g && c.r > c.b) { maxVal = c.r; return 0; }
        else if(c.g > c.b) { maxVal = c.g; return 1; }
        maxVal = c.b; return 2;
    }

    // Helper to get min index and min value in vec3
    int minIdx(vec3 c, out float minVal) {
        if(c.r < c.g && c.r < c.b) { minVal = c.r; return 0; }
        else if(c.g < c.b) { minVal = c.g; return 1; }
        minVal = c.b; return 2;
    }

    float maxOf(vec3 c) {
        return max(max(c.r, c.g), c.b);
    }

    float minOf(vec3 c) {
        return min(min(c.r, c.g), c.b);
    }

    //float pow2(float x) { return x*x; }

    // ACES tonemap constants
    const mat3 ACESInputMat = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777
    );

    const mat3 ACESOutputMat = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108, 1.10813, -0.07276,
        -0.07367, -0.00605, 1.07602
    );

    // ACES approximation curve
    vec3 RRTAndODTFit(vec3 v)
    {
        vec3 a = v * (v + 0.0245786) - 0.000090537;
        vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
        return a / b;
    }

    vec3 ACESTonemap(vec3 color)
    {
        // Apply exposure and black offset
        #ifdef PURKINJE
            float sceneBrightness = getAverageSceneBrightness();
            vec3 purkinje = applyPurkinjeEffect(color, sceneBrightness);
            color = max(purkinje * EXPOSURE - BLACK_DEPTH, 0.0);
        #else
            color = max(color / getSceneBrightness() * EXPOSURE - BLACK_DEPTH, 0.0);
        #endif

        // Transform to ACES color space
        vec3 acesColor = ACESInputMat * color;

        // Apply the ACES RRT + ODT fit curve
        acesColor = RRTAndODTFit(acesColor);

        // Transform back to linear sRGB space
        acesColor = ACESOutputMat * acesColor;

        // Optional white clipping (clamp high values)
        if (WHITE_CLIP < 1.0) {
            acesColor = min(acesColor, vec3(WHITE_CLIP));
        }

        // Contrast adjustment: interpolate between middle gray and color
        acesColor = mix(vec3(0.5), acesColor, CONTRAST);

        // Saturation adjustment
        float luminance = dot(acesColor, vec3(0.2126, 0.7152, 0.0722));
        acesColor = mix(vec3(luminance), acesColor, SATURATION);

        // Clamp to [0,1] and apply gamma correction for display
        acesColor = pow(clamp(acesColor, 0.0, 1.0), vec3(1.0 / GAMMA));

        return acesColor;
    }

    // Tech's ResaturatedTonemap in shaderLabs #snippets channel
    vec3 ResaturatedTonemap(vec3 color)
    {
        // Find max and min channels and values
        float maxC; int maxI = maxIdx(color, maxC);
        float minC; int minI = minIdx(color, minC);
        int midI = 3 - (maxI + minI);
        float midC = color[midI];

        // Compute saturation target S (difference ratio)
        float S = (maxC - minC) / (maxC + 1e-5); 

        // Apply desaturation on very bright areas
        S *= 1.0 / sqrt(pow(maxC * RESATURATION_DESATURATION_AMOUNT, 2.0) + 1.0);

        // Calculate interpolation factor for mid channel
        float k = (midC - minC) / (maxC - minC + 1e-5);

        // Resaturate channels
        color[maxI] = maxC;
        color[minI] = (1.0 - S) * maxC;
        color[midI] = maxC * (1.0 - S * (1.0 - k));

        // Apply saturation multiplier (blend between grayscale and resaturated color)
        float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
        color = mix(vec3(luminance), color, RESATURATION_SATURATION);

        // Apply contrast adjustment around middle gray (0.5)
        color = mix(vec3(0.5), color, RESATURATION_CONTRAST);

        // Clamp result to valid color range
        return clamp(color, 0.0, 1.0);
    }
#endif

#define clamp01(x) clamp(x, 0.0, 1.0)

// thanks to Query's for their AWESOME LUTs

void OverworldLookup(inout vec3 color) {
    const vec2 inverseSize = vec2(1.0 / 512, 1.0 / 5120);

    const mat2 correctGrid = mat2(
            vec2(1.0, inverseSize.y * 512), vec2(0.0, Overworld_Lut * inverseSize.y * 512)
    );
    
    color = clamp01(color);

    float blueColor = color.b * 63.0;

    vec4 quad = vec4(0.0);
    quad.y = floor(floor(blueColor) * 0.125);
    quad.x = floor(blueColor) - (quad.y * 8.0);
    quad.w = floor(ceil(blueColor) * 0.125);
    quad.z = ceil(blueColor) - (quad.w * 8.0);

    vec4 texPos = (quad * 0.125) + (0.123046875 * color.rg).xyxy + 0.0009765625;

    vec3 newColor1, newColor2;
    
    #if Lut_Set == 1
    newColor1 = texture2D(colortex7, texPos.xy * correctGrid[0] + correctGrid[1]).rgb;
    newColor2 = texture2D(colortex7, texPos.zw * correctGrid[0] + correctGrid[1]).rgb;
    #elif Lut_Set == 2
    newColor1 = texture2D(colortex8, texPos.xy * correctGrid[0] + correctGrid[1]).rgb;
    newColor2 = texture2D(colortex8, texPos.zw * correctGrid[0] + correctGrid[1]).rgb;
    #endif

    //#if Overworld_Lut == 2
    
    
    color = mix(newColor1, newColor2, fract(blueColor));
}

void NetherLookup(inout vec3 color) {
    const vec2 inverseSize = vec2(1.0 / 512, 1.0 / 5120);

    const mat2 correctGrid = mat2(
            vec2(1.0, inverseSize.y * 512), vec2(0.0, Nether_Lut * inverseSize.y * 512)
    );
    
    color = clamp01(color);

    float blueColor = color.b * 63.0;

    vec4 quad = vec4(0.0);
    quad.y = floor(floor(blueColor) * 0.125);
    quad.x = floor(blueColor) - (quad.y * 8.0);
    quad.w = floor(ceil(blueColor) * 0.125);
    quad.z = ceil(blueColor) - (quad.w * 8.0);

    vec4 texPos = (quad * 0.125) + (0.123046875 * color.rg).xyxy + 0.0009765625;

    vec3 newColor1, newColor2;
    
    #if Lut_Set == 1
    newColor1 = texture2D(colortex7, texPos.xy * correctGrid[0] + correctGrid[1]).rgb;
    newColor2 = texture2D(colortex7, texPos.zw * correctGrid[0] + correctGrid[1]).rgb;
    #elif Lut_Set == 2
    newColor1 = texture2D(colortex8, texPos.xy * correctGrid[0] + correctGrid[1]).rgb;
    newColor2 = texture2D(colortex8, texPos.zw * correctGrid[0] + correctGrid[1]).rgb;
    #endif
    
    color = mix(newColor1, newColor2, fract(blueColor));
}

void EndLookup(inout vec3 color) {
    const vec2 inverseSize = vec2(1.0 / 512, 1.0 / 5120);

    const mat2 correctGrid = mat2(
            vec2(1.0, inverseSize.y * 512), vec2(0.0, End_Lut * inverseSize.y * 512)
    );
    
    color = clamp01(color);

    float blueColor = color.b * 63.0;

    vec4 quad = vec4(0.0);
    quad.y = floor(floor(blueColor) * 0.125);
    quad.x = floor(blueColor) - (quad.y * 8.0);
    quad.w = floor(ceil(blueColor) * 0.125);
    quad.z = ceil(blueColor) - (quad.w * 8.0);

    vec4 texPos = (quad * 0.125) + (0.123046875 * color.rg).xyxy + 0.0009765625;

    vec3 newColor1, newColor2;
    
    #if Lut_Set == 1
    newColor1 = texture2D(colortex7, texPos.xy * correctGrid[0] + correctGrid[1]).rgb;
    newColor2 = texture2D(colortex7, texPos.zw * correctGrid[0] + correctGrid[1]).rgb;
    #elif Lut_Set == 2
    newColor1 = texture2D(colortex8, texPos.xy * correctGrid[0] + correctGrid[1]).rgb;
    newColor2 = texture2D(colortex8, texPos.zw * correctGrid[0] + correctGrid[1]).rgb;
    #endif
    
    color = mix(newColor1, newColor2, fract(blueColor));
}

#ifdef BLOOM
    vec2 rescale = max(vec2(viewWidth, viewHeight) / vec2(1920.0, 1080.0), vec2(1.0));
    vec3 GetBloomTile(float lod, vec2 coord, vec2 offset) {
        float scale = exp2(lod);
        vec2 bloomCoord = coord / scale + offset;
        bloomCoord = clamp(bloomCoord, offset, 1.0 / scale + offset);

        vec3 bloom = texture2D(colortex3, bloomCoord / rescale).rgb;
        bloom *= bloom;
        bloom *= bloom;
        
        return bloom * 128.0;
    }

    void DoBloom(inout vec3 color, vec2 coord, float dither, float lViewPos) {
        vec3 blur1 = GetBloomTile(2.0, coord, vec2(0.0      , 0.0   ));
        vec3 blur2 = GetBloomTile(3.0, coord, vec2(0.0      , 0.26  ));
        vec3 blur3 = GetBloomTile(4.0, coord, vec2(0.135    , 0.26  ));
        vec3 blur4 = GetBloomTile(5.0, coord, vec2(0.2075   , 0.26  ));
        vec3 blur5 = GetBloomTile(6.0, coord, vec2(0.135    , 0.3325));
        vec3 blur6 = GetBloomTile(7.0, coord, vec2(0.160625 , 0.3325));
        vec3 blur7 = GetBloomTile(8.0, coord, vec2(0.1784375, 0.3325));

        vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6 + blur7) * 0.14;

        float bloomStrength = BLOOM_STRENGTH + 0.2 * darknessFactor;

        #if defined BLOOM_FOG && defined NETHER && defined BORDER_FOG
            float farM = min(renderDistance, NETHER_VIEW_LIMIT); // consistency9023HFUE85JG
            float netherBloom = lViewPos / clamp(farM, 96.0, 256.0);
            netherBloom *= netherBloom;
            netherBloom *= netherBloom;
            netherBloom = 1.0 - exp(-8.0 * netherBloom);
            netherBloom *= 1.0 - maxBlindnessDarkness;
            bloomStrength = mix(bloomStrength * 0.7, bloomStrength * 1.8, netherBloom);
        #endif

        color = mix(color, blur, bloomStrength);
        //color = pow(color, vec3(2.2));
        //color += blur * bloomStrength * (ditherFactor.x + ditherFactor.y);
    }
#endif

//Includes//
#ifdef BLOOM_FOG
    #include "/lib/atmospherics/fog/bloomFog.glsl"
#endif

#ifdef BLOOM
    #include "/lib/util/dither.glsl"
#endif

#if LENSFLARE_MODE > 0 && defined OVERWORLD
    #include "/lib/misc/lensFlare.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = texCoord * view;

    // Calculate noise and sample texture
    float noise = (fract(sin(dot(texCoord * sin(frameTimeCounter) + 1.0, vec2(12.9898,78.233) * 2.0)) * 43758.5453));

    #define FILM_GRAIN_I 3  // [0 1 2 3 4 5 6 7 8 9 10]
    
    color.rgb *= max(noise, 1.0 - (float(FILM_GRAIN_I) / 10));
    color *= 1.3;

    #if defined BLOOM_FOG || LENSFLARE_MODE > 0 && defined OVERWORLD
        float z0 = texture2D(depthtex0, texCoord).r;

        vec4 screenPos = vec4(texCoord, z0, 1.0);
        vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
        viewPos /= viewPos.w;
        float lViewPos = length(viewPos.xyz);

        #if defined DISTANT_HORIZONS && defined NETHER
            float z0DH = texelFetch(dhDepthTex, texelCoord, 0).r;
            vec4 screenPosDH = vec4(texCoord, z0DH, 1.0);
            vec4 viewPosDH = dhProjectionInverse * (screenPosDH * 2.0 - 1.0);
            viewPosDH /= viewPosDH.w;
            lViewPos = min(lViewPos, length(viewPosDH.xyz));
        #endif
    #else
        float lViewPos = 0.0;
    #endif

    float dither = texture2D(noisetex, texCoord * view / 128.0).b;
    #ifdef TAA
        dither = fract(dither + goldenRatio * mod(float(frameCounter), 3600.0));
    #endif

    #ifdef BLOOM_FOG
        color /= GetBloomFog(lViewPos);
    #endif

    #ifdef BLOOM
        DoBloom(color, texCoord, dither, lViewPos);
    #endif

    #ifdef COLORGRADING
        color =
            pow(color.r, GR_RC) * vec3(GR_RR, GR_RG, GR_RB) +
            pow(color.g, GR_GC) * vec3(GR_GR, GR_GG, GR_GB) +
            pow(color.b, GR_BC) * vec3(GR_BR, GR_BG, GR_BB);
        color *= 0.01;
    #endif

    float filmGrain = dither;
    color += vec3((filmGrain - 0.25) / 128.0);

    //DoBSLTonemap(color);
    float ignored = dot(color * vec3(0.15, 0.50, 0.35), vec3(0.1, 0.65, 0.6));
    float desaturated = dot(color, vec3(0.15, 0.50, 0.35));
    color = mix(color, vec3(ignored), exp2((-64) * desaturated));

    #ifdef TONEMAP
        vec3 tonemappedColor = ACESTonemap(color);
        color = ResaturatedTonemap(tonemappedColor);
    #endif

    #if defined GREEN_SCREEN_LIME || SELECT_OUTLINE == 4
        int materialMaskInt = int(texelFetch(colortex6, texelCoord, 0).g * 255.1);
    #endif

    #ifdef GREEN_SCREEN_LIME
        if (materialMaskInt == 240) { // Green Screen Lime Blocks
            color = vec3(0.0, 1.0, 0.0);
        }
    #endif

    #if SELECT_OUTLINE == 4
        if (materialMaskInt == 252) { // Versatile Selection Outline
            float colorMF = 1.0 - dot(color, vec3(0.25, 0.45, 0.1));
            colorMF = smoothstep1(smoothstep1(smoothstep1(smoothstep1(smoothstep1(colorMF)))));
            color = mix(color, 3.0 * (color + 0.2) * vec3(colorMF * SELECT_OUTLINE_I), 0.3);
        }
    #endif

    #if LENSFLARE_MODE > 0 && defined OVERWORLD
        DoLensFlare(color, viewPos.xyz, dither);
    #endif

    #ifdef OVERWORLD
        OverworldLookup(color);
    #endif

    #ifdef NETHER
        NetherLookup(color);
    #endif

    #ifdef END
        EndLookup(color);
    #endif

    /* DRAWBUFFERS:3 */
    gl_FragData[0] = vec4(color, 1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

#if defined BLOOM_FOG || LENSFLARE_MODE > 0 && defined OVERWORLD
    flat out vec3 upVec, sunVec;
#endif

//Attributes//

//Common Variables//

//Common Functions//

//Includes//

//Program//
void main() {
    gl_Position = ftransform();

    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if defined BLOOM_FOG || LENSFLARE_MODE > 0 && defined OVERWORLD
        upVec = normalize(gbufferModelView[1].xyz);
        sunVec = GetSunVector();
    #endif
}

#endif
