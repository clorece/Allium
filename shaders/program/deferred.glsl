/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////
//Common//
#include "/lib/common.glsl"
//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER
noperspective in vec2 texCoord;
flat in vec3 upVec, sunVec;
//Pipeline Constants//
//Common Variables//
#include "/lib/commonVariables.glsl"
#include "/lib/commonFunctions.glsl"
//Common Functions//

float GetLinearDepth2(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/fog/mainFog.glsl"
#include "/lib/colors/skyColors.glsl"

#if defined NETHER || END
    #include "/lib/colors/lightAndAmbientColors.glsl"
#endif

#define MIN_LIGHT_AMOUNT 1.0

#include "/lib/lighting/indirectLighting.glsl"

//Program//
void main() {
    float z0 = texelFetch(depthtex0, texelCoord, 0).r;
    vec3 gi = vec3(0.0);
    float variance = 0.0;
    
    #if GLOBAL_ILLUMINATION == 2
    if (z0 < 1.0) {
        vec4 screenPos = vec4(texCoord, z0, 1.0);
        vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
        viewPos /= viewPos.w;
        vec3 nViewPos = normalize(viewPos.xyz);
        vec3 texture5 = texelFetch(colortex5, texelCoord, 0).rgb;
        vec3 normalM = mat3(gbufferModelView) * texture5;
        vec4 texture6 = texelFetch(colortex6, texelCoord, 0);
        float foliage = texture2D(colortex10, texCoord).a;
        float skyLightFactor = texture6.b;
        bool entityOrHand = z0 < 0.56;
        float dither = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 128.0).b;

        #ifdef TAA
            dither = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
        #endif

        float VdotU = dot(nViewPos, upVec);
        float VdotS = dot(nViewPos, sunVec);
        vec3 normalG = normalM;

        #ifdef TAA
            float noiseMult = 0.5;
        #else
            float noiseMult = 0.1;
        #endif

        vec2 roughCoord = gl_FragCoord.xy / 128.0;
        vec3 roughNoise = vec3(
            texture2D(noisetex, roughCoord).r,
            texture2D(noisetex, roughCoord + 0.09375).r,
            texture2D(noisetex, roughCoord + 0.1875).r
        );
        roughNoise = fract(roughNoise + vec3(dither, dither * goldenRatio, dither * pow2(goldenRatio)));
        roughNoise = noiseMult * (roughNoise - vec3(0.5));
        normalG += roughNoise;
        gi = min(GetGI(normalG, viewPos.xyz, nViewPos, depthtex0, dither, skyLightFactor, 1.0, VdotU, VdotS, entityOrHand).rgb, vec3(4.0));
        gi = max(gi, vec3(0.0));

        vec4 prevGI = texture2D(colortex9, texCoord);
        vec3 prevColor = prevGI.rgb;
        float prevVariance = prevGI.a;
        vec3 colorDiff = gi - prevColor;
        float currentVariance = dot(colorDiff, colorDiff);
        float varianceAlpha = 0.2;
        variance = mix(prevVariance, currentVariance, varianceAlpha);
        variance = clamp(variance, 0.0, 4.0);
    }
    #endif

    /* RENDERTARGETS: 9,11 */
    gl_FragData[0] = vec4(gi, variance);  // colortex9: filtered GI + variance
    gl_FragData[1] = vec4(gi, variance);  // colortex11: same, for temporal filter to read
}
#endif
//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER
noperspective out vec2 texCoord;
flat out vec3 upVec, sunVec;
//Attributes//
//Common Variables//
//Common Functions//
//Includes//
//Program//
void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = normalize(sunPosition);
}
#endif