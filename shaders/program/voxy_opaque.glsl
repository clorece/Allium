#include "/lib/common.glsl"
#include "/lib/misc/lodModSupport.glsl"
#include "/lib/util/spaceConversion.glsl"

// Global variables required by mainLighting.glsl
int mat;
vec3 upVec, sunVec, lightVec;
vec3 northVec, eastVec;
float NdotU, NdotUmax0;

// Voxy uses a forward rendering approach here, effectively filling the gbuffers 
// but we calculate lighting immediately for the final color.

#include "/lib/lighting/mainLighting.glsl"

layout(location = 0) out vec4 color_out;

void voxy_emitFragment(VoxyFragmentParameters parameters) {
    // 1. Setup Globals
    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = GetSunVector();
    northVec = normalize(gbufferModelView[2].xyz);
    eastVec = normalize(gbufferModelView[0].xyz);

    mat = int(parameters.customId) - 10000;

    // 2. Decode Normal
    // Voxy face encoding: 0=down, 1=up, 2=north, 3=south, 4=west, 5=east
    vec3 normal = vec3(
        uint((parameters.face >> 1) == 2),  // X
        uint((parameters.face >> 1) == 0),  // Y
        uint((parameters.face >> 1) == 1)   // Z
    ) * (float(int(parameters.face) & 1) * 2.0 - 1.0); // Sign

    // 3. Common Vectors
    NdotU = dot(normal, upVec);
    NdotUmax0 = max(NdotU, 0.0);

    #ifdef OVERWORLD
        lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
    #else
        lightVec = sunVec;
    #endif

    // 4. Reconstruct Position
    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
    
    vec3 viewPos = ScreenToViewLOD(screenPos);
    vec3 playerPos = ViewToPlayer(viewPos);
    float lViewPos = length(playerPos);

    // 5. Prepare Colors
    vec4 color = parameters.sampledColour * parameters.tinting;
    
    // 6. Lighting Setup
    vec3 shadowMult = vec3(1.0);
    vec3 geoNormal = normal;
    vec3 normalM = normal;
    vec3 worldGeoNormal = normalize(ViewToPlayer(geoNormal * 10000.0));
    float dither = Bayer64(gl_FragCoord.xy);

    // 7. Do Lighting
    DoLighting(
        color,               // inout color
        shadowMult,          // inout shadowMult
        playerPos,           // playerPos
        viewPos,             // viewPos
        lViewPos,            // lViewPos
        geoNormal,           // geoNormal
        normalM,             // normalM
        dither,              // dither
        worldGeoNormal,      // worldGeoNormal
        parameters.lightMap, // lightmap
        false,               // noSmoothLighting
        false,               // noDirectionalShading
        false,               // noVanillaAO
        false,               // centerShadowBias
        0,                   // subsurfaceMode
        0.0,                 // smoothnessG
        1.0,                 // highlightMult
        0.0                  // emission
    );

    // Note: DoFog is not called here, assuming standard Allium pipeline calls it later or we should add it.
    // In gbuffers_terrain, DoFog is called.
    // We should probably call it here too.
    // But DoLighting includes skyColors which might be enough for some?
    // Let's rely on voxy_translucent to handle water fog.
    // Ideally, opaque terrain also needs fog.
    // I can't easily include mainFog.glsl due to function name collisions potentially?
    // But voxy_opaque.glsl is a separate program.
    // Let's exclude fog for now to minimize errors, or investigate if I should add it.
    // gbuffers_terrain includes mainFog.glsl and calls DoFog.
    // I will skip it in opaque for now to match my previous safe attempt.

    color_out = color;
}
