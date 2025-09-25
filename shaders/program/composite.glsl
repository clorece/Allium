/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

flat in vec3 upVec, sunVec;

#ifdef LIGHTSHAFTS_ACTIVE
    flat in float vlFactor;
#endif

//Pipeline Constants//

#include "/lib/commonVariables.glsl"
#include "/lib/commonFunctions.glsl"
#include "/lib/util/spaceConversion.glsl"

//Common Functions//

//Includes//
#include "/lib/atmospherics/fog/waterFog.glsl"
#include "/lib/atmospherics/fog/caveFactor.glsl"

#ifdef BLOOM_FOG_COMPOSITE
    #include "/lib/atmospherics/fog/bloomFog.glsl"
#endif

#ifdef LIGHTSHAFTS_ACTIVE
    #ifdef END
        #include "/lib/atmospherics/enderBeams.glsl"
        #include "/lib/atmospherics/stars.glsl"      
    #endif
    #include "/lib/atmospherics/volumetricLight.glsl"
#endif

//#if WATER_MAT_QUALITY >= 3 || defined NETHER_STORM || defined COLORED_LIGHT_FOG
    
//#endif

vec2 GetCombinedWaves(vec2 uv, vec2 wind) {
    uv *= 1.0;
    wind *= 0.9;
    vec2 nMed   = texture2D(gaux4, uv + 0.25 * wind).gg - 0.5;
    vec2 nSmall = texture2D(gaux4, uv * 2.0 - 2.0 * wind).gg - 0.5;
    vec2 nBig   = texture2D(gaux4, uv * 0.35 + 0.65 * wind).gg - 0.5;

    return nMed * WATER_BUMP_MED +
            nSmall * WATER_BUMP_SMALL +
            nBig * WATER_BUMP_BIG;
}

#if WATER_MAT_QUALITY >= 3
    #include "/lib/materials/materialMethods/refraction.glsl"
#endif

#ifdef NETHER_STORM
    #include "/lib/atmospherics/netherStorm.glsl"
#endif

/*#ifdef END


    vec4 GetEndStorm(vec3 color, vec3 translucentMult, vec3 nPlayerPos, vec3 playerPos, float lViewPos, float lViewPos1, float VdotU, float dither) { 
        #define END_STORM_I 1.25
        #define END_STORM_LOWER_ALT -200.0
        #define END_STORM_HEIGHT 2000.0
        #define END_STORM_SIZE 0.0002
        #define END_STORM_SPEED 0.0003

        if (isEyeInWater != 0) return vec4(0.0);
        vec4 netherStorm = vec4(1.0, 1.0, 1.0, 0.0);

        #ifdef BORDER_FOG
            float maxDist = min(renderDistance, 2048); // consistency9023HFUE85JG
        #else
            float maxDist = renderDistance;
        #endif

        #ifndef LOW_QUALITY_NETHER_STORM
            int sampleCount = int(maxDist / 8.0 + 0.001);

            vec3 traceAdd = nPlayerPos * maxDist / sampleCount;
            vec3 tracePos = cameraPosition;
            tracePos += traceAdd * dither;
        #else
            int sampleCount = int(maxDist / 16.0 + 0.001);

            vec3 traceAdd = 0.75 * nPlayerPos * maxDist / sampleCount;
            vec3 tracePos = cameraPosition;
            tracePos += traceAdd * dither;
            tracePos += traceAdd * sampleCount * 0.25;
        #endif

        vec3 translucentMultM = pow(translucentMult, vec3(1.0 / sampleCount));

        for (int i = 0; i < sampleCount; i++) {
            tracePos += traceAdd;

            vec3 tracedPlayerPos = tracePos - cameraPosition;
            float lTracePos = length(tracedPlayerPos);
            if (lTracePos > lViewPos1) break;

            vec3 wind = vec3(frameTimeCounter * END_STORM_SPEED);

            vec3 tracePosM = tracePos * END_STORM_SIZE;
            //tracePosM.z += tracePosM.x;
            tracePosM.y /= 1.5;

            tracePosM += Noise3D(tracePosM - wind) * 0.01;
            tracePosM = tracePosM * vec3(2.0, 0.5, 2.0);

            float traceAltitudeM = abs(tracePos.y - END_STORM_LOWER_ALT);
            if (tracePos.y < END_STORM_LOWER_ALT) traceAltitudeM *= 10.0;
            traceAltitudeM = 1.0 - min1(abs(traceAltitudeM) / END_STORM_HEIGHT);

            for (int h = 0; h < 2; h++) {
                float stormSample = pow2(Noise3D(tracePosM + wind));
                stormSample *= traceAltitudeM;
                stormSample = pow2(pow2(stormSample));
                stormSample *= sqrt1(max0(1.0 - lTracePos / maxDist));

                netherStorm.a += stormSample;
                tracePosM *= 2.0;
                wind *= -2.0;
            }

            if (lTracePos > lViewPos) netherStorm.rgb *= translucentMultM;
        }

        #ifdef LOW_QUALITY_NETHER_STORM
            netherStorm.a *= 1.8;
        #endif

        //netherStorm.a = min1(endSkyColor.a * NETHER_STORM_I);

        netherStorm.rgb *= endSkyColor * (1.0 - VdotU) * END_STORM_I * (1.0 - maxBlindnessDarkness);
        //netherColor.rgb *= mix(fogColor, endSkyColor, -VdotU) * 0.0 ;

        //if (netherStorm.a > 0.98) netherStorm.rgb = vec3(1,0,1);
        //netherStorm.a *= 1.0 - max0(netherStorm.a - 0.98) * 50.0;

        return netherStorm;
    }
#endif*/

