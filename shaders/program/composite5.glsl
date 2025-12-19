/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"


// Query's AWESOME LUTs
// LUT DEFAULT SHOULD BE 2
#define Lut_Set                     1           //[1] // technically there should be a 2 for raspberry but ill keep it off for now :3


#define Overworld_Lut                5          //[0 1 2 3 4 5 6 7 8 9]
#define Nether_Lut                2          //[0 1 2 3 4 5 6 7 8 9]
#define End_Lut                 1          //[0 1 2 3 4 5 6 7 8 9]

#define GBPreset 18 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32]

const float eyeBrightnessHalflife = 1.0f;

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


vec3 AcesTonemap(vec3 color) {
    // === Adjustable parameters ===

    float exposure = 0.35;   // >1.0 = brighter, <1.0 = darker
    float saturation = 1.0; // >1.0 = more vibrant, <1.0 = more gray
    float gamma = 2.2;      // sRGB standard gamma
    float contrast = 0.998;   // >1.0 = higher contrast, <1.0 = flatter

    color *= exposure;

    const mat3 m1 = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777
    );
    const mat3 m2 = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602
    );

    vec3 v = m1 * color;
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    vec3 tonemapped = m2 * (a / b);

    float luminance = dot(tonemapped, vec3(0.2126, 0.7152, 0.0722));
    tonemapped = mix(vec3(luminance), tonemapped, saturation);

    tonemapped = mix(vec3(0.5), tonemapped, contrast);

    return pow(clamp(tonemapped, 0.0, 1.0), vec3(1.0 / gamma));
}

vec3 Uchimura(vec3 x, float P, float a, float m, float l, float c, float b) {
    // Uchimura 2017, "HDR theory and practice"
    // Math: https://www.desmos.com/calculator/gslcdxvipg
    // Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    vec3 w0 = vec3(1.0) - smoothstep(vec3(0.0), vec3(m), x);
    vec3 w2 = step(vec3(m + l0), x);
    vec3 w1 = vec3(1.0) - w0 - w2;

    vec3 T = m * pow(x / m, vec3(c)) + b;
    vec3 S = P - (P - S1) * exp(CP * (x - S0));
    vec3 L = m + a * (x - m);

    return T * w0 + L * w1 + S * w2;
}

vec3 Tonemap_Uchimura(vec3 color) {
    const float P = 1.0;  // max display brightness
    const float a = 0.5;  // contrast
    const float m = 0.22; // linear section start
    const float l = 0.4;  // linear section length
    const float c = 1.22; // black
    const float b = 0.0;  // pedestal
    return Uchimura(color, P, a, m, l, c, b);
}

vec3 Tonemap_Lottes(vec3 x) {
    // Lottes 2016, "Advanced Techniques and Optimization of HDR Color Pipelines"
    const float exposure = 0.7; // Exposure multiplier - Higher values brighten the image, lower values darken it
    const float a = 1.0;        // Contrast - Higher values increase contrast in highlights
    const float d = 0.977;      // Toe adjustment - Controls the curve in dark regions (closer to 1.0 = harder toe)
    const float hdrMax = 8.0;   // Maximum HDR input value - Defines the upper limit of the HDR range
    const float midIn = 0.18;   // Input middle grey - The HDR value that represents middle grey (18% grey)
    const float midOut = 0.267; // Output middle grey - Where middle grey maps to in the output (controls overall brightness)
    

    // Apply exposure
    x *= exposure;

    // Can be precomputed
    const float b =
        (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
    const float c =
        (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

    return pow(x, vec3(a)) / (pow(x, vec3(a * d)) * b + c);
}

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

        #ifdef NETHER
        bloomStrength *= 0.1;
        #endif

        #ifdef END
        bloomStrength *= 0.5;
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

#include "/lib/antialiasing/autoExposure.glsl"

//Program//
void main() {
    /*#if defined TAA
        // The viewport is CENTERED on screen
        // Full screen UV (0,1) needs to map to centered viewport
        
        // For RENDER_SCALE = 0.5:
        // The viewport goes from 0.25 to 0.75 (centered)
        
        // Transform: scale around center point (0.5, 0.5)
        vec2 scaledUV = (texCoord) * RENDER_SCALE;
        
        vec3 color = texture2D(colortex0, scaledUV).rgb;
    #else*/
        vec3 color = texelFetch(colortex0, texelCoord, 0).rgb;
    //=#endif

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = texCoord * view;

    // Calculate noise and sample texture
    float noise = (fract(sin(dot(texCoord * sin(frameTimeCounter) + 1.0, vec2(12.9898,78.233) * 2.0)) * 43758.5453));

    #define FILM_GRAIN_I 2  // [0 1 2 3 4 5 6 7 8 9 10]
    
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

    vec2 scaledDither = texCoord;
    float dither = texture2D(noisetex, scaledDither * view / 128.0).b;
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

    //float filmGrain = dither;
    //color += vec3((filmGrain - 0.25) / 128.0);

    //DoBSLTonemap(color);
    float ignored = dot(color * vec3(0.15, 0.50, 0.35), vec3(0.1, 0.65, 0.6));
    float desaturated = dot(color, vec3(0.15, 0.50, 0.35));
    color = mix(color, vec3(ignored), exp2((-32) * desaturated));

     // Get auto exposure value (reads from colortex4)
    float exposure = GetAutoExposure(colortex0, dither);
    
    // Apply exposure
    #ifdef OVERWORLD
    color = ApplyExposure(color, exposure);
    #elif defined NETHER
        color *= 1.5;
    #endif

    color = Tonemap_Lottes(color);

    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luminance), color, 0.9);

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

    if (gl_FragCoord.x < 0.5 && gl_FragCoord.y < 0.5) {
        /* DRAWBUFFERS:34 */
        gl_FragData[1] = vec4(0.0, exposure, 0.0, 1.0);
    }
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
