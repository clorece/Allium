#include "/lib/common.glsl"
#include "/lib/misc/lodModSupport.glsl"
#include "/lib/util/spaceConversion.glsl"

// Globals
int mat;
vec3 upVec, sunVec, lightVec;
vec3 northVec, eastVec;
float NdotU, NdotUmax0;

#include "/lib/lighting/mainLighting.glsl"
#include "/lib/atmospherics/fog/mainFog.glsl"

layout(location = 0) out vec4 color_out;

void voxy_emitFragment(VoxyFragmentParameters parameters) {
    // 1. Setup
    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = GetSunVector();
    northVec = normalize(gbufferModelView[2].xyz);
    eastVec = normalize(gbufferModelView[0].xyz);

    mat = int(parameters.customId) - 10000;
    
    // Normal
    vec3 normal = vec3(
        uint((parameters.face >> 1) == 2),
        uint((parameters.face >> 1) == 0),
        uint((parameters.face >> 1) == 1)
    ) * (float(int(parameters.face) & 1) * 2.0 - 1.0);

    // Light direction
    #ifdef OVERWORLD
        lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
    #else
        lightVec = sunVec;
    #endif

    // Vectors
    NdotU = dot(normal, upVec);
    NdotUmax0 = max(NdotU, 0.0);

    // Position
    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
    vec3 viewPos = ScreenToViewLOD(screenPos);
    vec3 playerPos = ViewToPlayer(viewPos);
    float lViewPos = length(playerPos);
    
    vec3 nViewPos = normalize(viewPos);
    float VdotU = dot(nViewPos, upVec);
    float VdotS = dot(nViewPos, sunVec);

    // Color
    vec4 color = parameters.sampledColour * parameters.tinting;

    // Lighting
    vec3 shadowMult = vec3(1.0);
    vec3 geoNormal = normal;
    vec3 worldGeoNormal = normalize(ViewToPlayer(geoNormal * 10000.0));
    float dither = Bayer64(gl_FragCoord.xy);

    DoLighting(color, shadowMult, playerPos, viewPos, lViewPos, geoNormal, normal, dither,
               worldGeoNormal, parameters.lightMap, false, false, false, false, 0, 0.0, 1.0, 0.0);
               
    // Fog
    float sky = 0.0;
    DoFog(color.rgb, sky, lViewPos, playerPos, VdotU, VdotS, dither);
    color.a *= 1.0 - sky;

    color_out = color;
}
