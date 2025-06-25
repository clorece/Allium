/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

#if DETAIL_QUALITY > 2
    #define SKY_ILLUMINATION
#endif

//#define SKY_ILLUMINATION_VIEW

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

in vec3 normal;

flat in vec3 upVec, sunVec;

#if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
    flat in float vlFactor;
#endif

uniform vec2 pixel;

//Pipeline Constants//
const bool colortex0MipmapEnabled = true;

//Common Variables//
float SdotU = dot(sunVec, upVec);
float sunFactor = SdotU < 0.0 ? clamp(SdotU + 0.375, 0.0, 0.75) / 0.75 : clamp(SdotU + 0.03125, 0.0, 0.0625) / 0.0625;
float sunVisibility = clamp(SdotU + 0.0625, 0.0, 0.125) / 0.125;
float sunVisibility2 = sunVisibility * sunVisibility;
float shadowTimeVar1 = abs(sunVisibility - 0.5) * 2.0;
float shadowTimeVar2 = shadowTimeVar1 * shadowTimeVar1;
float shadowTime = shadowTimeVar2 * shadowTimeVar2;
float farMinusNear = far - near;

vec2 view = vec2(viewWidth, viewHeight);

#ifdef OVERWORLD
    vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
#else
    vec3 lightVec = sunVec;
#endif

#if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
#else
    float vlFactor = 0.0;
#endif

//Common Functions//
float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * farMinusNear);
}

float GetInverseLinearDepth(float linearDepth) {
    return (far + near - (2.0 * near) / linearDepth) / (far - near);
}

