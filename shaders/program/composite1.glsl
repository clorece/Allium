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

#include "/lib/commonVariables.glsl"

//Common Functions//
float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * farMinusNear);
}

//Includes//
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/colors/skyColors.glsl"

#if AURORA_STYLE > 0
    #include "/lib/atmospherics/auroraBorealis.glsl"
#endif

#ifdef NIGHT_NEBULA
    #include "/lib/atmospherics/nightNebula.glsl"
#endif

#ifdef VL_CLOUDS_ACTIVE
    #include "/lib/atmospherics/clouds/mainClouds.glsl"
#endif

#ifdef ATM_COLOR_MULTS
    #include "/lib/colors/colorMultipliers.glsl"
#endif

//Program//
void main() {
    float z0 = texelFetch(depthtex0, texelCoord, 0).r;
    
    vec4 screenPos = vec4(texCoord, z0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    float lViewPos = length(viewPos.xyz);
    vec3 nViewPos = normalize(viewPos.xyz);
    vec3 playerPos = ViewToPlayer(viewPos.xyz);

    float dither = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 128.0).b;
    #if defined TAA || defined TEMPORAL_FILTER
        dither = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
    #endif

    #ifdef ATM_COLOR_MULTS
        atmColorMult = GetAtmColorMult();
        sqrtAtmColorMult = sqrt(atmColorMult);
    #endif

    float VdotU = dot(nViewPos, upVec);
    float VdotS = dot(nViewPos, sunVec);
    
    float skyFade = 0.0;
    vec3 auroraBorealis = vec3(0.0);
    vec3 nightNebula = vec3(0.0);
    vec4 clouds = vec4(0.0);
    float cloudLinearDepth = 1.0;

    // Only render clouds for sky pixels
    float cloudZCheck = 0.56;
    
    if (z0 > cloudZCheck) {
        skyFade = 1.0;
        
        // Get aurora and nebula for cloud interactions
        #ifdef OVERWORLD
            #if AURORA_STYLE > 0
                auroraBorealis = GetAuroraBorealis(viewPos.xyz, VdotU, dither);
            #endif
            #ifdef NIGHT_NEBULA
                nightNebula = GetNightNebula(viewPos.xyz, VdotU, VdotS);
            #endif
        #endif

        #ifdef VL_CLOUDS_ACTIVE
            clouds = GetClouds(cloudLinearDepth, skyFade, cameraPosition, playerPos,
                               lViewPos, VdotS, VdotU, dither, auroraBorealis, nightNebula);
        #endif
    }

    /*DRAWBUFFERS:9*/
    gl_FragData[0] = vec4(clouds.rgb, cloudLinearDepth); // Store depth in alpha
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

flat out vec3 upVec, sunVec;

//Program//
void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = normalize(sunPosition);
}

#endif