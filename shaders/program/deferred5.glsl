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

//Includes//
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/fog/mainFog.glsl"
#include "/lib/colors/skyColors.glsl"

#if AURORA_STYLE > 0
    #include "/lib/atmospherics/auroraBorealis.glsl"
#endif

#ifdef NIGHT_NEBULA
    #include "/lib/atmospherics/nightNebula.glsl"
#endif



// Include cloud rendering - this is needed for GetClouds() function
#ifdef VL_CLOUDS_ACTIVE
    #include "/lib/atmospherics/clouds/mainClouds.glsl"
#endif
#ifdef MOON_PHASE_INF_ATMOSPHERE
    #include "/lib/colors/moonPhaseInfluence.glsl"
#endif

bool IsActivePixel(vec2 coord) {
    #if CLOUD_RENDER_RESOLUTION == 3
        return true;
    #else
        ivec2 p = ivec2(coord);
        
        if (CLOUD_RENDER_RESOLUTION == 2) return !((p.x & 1) != 0 && (p.y & 1) != 0);
        if (CLOUD_RENDER_RESOLUTION == 1) return ((p.x + p.y) & 1) == 0;
        //if (CLOUD_RENDER_RESOLUTION == 0) return ((p.x & 1) == 0 && (p.y & 1) == 0);
        
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
    // Calculate actual texture coordinate for downscaled buffer
    vec2 actualTexCoord = texCoord;
    
    // Sample depth at downscaled resolution
    float z0 = texture2D(depthtex0, actualTexCoord).r;
    
    vec4 screenPos = vec4(actualTexCoord, z0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    float lViewPos = length(viewPos.xyz);
    vec3 nViewPos = normalize(viewPos.xyz);
    vec3 playerPos = ViewToPlayer(viewPos.xyz);
    
    // Dither for temporal stability
    float dither = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 128.0).b;
    #ifdef TAA
        dither = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
    #endif
    
    float VdotU = dot(nViewPos, upVec);
    float VdotS = dot(nViewPos, sunVec);
    
    vec3 auroraBorealis = vec3(0.0);
    vec3 nightNebula = vec3(0.0);
    
    #ifdef OVERWORLD
        #if AURORA_STYLE > 0
            auroraBorealis = GetAuroraBorealis(viewPos.xyz, VdotU, dither);
        #endif
        #ifdef NIGHT_NEBULA
            nightNebula = GetNightNebula(viewPos.xyz, VdotU, VdotS);
        #endif
    #endif
    
    float cloudLinearDepth = 1.0;
    vec4 clouds = vec4(0.0);
    float skyFade = z0 >= 1.0 ? 1.0 : 0.0;
    
    #ifdef VL_CLOUDS_ACTIVE
        float cloudZCheck = 0.56;
        
        //if (z0 > cloudZCheck) {
            clouds = GetClouds(cloudLinearDepth, skyFade, cameraPosition, playerPos,
                               lViewPos, VdotS, VdotU, dither, auroraBorealis, nightNebula);
        //}
    #endif
    
    // Output: RGB = cloud color, A = cloud alpha
    // colortex12 = clouds RGBA, colortex13 = cloud depth
    /* RENDERTARGETS:12,13 */
    gl_FragData[0] = clouds;
    gl_FragData[1] = vec4(cloudLinearDepth, 0.0, 0.0, 1.0);
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

    #if defined TAA && RENDER_SCALE < 1.0
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
    #endif
}

#endif