#ifdef ATM_COLOR_MULTS
    #include "/lib/colors/colorMultipliers.glsl"
#endif
#ifdef MOON_PHASE_INF_ATMOSPHERE
    #include "/lib/colors/moonPhaseInfluence.glsl"
#endif

#if RAINBOWS > 0 && defined OVERWORLD
    #include "/lib/atmospherics/rainbow.glsl"
#endif

#ifdef COLORED_LIGHT_FOG
    #include "/lib/misc/voxelization.glsl"
    #include "/lib/atmospherics/fog/coloredLightFog.glsl"
#endif

//Program//
void main() {
    vec3 color = texelFetch(colortex0, texelCoord, 0).rgb;
    float z0 = texelFetch(depthtex0, texelCoord, 0).r;
    float z1 = texelFetch(depthtex1, texelCoord, 0).r;

    vec4 screenPos = vec4(texCoord, z0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    float lViewPos = length(viewPos.xyz);

    #if defined DISTANT_HORIZONS && !defined OVERWORLD
        float z0DH = texelFetch(dhDepthTex, texelCoord, 0).r;
        vec4 screenPosDH = vec4(texCoord, z0DH, 1.0);
        vec4 viewPosDH = dhProjectionInverse * (screenPosDH * 2.0 - 1.0);
        viewPosDH /= viewPosDH.w;
        lViewPos = min(lViewPos, length(viewPosDH.xyz));
    #endif

    float dither = texture2D(noisetex, texCoord * view / 128.0).b;
    #ifdef TAA
        dither = fract(dither + goldenRatio * mod(float(frameCounter), 3600.0));
    #endif

    /* TM5723: The "1.0 - translucentMult" trick is done because of the default color attachment
    value being vec3(0.0). This makes it vec3(1.0) to avoid issues especially on improved glass */
    vec3 translucentMult = 1.0 - texelFetch(colortex3, texelCoord, 0).rgb; //TM5723
    vec4 volumetricEffect = vec4(0.0);

    #if WATER_MAT_QUALITY >= 3
        DoRefraction(color, z0, z1, viewPos.xyz, lViewPos);
    #endif

    vec4 screenPos1 = vec4(texCoord, z1, 1.0);
    vec4 viewPos1 = gbufferProjectionInverse * (screenPos1 * 2.0 - 1.0);
    viewPos1 /= viewPos1.w;

    vec3 nViewPos = normalize(viewPos1.xyz);
    float lViewPos1 = length(viewPos1.xyz);
    float VdotL = dot(nViewPos, lightVec);
    float VdotU = dot(nViewPos, upVec);
    float VdotS = dot(nViewPos, sunVec);

    #if defined DISTANT_HORIZONS && !defined OVERWORLD
        float z1DH = texelFetch(dhDepthTex1, texelCoord, 0).r;
        vec4 screenPos1DH = vec4(texCoord, z1DH, 1.0);
        vec4 viewPos1DH = dhProjectionInverse * (screenPos1DH * 2.0 - 1.0);
        viewPos1DH /= viewPos1DH.w;
        lViewPos1 = min(lViewPos1, length(viewPos1DH.xyz));
    #endif

        

    //#if defined NETHER_STORM || defined COLORED_LIGHT_FOG
        vec3 playerPos = ViewToPlayer(viewPos1.xyz);
        vec3 nPlayerPos = normalize(playerPos);
    //#endif

    #if RAINBOWS > 0 && defined OVERWORLD
        if (isEyeInWater == 0) color += GetRainbow(translucentMult, z0, z1, lViewPos, lViewPos1, VdotL, dither);
    #endif

    #ifdef LIGHTSHAFTS_ACTIVE
        float vlFactorM = vlFactor;

        volumetricEffect = GetVolumetricLight(color, vlFactorM, translucentMult, lViewPos, lViewPos1, nViewPos, VdotL, VdotU, texCoord, z0, z1, dither);
    #endif

    #ifdef NETHER_STORM
        volumetricEffect = GetNetherStorm(color, translucentMult, nPlayerPos, playerPos, lViewPos, lViewPos1, dither);
    #endif

    /*#ifdef END  
        //#if DETAIL_QUALITY > 2
        //vec3 playerPos = ViewToPlayer(viewPos1.xyz);
        //vec3 nPlayerPos = normalize(playerPos);
        //float VdotU = dot(nViewPos, upVec);
        //volumetricEffect = GetEndStorm(color, translucentMult, nPlayerPos, playerPos, lViewPos, lViewPos1, VdotU, dither);
        //color = mix(color, volumetricEffect.rgb, volumetricEffect.a);
        //#endif
    #endif*/


    #ifdef ATM_COLOR_MULTS
        volumetricEffect.rgb *= GetAtmColorMult();
    #endif
    #ifdef MOON_PHASE_INF_ATMOSPHERE
        volumetricEffect.rgb *= moonPhaseInfluence;
    #endif

    #ifdef NETHER_STORM
        color = mix(color, volumetricEffect.rgb, volumetricEffect.a);
    #endif

    #ifdef COLORED_LIGHT_FOG
        vec3 lightFog = GetColoredLightFog(nPlayerPos, translucentMult, lViewPos, lViewPos1, dither);
        float lightFogMult = COLORED_LIGHT_FOG_I;
        //if (heldItemId == 40000 && heldItemId2 != 40000) lightFogMult = 0.0; // Hold spider eye to disable light fog

        #ifdef OVERWORLD
            lightFogMult *= 0.2 + 0.6 * mix(1.0, 1.0 - sunFactor * invRainFactor, eyeBrightnessM);
        #endif
    #endif

    if (isEyeInWater == 1) {
        if (z0 == 1.0) color.rgb = waterFogColor;

        vec3 underwaterMult = vec3(0.80, 0.87, 0.97);
        color.rgb *= underwaterMult * 0.85;
        volumetricEffect.rgb *= pow2(underwaterMult * 0.71);

        #ifdef COLORED_LIGHT_FOG
            lightFog *= underwaterMult;
        #endif
    } else if (isEyeInWater == 2) {
        if (z1 == 1.0) color.rgb = fogColor * 5.0;

        volumetricEffect.rgb *= 0.0;
        #ifdef COLORED_LIGHT_FOG
            lightFog *= 0.0;
        #endif
    }

    #ifdef COLORED_LIGHT_FOG
        color /= 1.0 + pow2(GetLuminance(lightFog)) * lightFogMult * 2.0;
        color += lightFog * lightFogMult * 0.5;
    #endif

    color = pow(color, vec3(2.2));

    #ifdef LIGHTSHAFTS_ACTIVE
        //#ifdef END
        //    volumetricEffect.rgb *= 0.05;
        //#endif

        
        color += volumetricEffect.rgb;
    #endif

    #ifdef CREPUSCULAR_RAYS
        color += GetCrepuscularRays(VdotL, VdotU, VdotS, lViewPos1, z0, z1, dither).rgb;
    #endif

    #ifdef BLOOM_FOG_COMPOSITE
        color *= GetBloomFog(lViewPos); // Reminder: Bloom Fog can move between composite1-2-3
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);

    // supposed to be #if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
    #if LIGHTSHAFT_QUALI_DEFINE > 0 && LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 && defined OVERWORLD || defined END
        #if LENSFLARE_MODE > 0 || defined ENTITY_TAA_NOISY_CLOUD_FIX
            if (viewWidth + viewHeight - gl_FragCoord.x - gl_FragCoord.y > 1.5)
                vlFactorM = texelFetch(colortex4, texelCoord, 0).r;
        #endif

        /* DRAWBUFFERS:04 */
        gl_FragData[1] = vec4(vlFactorM, 0.0, 0.0, 1.0);
    #endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

flat out vec3 upVec, sunVec;

#ifdef LIGHTSHAFTS_ACTIVE
    flat out float vlFactor;
#endif

//Attributes//

//Common Variables//

//Common Functions//

//Includes//

//Program//
void main() {
    gl_Position = ftransform();

    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = GetSunVector();

    #ifdef LIGHTSHAFTS_ACTIVE
        #if LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END
            vlFactor = texelFetch(colortex4, ivec2(viewWidth-1, viewHeight-1), 0).r;
        #else
            #if LIGHTSHAFT_BEHAVIOUR == 2
                vlFactor = 0.0;
            #elif LIGHTSHAFT_BEHAVIOUR == 3
                vlFactor = 1.0;
            #endif
        #endif
    #endif
}

#endif
