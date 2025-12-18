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

#ifdef TEMPORAL_FILTER
    // Previous frame reprojection from Chocapic13
    vec2 Reprojection(vec3 pos, vec3 cameraOffset) {
        pos = pos * 2.0 - 1.0;

        vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
        viewPosPrev /= viewPosPrev.w;
        viewPosPrev = gbufferModelViewInverse * viewPosPrev;

        vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
        previousPosition = gbufferPreviousModelView * previousPosition;
        previousPosition = gbufferPreviousProjection * previousPosition;
        return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
    }

    vec2 SHalfReprojection(vec3 playerPos, vec3 cameraOffset) {
        vec4 proPos = vec4(playerPos + cameraOffset, 1.0);
        vec4 previousPosition = gbufferPreviousModelView * proPos;
        previousPosition = gbufferPreviousProjection * previousPosition;
        return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
    }
#endif

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

bool IsActivePixel(vec2 coord) {
    #if PT_RENDER_RESOLUTION == 3
        return true;
    #else
        ivec2 p = ivec2(coord);
        
        if (PT_RENDER_RESOLUTION == 2) return !((p.x & 1) != 0 && (p.y & 1) != 0);
        if (PT_RENDER_RESOLUTION == 1) return ((p.x + p.y) & 1) == 0;
        if (PT_RENDER_RESOLUTION == 0) return ((p.x & 1) == 0 && (p.y & 1) == 0);
        
        return true;
    #endif
}

//Program//
void main() {
    if (!IsActivePixel(gl_FragCoord.xy)) {
        gl_FragData[0] = vec4(0.0);
        gl_FragData[1] = vec4(0.0);
        return;
    }

    vec2 scaledCoord = texCoord * RENDER_SCALE;
    ivec2 scaledTexelCoord = ivec2(scaledCoord * vec2(viewWidth, viewHeight));
    
    float z0 = texelFetch(depthtex0, scaledTexelCoord, 0).r;
    vec3 gi = vec3(0.0);
    vec3 ao = vec3(0.0);

    vec4 screenPos = vec4(scaledCoord, z0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    vec3 nViewPos = normalize(viewPos.xyz);
    vec3 playerPos = ViewToPlayer(viewPos.xyz);
    
    vec3 texture5 = texelFetch(colortex5, scaledTexelCoord, 0).rgb;
    vec3 normalM = mat3(gbufferModelView) * texture5;
    vec4 texture6 = texelFetch(colortex6, scaledTexelCoord, 0);
    float skyLightFactor = texture6.b;
    bool entityOrHand = z0 < 0.56;
    
    float dither = texture2D(noisetex, scaledCoord * vec2(viewWidth, viewHeight) / 128.0).b;
    #ifdef TAA
        dither = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
    #endif

    float VdotU = dot(nViewPos, upVec);
    float VdotS = dot(nViewPos, sunVec);
    vec3 normalG = normalM;

    #ifdef TAA
        float noiseMult = 1.0;
    #else
        float noiseMult = 0.1;
    #endif
    vec2 roughCoord = gl_FragCoord.xy / 128.0;
    float roughNoise = texture2D(noisetex, roughCoord).r;
    roughNoise = fract(roughNoise + goldenRatio * mod(float(frameCounter), 360.0));
    roughNoise = noiseMult * (roughNoise - 0.5);
    normalG += roughNoise;

    gi = min(GetGI(ao, normalG, viewPos.xyz, nViewPos, depthtex0, dither, skyLightFactor, 1.0, VdotU, VdotS, entityOrHand).rgb, vec3(4.0));
    gi = max(gi, vec3(0.0));

    vec3 colorAdd = gi - ao;
    
    /* RENDERTARGETS: 9,11 */
    gl_FragData[0] = vec4(gi, 1.0);
    gl_FragData[1] = vec4(ao, 1.0);
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