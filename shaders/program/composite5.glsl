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

#define VIBRANCE 0.65 

// Per-hue saturation multipliers
#define SAT_RED      0.985
#define SAT_ORANGE   0.65
#define SAT_YELLOW   1.00
#define SAT_GREEN    1.2
#define SAT_CYAN     1.15
#define SAT_BLUE     1.1
#define SAT_MAGENTA  1.00

#define HUE_BAND_WIDTH   0.08
#define HUE_BAND_SOFT    2.00

#define TONEMAP
#define EXPOSURE 0.5 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define SATURATION 0.8 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define CONTRAST 0.999 //[0.985 0.986 0.987 0.988 0.989 0.990 0.991 0.992 0.993 0.994 0.995 0.996 0.997 0.998 0.999]
#define GAMMA 1.9 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define BLACK_DEPTH 0.00001
#define WHITE_CLIP 1.0
#define DESATURATION_AMOUNT 0.35

#define RESATURATION_SATURATION 1.0
#define RESATURATION_CONTRAST 1.0
#define RESATURATION_DESATURATION_AMOUNT 0.35

#define PURKINJE
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

float getAverageSceneBrightness() {
    vec3 color = textureLod(colortex0, vec2(0.5), 8).rgb;
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    luminance = max(luminance, 0.0001); // avoid log(0)

    float exposureMin = 0.0001;
    float exposureMax = 0.1;

    float normalizedLum = clamp((luminance - exposureMin) / (exposureMax - exposureMin), 0.0, 1.0);

    return exp(mix(log(exposureMin), log(exposureMax), normalizedLum));
}


vec3 applyPurkinjeEffect(vec3 color, float sceneBrightness) {
    float shift = smoothstep(0.0, 0.6, 0.5 - sceneBrightness) * 0.5;

    vec3 purkinje = vec3(
        mix(1.0, 0.6, shift),
        mix(1.0, 0.8, shift),
        mix(1.0, 1.2, shift) 
    );

    return color * purkinje;
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

vec3 ApplyVibrance(vec3 color, float vibranceAmount) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    vec3 diff = color - vec3(luma);

    return color + diff * vibranceAmount;
}

vec3 HableFilmic(vec3 x, float A, float B, float C, float D, float E, float F) {
    // ((x*(A*x + C*B) + D*E) / (x*(A*x + B) + D*F)) - E/F
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

float HableWhiteScale(float W, float A, float B, float C, float D, float E, float F) {
    float w = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;
    return 1.0 / max(w, 1e-6);
}

vec3 UnchartedTonemap(vec3 color) {

    #ifdef PURKINJE
        float sceneBrightness = getAverageSceneBrightness();
        vec3  purkinje       = applyPurkinjeEffect(color, sceneBrightness);
        color = max(purkinje * EXPOSURE - BLACK_DEPTH, 0.0);
    #else
        color = max(color / getAverageSceneBrightness() * EXPOSURE - BLACK_DEPTH, 0.0);
    #endif

    const float A = 0.22;
    const float B = 0.30;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.01;
    const float F = 0.30;

    const float W = 11.2;

    vec3  c      = HableFilmic(color, A, B, C, D, E, F);
    float whiteS = HableWhiteScale(W, A, B, C, D, E, F);
    c *= whiteS;

    if (WHITE_CLIP < 1.0) c = min(c, vec3(WHITE_CLIP));

    c = mix(vec3(0.5), c, CONTRAST);

    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(luma), c, SATURATION);

    c = pow(clamp(c, 0.0, 1.0), vec3(1.0 / GAMMA));

    return c;
}

float hueDist(float h, float center){
    float d = abs(h - center);
    return min(d, 1.0 - d);
}

float bandWeight(float h, float center, float width, float softness){
    float x = clamp(1.0 - pow(hueDist(h, center) / max(width, 1e-6), softness), 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}

const float H_RED     = 0.000;
const float H_ORANGE  = 0.083; 
const float H_YELLOW  = 0.167; 
const float H_GREEN   = 0.333; 
const float H_CYAN    = 0.500; 
const float H_BLUE    = 0.667;
const float H_MAGENTA = 0.833; 

vec3 BoostHueSaturationBands(vec3 rgb){
    vec3 hsv = rgb2hsv(rgb);
    float h  = hsv.x;
    float s  = hsv.y;

    float wR = bandWeight(h, H_RED,     HUE_BAND_WIDTH, HUE_BAND_SOFT);
    float wO = bandWeight(h, H_ORANGE,  HUE_BAND_WIDTH, HUE_BAND_SOFT);
    float wY = bandWeight(h, H_YELLOW,  HUE_BAND_WIDTH, HUE_BAND_SOFT);
    float wG = bandWeight(h, H_GREEN,   HUE_BAND_WIDTH, HUE_BAND_SOFT);
    float wC = bandWeight(h, H_CYAN,    HUE_BAND_WIDTH, HUE_BAND_SOFT);
    float wB = bandWeight(h, H_BLUE,    HUE_BAND_WIDTH, HUE_BAND_SOFT);
    float wM = bandWeight(h, H_MAGENTA, HUE_BAND_WIDTH, HUE_BAND_SOFT);

    float totalW = wR + wO + wY + wG + wC + wB + wM;
    float blendedMul = 1.0;
    if (totalW > 1e-3) {
        blendedMul =
            (wR * SAT_RED +
             wO * SAT_ORANGE +
             wY * SAT_YELLOW +
             wG * SAT_GREEN +
             wC * SAT_CYAN +
             wB * SAT_BLUE +
             wM * SAT_MAGENTA) / totalW;
    }

    if (s > 0.05) {
        float boosted = clamp(s * blendedMul, 0.0, 1.0);
        hsv.y = mix(s, boosted, s);
    }

    return hsv2rgb(hsv);
}

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = texCoord * view;

    // Calculate noise and sample texture
    float noise = (fract(sin(dot(texCoord * sin(frameTimeCounter) + 1.0, vec2(12.9898,78.233) * 2.0)) * 43758.5453));

    #define FILM_GRAIN_I 0  // [0 1 2 3 4 5 6 7 8 9 10]
    
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

    float ignored = dot(color * vec3(0.15, 0.50, 0.35), vec3(0.1, 0.65, 0.6));
    float desaturated = dot(color, vec3(0.15, 0.50, 0.35));
    color = mix(color, vec3(ignored), exp2((-32.0) * desaturated));

    #ifdef TONEMAP
        //vec3 tonemappedColor = ACESTonemap(color);
        //color = ResaturatedTonemap(tonemappedColor);
        color = UnchartedTonemap(color);
        color = ApplyVibrance(color, VIBRANCE);
        color = BoostHueSaturationBands(color);
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

    float filmGrain = dither;
    //color += vec3((filmGrain - 0.25) / 128.0);

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