#ifdef TEMPORAL_FILTER
    float GetApproxDistance(float depth) {
        return near * far / (far - depth * far);
    }

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

    vec3 FHalfReprojection(vec3 pos) {
        pos = pos * 2.0 - 1.0;

        vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
        viewPosPrev /= viewPosPrev.w;
        viewPosPrev = gbufferModelViewInverse * viewPosPrev;

        return viewPosPrev.xyz;
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

#if AURORA_STYLE > 0
    #include "/lib/atmospherics/auroraBorealis.glsl"
#endif

#ifdef NIGHT_NEBULA
    #include "/lib/atmospherics/nightNebula.glsl"
#endif

#ifdef VL_CLOUDS_ACTIVE
    #include "/lib/atmospherics/clouds/mainClouds.glsl"
#endif

#ifdef PBR_REFLECTIONS
    #include "/lib/materials/materialMethods/reflections.glsl"
#endif

#ifdef END
    #include "/lib/atmospherics/enderStars.glsl"   
#endif

#ifdef WORLD_OUTLINE
    #include "/lib/misc/worldOutline.glsl"
#endif

#ifdef DARK_OUTLINE
    #include "/lib/misc/darkOutline.glsl"
#endif

#ifdef ATM_COLOR_MULTS
    #include "/lib/colors/colorMultipliers.glsl"
#endif
#ifdef MOON_PHASE_INF_ATMOSPHERE
    #include "/lib/colors/moonPhaseInfluence.glsl"
#endif

#ifdef DISTANT_LIGHT_BOKEH
    #include "/lib/misc/distantLightBokeh.glsl"
#endif

#define GLOBAL_ILLUMINATION 1 //[0 1]
#define GI_MULT 1.0 //[1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#if SSAO_QUALI == 3
    float geometryAwareOcclusion(vec3 surfaceNormal, vec3 viewDir, vec3 hitPos, vec3 viewPos) {
        // Estimate normal of the hit position using screen-space derivatives
        vec3 hitNormal = normalize(cross(dFdx(hitPos), dFdy(hitPos)));

        // Check if the hit surface is facing toward the view position
        float facing = dot(hitNormal, surfaceNormal);

        // Reject AO from back-facing geometry (e.g., through fences)
        if (facing < 0.3) return 0.0;

        // Optional: fade based on alignment to preserve softer edges
        return smoothstep(0.3, 1.0, facing);
    }

    #define SSRAO_QUALITY 16 //[2 8 12 16 20]
    #define SSRAO_I 1.5 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define SSRAO_STEP 4
    #define SSRAO_RADIUS 1.0 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define DEPTH_TOLERANCE 12.0 //[1.0 2.0 8.0 12.0 16.0 24.0 32.0]

    float SSRAO(vec3 color, vec3 normalM, vec3 viewPos, sampler2D depthtex, float dither) {

        const int NUM_SAMPLES = SSRAO_QUALITY;
        const int MAX_STEPS = SSRAO_STEP;
        const float AO_RADIUS = SSRAO_RADIUS;

        float occlusion = 0.0;

        // Tangent space basis
        vec3 up = abs(normalM.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 tangent = normalize(cross(up, normalM));
        vec3 bitangent = cross(normalM, tangent);

        float invSamples = 1.0 / float(NUM_SAMPLES);
        float stepSize = AO_RADIUS / float(MAX_STEPS);

        for (int i = 0; i < NUM_SAMPLES; ++i) {
            float fi = float(i);
            float rand = fract(fi * 0.73 + dither * SSRAO_STEP);
            float phi = 6.2831 * (rand);
            float cosTheta = sqrt(1.0 - fi * invSamples);
            float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

            vec3 hemiDir = sinTheta * cos(phi) * tangent +
                        sinTheta * sin(phi) * bitangent +
                        cosTheta * normalM;

            vec3 rayDir = hemiDir * stepSize;
            vec3 rayPos = viewPos + normalM * 0.01 * color;

            for (int j = 0; j < MAX_STEPS; ++j) {
                rayPos += rayDir;

                vec4 projected = gbufferProjection * vec4(rayPos, 1.0);
                if (projected.w <= 0.0) break;

                vec2 screenUV = projected.xy / projected.w * 0.5 + 0.5;
                if (abs(screenUV.x - 0.5) > view.x || abs(screenUV.y - 0.5) > view.y) break;

                float sceneZ = texture(depthtex0, screenUV).r;
                vec4 hitClip = vec4(screenUV * 2.0 - 1.0, sceneZ * 2.0 - 1.0, 1.0);
                vec4 hitPos4 = gbufferProjectionInverse * hitClip;
                vec3 hitPos = hitPos4.xyz / hitPos4.w;

                float dz = hitPos.z - rayPos.z;
                float depthDiff = abs(hitPos.z - viewPos.z);

                if (dz > 0.001 && dz < stepSize * DEPTH_TOLERANCE && depthDiff < AO_RADIUS * 32.0) {
                    float geomFactor = geometryAwareOcclusion(normalM, rayDir, hitPos, viewPos);
                    float weight = (1.0 - smoothstep(0.0, stepSize * DEPTH_TOLERANCE, dz));
                    //occlusion -= geomFactor;
                    occlusion += weight * SSRAO_I;
                    break;
                }
            }
        }
        occlusion *= 0.5;

        float ao = 1.0 - (occlusion * invSamples);
        return clamp(ao, 0.0, 1.0);

    }
#endif

#if SSAO_QUALI == 2
float hash1(float x) {
    return fract(sin(x * 12.9898 + 78.233) * 43758.5453);
}

float SSAO(vec3 normalM, vec3 viewPos, sampler2D depthtex, float dither) {
    #define SSAO_SAMPLES 2
    #define SSAO_STEPS   12
    #define SSAO_RADIUS  1.0

    const vec2 rEdge = vec2(0.6, 0.55);

    // Build tangent basis
    vec3 upV = abs(normalM.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(upV, normalM));
    vec3 B = cross(normalM, T);

    float occlusion = 0.0;

    for (int i = 0; i < SSAO_SAMPLES; i++) {
        float rnd   = hash1(float(i) + dither);
        float phi   = 6.2831853 * rnd;
        float cosTh = sqrt(1.0 - rnd);
        float sinTh = sqrt(1.0 - cosTh * cosTh); // keep this version

        vec3 sampleDir = T * (cos(phi) * sinTh)
                       + B * (sin(phi) * sinTh)
                       + normalM * cosTh;

        for (int j = 1; j <= SSAO_STEPS; j++) {
            float t = float(j) / float(SSAO_STEPS) * SSAO_RADIUS;
            vec3 sampPos = viewPos + sampleDir * t;

            // Project to clip space
            vec4 clip = gbufferProjection * vec4(sampPos, 1.0);
            if (clip.w <= 0.0) break;
            vec2 uv = clip.xy / clip.w * 0.5 + 0.5;

            // Skip if offscreen
            if (abs(uv.x - 0.5) > rEdge.x || abs(uv.y - 0.5) > rEdge.y)
                break;

            // Reconstruct view-space position
            float sceneZ = texture2D(depthtex0, uv).r;
            vec4 projected = vec4(uv * 2.0 - 1.0, sceneZ * 2.0 - 1.0, 1.0);
            vec4 sceneVS4 = gbufferProjectionInverse * projected;
            vec3 sceneVS = sceneVS4.xyz / sceneVS4.w; // DO NOT skip this divide

            // AO test
            float bias = 0.005;
            if (sceneVS.z > sampPos.z + bias) {
                occlusion += 1.0;
                break;
            }
        }
    }

    float ao = 1.0 - occlusion / float(SSAO_SAMPLES * SSAO_STEPS);
    return clamp(ao, 0.0, 1.0);
}
#endif

#ifdef NETHER
vec3 ambientColor = vec3(0.5, 0.21, 0.01);
#endif

#define MIN_LIGHT_AMOUNT 1.0


#ifdef OVERWORLD // GI ONLY AVAILABLE FOR OVERWORLD, for now...
    #if GLOBAL_ILLUMINATION == 1
        #include "/lib/lighting/GI.glsl"
    #endif
#endif


vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

//Program//
void main() {
    vec3 color = texelFetch(colortex0, texelCoord, 0).rgb;
    // FROM BLISS MUST NOT USE
    //vec3 Indirect_lighting = vec3(0.0);
    //vec3 minLightColor = vec3(1.0);


    float z0 = texelFetch(depthtex0, texelCoord, 0).r;

    vec4 screenPos = vec4(texCoord, z0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    float lViewPos = length(viewPos);
    vec3 nViewPos = normalize(viewPos.xyz);
    vec3 playerPos = ViewToPlayer(viewPos.xyz);
    vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos.xyz;
	vec3 feetPlayerPos_normalized = normVec(feetPlayerPos);

    float dither = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 128.0).b;
    vec3 dither2 = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 128.0).xyz;
    #if defined TAA || defined TEMPORAL_FILTER
        dither = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
        dither2.x = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
        dither2.y = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
        dither2.z = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
    #endif

    #ifdef ATM_COLOR_MULTS
        atmColorMult = GetAtmColorMult();
        sqrtAtmColorMult = sqrt(atmColorMult);
    #endif

    float VdotU = dot(nViewPos, upVec);
    float VdotS = dot(nViewPos, sunVec);
    float skyFade = 0.0;
    vec3 waterRefColor = vec3(0.0);
    vec3 auroraBorealis = vec3(0.0);
    vec3 nightNebula = vec3(0.0);

    #ifdef TEMPORAL_FILTER
        vec4 refToWrite = vec4(0.0);
    #endif

    if (z0 < 1.0) {
        #ifdef DISTANT_LIGHT_BOKEH
            int dlbo = 1;
            vec3 dlbColor = color;
            dlbColor += texelFetch(colortex0, texelCoord + ivec2( 0, dlbo), 0).rgb;
            dlbColor += texelFetch(colortex0, texelCoord + ivec2( 0,-dlbo), 0).rgb;
            dlbColor += texelFetch(colortex0, texelCoord + ivec2( dlbo, 0), 0).rgb;
            dlbColor += texelFetch(colortex0, texelCoord + ivec2(-dlbo, 0), 0).rgb;
            dlbColor = max(color, dlbColor * 0.2);
            float dlbMix = GetDistantLightBokehMix(lViewPos);
            color = mix(color, dlbColor, dlbMix);
        #endif

        #if SSAO_QUALI > 0 || defined WORLD_OUTLINE || defined TEMPORAL_FILTER
            float linearZ0 = GetLinearDepth(z0);
        #endif

        vec3 texture6 = texelFetch(colortex6, texelCoord, 0).rgb;
        bool entityOrHand = z0 < 0.56;
        int materialMaskInt = int(texture6.g * 255.1);
        float intenseFresnel = 0.0;
        float smoothnessD = texture6.r;
        vec3 reflectColor = vec3(1.0);

        float skyLightFactor = texture6.b;
        vec3 texture5 = texelFetch(colortex5, texelCoord, 0).rgb;
        vec3 normalM = mat3(gbufferModelView) * texture5;

        // FROM BLISS, MUST NOT USE
        //Indirect_lighting += doIndirectLighting(ambientColor * 1.0, minLightColor, skyLightFactor);
        //minLightColor = minLightColor + 0.7 * minLightColor * dot(normalM, feetPlayerPos_normalized);

        float ao = 1.0;
        #if SSAO_QUALI == 2
            ao = SSAO(normalM, viewPos.xyz, depthtex0, dither);
            ao = clamp( 1.0 - (1.0 - ao) * SSAO_I, 0.0, 1.0 );
        #elif SSAO_QUALI == 3
            float aoDarkness = 5.0;
            ao = SSRAO(color.rgb, normalM, viewPos.xyz, depthtex0, dither);
        #else
            ao = 1.0;
        #endif

        if (materialMaskInt <= 240) {
            #ifdef IPBR
                #include "/lib/materials/materialHandling/deferredMaterials.glsl"
            #elif defined CUSTOM_PBR
                #if RP_MODE == 2 // seuspbr
                    float metalness = materialMaskInt / 240.0;

                    intenseFresnel = metalness;
                #elif RP_MODE == 3 // labPBR
                    float metalness = float(materialMaskInt >= 230);

                    intenseFresnel = materialMaskInt / 240.0;
                #endif
                reflectColor = mix(reflectColor, color.rgb / max(color.r + 0.00001, max(color.g, color.b)), metalness);
            #endif
        } else {
            if (materialMaskInt == 254) { // No SSAO, No TAA
                ao = 1.0;
                entityOrHand = true;
            }
        }
                float darkness = 0.5 - dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

        color.rgb *= ao;

    
        #ifdef OVERWORLD || END
            #if GLOBAL_ILLUMINATION == 1
                vec3 skyIndirect = GetSkyIllumination(normalM, viewPos.xyz, nViewPos, dither, skyLightFactor, vec3(0.0), VdotU, VdotS);
                //vec3 GlobalIllumination(vec3 viewPos, vec3 playerPos, vec3 normal, vec3 viewDir, float skyLightFactor, float linearZ0, float dither) {
                color.rgb = mix(color.rgb, min(color.rgb, GITonemap(skyIndirect)), darkness);   
                color.rgb += GITonemap(GlobalIllumination(viewPos.xyz, playerPos, normalM, nViewPos, skyLightFactor, linearZ0, dither));
                //color.rgb += GITonemap(GI(color.rgb, normalM, viewPos.xyz, depthtex0, dither));

                // SAMPLE GI FOR BLISS SHADERS, MUST NOT USE
                //vec3 indirect = GITonemap(applySSRT(Indirect_lighting, minLightColor, viewPos.xyz, dither2, skyLightFactor, entityOrHand));
                //color.rgb += mix(color.rgb * vec3(0.1), min(color.rgb, indirect), darkness);  
            #endif
        #endif
        

        #ifdef PBR_REFLECTIONS

            float fresnel = clamp(1.0 + dot(normalM, nViewPos), 0.0, 1.0);

            float fresnelFactor = (1.0 - smoothnessD) * 0.7;
            float fresnelM = max(fresnel - fresnelFactor, 0.0) / (1.0 - fresnelFactor);
            #ifdef IPBR
                fresnelM = mix(pow2(fresnelM), fresnelM * 0.75 + 0.25, intenseFresnel);
            #else
                fresnelM = mix(pow2(fresnelM), fresnelM * 0.5 + 0.5, intenseFresnel);
            #endif
            fresnelM = fresnelM * sqrt1(smoothnessD) - dither * 0.001;

            if (fresnelM > 0.0) {
                #ifdef TAA
                    float noiseMult = 0.3;
                #else
                    float noiseMult = 0.1;
                #endif
                #ifdef TEMPORAL_FILTER
                    float blendFactor = 1.0;
                    float writeFactor = 1.0;
                #endif
                #if defined CUSTOM_PBR || defined IPBR && defined IS_IRIS
                    if (entityOrHand) {
                        noiseMult *= 0.1;
                        #ifdef TEMPORAL_FILTER
                            blendFactor = 0.0;
                            writeFactor = 0.0;
                        #endif
                    }
                #endif
                noiseMult *= pow2(1.0 - smoothnessD);

                vec2 roughCoord = gl_FragCoord.xy / 128.0;
                vec3 roughNoise = vec3(
                    texture2D(noisetex, roughCoord).r,
                    texture2D(noisetex, roughCoord + 0.09375).r,
                    texture2D(noisetex, roughCoord + 0.1875).r
                );
                roughNoise = fract(roughNoise + vec3(dither, dither * goldenRatio, dither * pow2(goldenRatio)));
                roughNoise = noiseMult * (roughNoise - vec3(0.5));

                normalM += roughNoise;

                vec4 reflection = GetReflection(normalM, viewPos.xyz, nViewPos, playerPos, lViewPos, z0,
                                                depthtex0, dither, skyLightFactor, fresnel,
                                                smoothnessD, vec3(0.0), vec3(0.0), vec3(0.0), 0.0);

                vec3 colorAdd = reflection.rgb * reflectColor;
                //float colorMultInv = (0.75 - intenseFresnel * 0.5) * max(reflection.a, skyLightFactor);
                //float colorMultInv = max(reflection.a, skyLightFactor);
                float colorMultInv = 1.0;

                vec3 colorP = color;

                #ifdef TEMPORAL_FILTER
                    vec3 cameraOffset = cameraPosition - previousCameraPosition;
                    vec2 prvCoord = SHalfReprojection(playerPos, cameraOffset);
                    #if defined IPBR && !defined GENERATED_NORMALS
                        vec2 prvRefCoord = Reprojection(vec3(texCoord, max(refPos.z, z0)), cameraOffset);
                        vec4 oldRef = texture2D(colortex7, prvRefCoord);
                    #else
                        vec2 prvRefCoord = Reprojection(vec3(texCoord, z0), cameraOffset);
                        vec2 prvRefCoord2 = Reprojection(vec3(texCoord, max(refPos.z, z0)), cameraOffset);
                        vec4 oldRef1 = texture2D(colortex7, prvRefCoord);
                        vec4 oldRef2 = texture2D(colortex7, prvRefCoord2);
                        vec3 dif1 = colorAdd - oldRef1.rgb;
                        vec3 dif2 = colorAdd - oldRef2.rgb;
                        float dotDif1 = dot(dif1, dif1);
                        float dotDif2 = dot(dif2, dif2);

                        float oldRefMixer = clamp01((dotDif1 - dotDif2) * 500.0);
                        vec4 oldRef = mix(oldRef1, oldRef2, oldRefMixer);
                    #endif

                    vec4 newRef = vec4(colorAdd, colorMultInv);
                    vec2 oppositePreCoord = texCoord - 2.0 * (prvCoord - texCoord);

                    // Reduce blending at speed
                    blendFactor *= float(prvCoord.x > 0.0 && prvCoord.x < 1.0 && prvCoord.y > 0.0 && prvCoord.y < 1.0);
                    float velocity = length(cameraOffset) * max(16.0 - lViewPos / gbufferProjection[1][1], 3.0);
                    blendFactor *= mix(1.0, exp(-velocity) * 0.5 + 0.5, smoothnessD);

                    // Reduce blending if depth changed
                    float linearZDif = abs(GetLinearDepth(texture2D(colortex1, oppositePreCoord).r) - linearZ0) * far;
                    blendFactor *= max0(2.0 - linearZDif) * 0.5;
                    //color = mix(vec3(1,1,0), color, max0(2.0 - linearZDif) * 0.5);

                    // Reduce blending if normal changed
                    vec3 texture5P = texture2D(colortex5, oppositePreCoord, 0).rgb;
                    vec3 texture5Dif = abs(texture5 - texture5P);
                    if (texture5Dif != clamp(texture5Dif, vec3(-0.004), vec3(0.004))) {
                        blendFactor = 0.0;
                        //color.rgb = vec3(1,0,1);
                    }

                    blendFactor = max0(blendFactor); // Prevent first frame NaN
                    newRef = max(newRef, vec4(0.0)); // Prevent random NaNs from persisting
                    refToWrite = mix(newRef, oldRef, blendFactor * 0.95);
                    refToWrite = mix(max(refToWrite, newRef), refToWrite, pow2(pow2(pow2(refToWrite.a))));
                    
                    color.rgb *= 1.0 - refToWrite.a * fresnelM;
                    color.rgb += refToWrite.rgb * fresnelM;
                    refToWrite *= writeFactor;
                #else
                    color *= 1.0 - colorMultInv * fresnelM;
                    color += colorAdd * fresnelM;
                #endif

                color = max(colorP, color); // Prevents reflections from making a surface darker

                //if (gl_FragCoord.x > 960) color = vec3(5.25,0,5.25);
            }
        #endif

        #ifdef WORLD_OUTLINE
            #ifndef WORLD_OUTLINE_ON_ENTITIES
                if (!entityOrHand)
            #endif
            DoWorldOutline(color, linearZ0);
        #endif

        #ifndef SKY_EFFECT_REFLECTION
            waterRefColor = sqrt(color) - 1.0;
        #else
            waterRefColor = color;
        #endif

        DoFog(color, skyFade, lViewPos, playerPos, VdotU, VdotS, dither);
    } else { // Sky
        #ifdef DISTANT_HORIZONS
            float z0DH = texelFetch(dhDepthTex, texelCoord, 0).r;
            if (z0DH < 1.0) { // Distant Horizons Chunks
                vec4 screenPosDH = vec4(texCoord, z0DH, 1.0);
                vec4 viewPosDH = dhProjectionInverse * (screenPosDH * 2.0 - 1.0);
                viewPosDH /= viewPosDH.w;
                lViewPos = length(viewPosDH.xyz);
                playerPos = ViewToPlayer(viewPosDH.xyz);
                
                #ifndef SKY_EFFECT_REFLECTION
                    waterRefColor = sqrt(color) - 1.0;
                #else
                    waterRefColor = color;
                #endif
                
                DoFog(color.rgb, skyFade, lViewPos, playerPos, VdotU, VdotS, dither);
            } else { // Start of Actual Sky
        #endif

        skyFade = 1.0;

        #ifdef OVERWORLD
            #if AURORA_STYLE > 0
                auroraBorealis = GetAuroraBorealis(viewPos.xyz, VdotU, dither);
                color.rgb += auroraBorealis;
            #endif
            #ifdef NIGHT_NEBULA
                nightNebula += GetNightNebula(viewPos.xyz, VdotU, VdotS);
                color.rgb += nightNebula;
            #endif
        #endif
        #ifdef NETHER
            color.rgb = netherColor * (1.0 - maxBlindnessDarkness);

            #ifdef ATM_COLOR_MULTS
                color.rgb *= atmColorMult;
            #endif
        #endif
        #ifdef END
            //color
            //color.rgb = endSkyColor;

            color.rgb += GetEnderStars(viewPos.xyz, VdotU);
            color.rgb = mix(endSkyColor, color, VdotU) * 0.8;
            color.rgb *= 1.0 - maxBlindnessDarkness;

            #ifdef ATM_COLOR_MULTS
                color.rgb *= atmColorMult;
            #endif
        #endif

        #ifdef DISTANT_HORIZONS
        } // End of Actual Sky
        #endif
    }

    float cloudLinearDepth = 1.0;
    vec4 clouds = vec4(0.0);

    #ifdef VL_CLOUDS_ACTIVE
        float cloudZCheck = 0.56;

        if (z0 > cloudZCheck) {
            clouds = GetClouds(cloudLinearDepth, skyFade, cameraPosition, playerPos,
                               lViewPos, VdotS, VdotU, dither, auroraBorealis, nightNebula);

            color = mix(color, clouds.rgb, clouds.a);
        }
    #endif

    #ifdef SKY_EFFECT_REFLECTION
        waterRefColor = mix(waterRefColor, clouds.rgb, clouds.a);
        waterRefColor = sqrt(waterRefColor) - 1.0;
    #endif

    #if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
        if (viewWidth + viewHeight - gl_FragCoord.x - gl_FragCoord.y < 1.5)
            cloudLinearDepth = vlFactor;
    #endif

    #if defined OVERWORLD && defined ATMOSPHERIC_FOG && (defined SPECIAL_BIOME_WEATHER || RAIN_STYLE == 2)
        float altitudeFactorRaw = GetAtmFogAltitudeFactor(playerPos.y + cameraPosition.y);
        vec3 atmFogColor = GetAtmFogColor(altitudeFactorRaw, VdotS);

        #if RAIN_STYLE == 2
            float factor = 1.0;
        #else
            float factor = max(inSnowy, inDry);
        #endif

        color = mix(color, atmFogColor, 0.5 * rainFactor * factor * sqrt1(skyFade));
    #endif

    #ifdef DARK_OUTLINE
        if (clouds.a < 0.5) DoDarkOutline(color, skyFade, z0, dither);
    #endif

    /*DRAWBUFFERS:054*/
    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(waterRefColor, 1.0 - skyFade);
    gl_FragData[2] = vec4(cloudLinearDepth, 0.0, 0.0, 1.0);
    #ifdef TEMPORAL_FILTER
        /*DRAWBUFFERS:0547*/
        gl_FragData[3] = refToWrite;
    #endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

out vec3 normal;

flat out vec3 upVec, sunVec;

#if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
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
    normal = normalize(gl_NormalMatrix * gl_Normal);

    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = GetSunVector();

    #if defined LIGHTSHAFTS_ACTIVE && (LIGHTSHAFT_BEHAVIOUR == 1 && SHADOW_QUALITY >= 1 || defined END)
        vlFactor = texelFetch(colortex4, ivec2(viewWidth-1, viewHeight-1), 0).r;

        #ifdef END
            if (frameCounter % int(0.06666 / frameTimeSmooth + 0.5) == 0) { // Change speed is not too different above 10 fps
                vec2 absCamPosXZ = abs(cameraPosition.xz);
                float maxCamPosXZ = max(absCamPosXZ.x, absCamPosXZ.y);

                if (gl_Fog.start / far > 0.5 || maxCamPosXZ > 350.0) vlFactor = max(vlFactor - OSIEBCA*2, 0.0);
                else                                                 vlFactor = min(vlFactor + OSIEBCA*2, 1.0);
            }
        #endif
    #endif
}

#endif
