// LQ_CLOUD macro is really just to lower the quality of clouds for cloud dependent effects such as crepuscular rays and cloud shadows in order to improve performance
// if anybody knows sees this and would like to change the way i make the effects mentioned, for optimization, please let me know!

#define LOWER_CLOUD_LAYER
#define CLOUD_STEP_QUALITY 1.5 //[1.0 1.5 2.0 2.5 3.0 3.5 4.0]
#define CLOUD_SHADING_QUALITY 9 //[6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24]

#define CLOUD_SHADING_STRENGTH 3.0 //[1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]

#define CLOUD_RENDER_DISTANCE 2048 //[1024 2048 4096]

#define CURVED_CLOUDS           //[0 off, 1 on]
#define PLANET_RADIUS 60000      //[30000 45000 60000 80000 100000]  // in blocks
#define CURVATURE_STRENGTH 1.0     //[0.0 0.5 1.0 1.25 1.5 2.0]

#define LOWER_CLOUD_LAYER_MULT       0.4   //[0.4 0.45 0.5 0.55 0.6 0.65 0.7]
#define LOWER_CLOUD_LAYER_SIZE_MULT  3.25    //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]
#define LOWER_CLOUD_LAYER_SIZE_MULT_M (200.0 * 0.01)
#define LOWER_CLOUD_LAYER_GRANULARITY 0.4 //[0.1 0.2 0.3 0.4 0.475 0.5 0.6 0.7 0.8 0.9 1.0]
#define LOWER_CLOUD_LAYER_ALT        180   //[-96 -92 -88 -84 -80 -76 -72 -68 -64 -60 -56 -52 -48 -44 -40 -36 -32 -28 -24 -20 -16 -10 -8 -4 0 4 8 12 16 20 22 24 28 32 36 40 44 48 52 56 60 64 68 72 76 80 84 88 92 96 100 104 108 112 116 120 124 128 132 136 140 144 148 152 156 160 164 168 172 176 180 184 188 192 196 200 204 208 212 216 220 224 228 232 236 240 244 248 252 256 260 264 268 272 276 280 284 288 292 296 300 304 308 312 316 320 324 328 332 336 340 344 348 352 356 360 364 368 372 376 380 384 388 392 396 400 404 408 412 416 420 424 428 432 436 440 444 448 452 456 460 464 468 472 476 480 484 488 492 496 500 510 520 530 540 550 560 570 580 590 600 610 620 630 640 650 660 670 680 690 700 710 720 730 740 750 760 770 780 790 800]
#define LOWER_CLOUD_LAYER_HEIGHT     48.0   //[6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0 24.0 32.0 48.0 54.0 64.0 96.0 128.0]
#define LOWER_CLOUD_LAYER_COVERAGE   0.42   //[0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5]

#ifndef DISTANT_HORIZONS
    #define CLOUD_BASE_ADD 0.65
    #define CLOUD_FAR_ADD 0.01
    #define CLOUD_ABOVE_ADD 0.1
#else
    #define CLOUD_BASE_ADD 0.9
    #define CLOUD_FAR_ADD -0.005
    #define CLOUD_ABOVE_ADD 0.03
#endif

const int   lowerLayerAlt = int(LOWER_CLOUD_LAYER_ALT);
float       lowerLayerStretch = LOWER_CLOUD_LAYER_HEIGHT;
float       lowerLayerHeight  = lowerLayerStretch * 2.0;

#ifdef LQ_CLOUD
    #define CLOUD_SHADING_STRENGTH_MULT ((CLOUD_SHADING_STRENGTH * 0.85) / CLOUD_SHADING_STRENGTH)
#else
    #define CLOUD_SHADING_STRENGTH_MULT CLOUD_SHADING_STRENGTH
#endif

#include "/lib/colors/lightAndAmbientColors.glsl"
#include "/lib/colors/cloudColors.glsl"
#include "/lib/atmospherics/sky.glsl"

#if SHADOW_QUALITY > -1 || VL_CLOUD_SHADOW
    vec3 GetShadowOnCloudPosition(vec3 tracePos, vec3 cameraPos) {
        vec3 wpos = PlayerToShadow(tracePos - cameraPos);
        float distb = sqrt(wpos.x * wpos.x + wpos.y * wpos.y);
        float distortFactor = 1.0 - shadowMapBias + distb * shadowMapBias;
        vec3 shadowPosition = vec3(vec2(wpos.xy / distortFactor), wpos.z * 0.2);
        return shadowPosition * 0.5 + 0.5;
    }

    bool GetShadowOnCloud(vec3 tracePos, vec3 cameraPos, int cloudAltitude, float lowerPlaneAltitude, float higherPlaneAltitude) {
        const float cloudShadowOffset = 0.5;

        vec3 shadowPosition0 = GetShadowOnCloudPosition(tracePos, cameraPos);
        if (length(shadowPosition0.xy * 2.0 - 1.0) < 1.0) {
            float shadowsample0 = shadow2D(shadowtex0, shadowPosition0).z;
            if (shadowsample0 == 0.0) return true;
        }
        return false;
    }
#endif

#if CLOUD_UNBOUND_SIZE_MULT != 100
    #define CLOUD_UNBOUND_SIZE_MULT_M CLOUD_UNBOUND_SIZE_MULT * 0.01
#endif

float Noise3D(vec3 p) {
    p.z = fract(p.z) * 128.0;
    float iz = floor(p.z);
    float fz = fract(p.z);
    vec2 a_off = vec2(23.0, 29.0) * (iz) / 128.0;
    vec2 b_off = vec2(23.0, 29.0) * (iz + 1.0) / 128.0;
    float a = texture2D(noisetex, p.xy + a_off).r;
    float b = texture2D(noisetex, p.xy + b_off).r;
    return mix(a, b, fz);
}


float Noise3D2(vec3 p) {
    p.z = fract(p.z) * 20.0;
    float iz = floor(p.z);
    float fz = fract(p.z);
    vec2 a_off = vec2(23.0, 29.0) * (iz) / 20.0;
    vec2 b_off = vec2(23.0, 29.0) * (iz + 1.0) / 20.0;
    float a = texture2D(colortex3, p.xy + a_off).r;
    float b = texture2D(colortex3, p.xy + b_off).b;
    return mix(a, b, fz);
}


float GetWind() {
    float wind = 0.0004;
    #if CLOUD_SPEED_MULT == 100
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        wind *= syncedTime;
    #else
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        wind *= frameTimeCounter * CLOUD_SPEED_MULT_M;
    #endif
    return wind;
}

vec3 Offset(float wind) { return vec3(wind * 0.7, wind * 0.5, wind * 0.2); }

float getCloudMap(vec3 p){
    vec2 uv = 0.5 + 0.5 * (p.xz/(1.8 * 100.0));
    return texture2D(noisetex, uv).x;
}

float angle = GetWind() * 0.05; // radians per second
vec3 windDir = normalize(vec3(cos(angle), 0.0, sin(angle)));
mat3 shearMatrix = mat3(
    1.0 + windDir.x * 0.2, windDir.x * 0.1, 0.0,
    windDir.y * 0.1,       1.0,           0.0,
    windDir.z * 0.2,       windDir.z * 0.1, 1.0
);

float lowerLayerCloudSizeMult = LOWER_CLOUD_LAYER_SIZE_MULT;

float GetLowerLayerDetail(vec3 pos, vec3 offset, float persistence) {
    float amplitude = 1.0;
    float total = 0.0;
    float detail = 0.0;

    vec3 p = pos;

    #ifndef LQ_CLOUD
        int detailSamples = 3;
    #else
        #ifdef COMPOSITE
            int detailSamples = 2;  // crepuscular rays
        #else
            int detailSamples = 1;  // cloud shadows
        #endif
    #endif

    for (int i = 0; i < detailSamples; ++i) {
        vec3 windOffset = windDir * GetWind() * 0.1 * float(i);
        float n = Noise3D(p * 4.0 / lowerLayerCloudSizeMult + offset * 1.5 + windOffset);
        detail += n * amplitude;
        total += amplitude;
        amplitude *= persistence;

        p *= 5.0;
    }

    return detail / total;
}

float LC_Coverage2D(vec2 xz, float windTick) {
    float n  = texture2D(noisetex, xz * 0.0012 + vec2(windTick)).r;
            n += texture2D(noisetex, xz * 0.0040 + vec2(windTick * 1.7)).r * 0.5;
            n  = n * (1.0 + rainFactor * 0.1) - nightFactor;

    float cov = smoothstep(0.35, 0.85, n) * LOWER_CLOUD_LAYER_COVERAGE;
    return clamp(cov, 0.0, 1.0);
}

float LC_DensityGain(float y, int cloudAltitude, float stretch) {
    float base = float(cloudAltitude) - stretch;
    float top  = float(cloudAltitude) + stretch;
    float t    = clamp((y - base) / max(top - base, 1e-3), 0.0, 1.0);

    float g = 0.001;
            g += smoothstep(0.00, 0.20, t) * 0.16;
            g += smoothstep(0.10, 0.50, t) * 0.40;
            g += smoothstep(0.10, 0.60, t) * 1.30;
            g += smoothstep(0.40, 1.00, t) * 1.00;
    return g;
}

float curvatureDrop(float dx) {
#ifdef CURVED_CLOUDS
    // Sagitta approximation: how much the horizon "falls" after dx blocks
    return CURVATURE_STRENGTH * (dx * dx) / max(2.0 * PLANET_RADIUS, 1.0);
#else
    return 0.0;
#endif
}

float curvedY(vec3 pos, vec3 cam) {
    // Apply curvature only by distance in XZ from the camera
    float dx = length((pos - cam).xz);
    return pos.y - curvatureDrop(dx);
}

float GetLowerLayerCloud(vec3 tracePos, int steps, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY,
                         float noisePersistence, float mult, float size) {
    vec3 tracePosM = shearMatrix * tracePos * (0.00018 * size);
            //tracePosM.y *= 0.85;

    float shearAmount = 0.25;
    //tracePosM.x += tracePosM.y * windDir.x * shearAmount;
    tracePosM.z *= 1.25;

    vec3 offset = Offset(GetWind() * size);

    float base = Noise3D(tracePosM * 0.71 / lowerLayerCloudSizeMult + offset) * 12.0;
            base+= Noise3D(tracePosM * 0.85 / lowerLayerCloudSizeMult + offset) * 6.0;

            base+= Noise3D(tracePosM * 1.24 / lowerLayerCloudSizeMult + offset) * 3.0;
            base+= Noise3D(tracePosM * 1.53 / lowerLayerCloudSizeMult + offset) * 1.0;
            base /= 12.0 / LOWER_CLOUD_LAYER_COVERAGE;
            base += rainFactor * 0.0001;
            //base-= nightFactor * 0.075 - rainFactor * 0.2;
            //base -= invNoonFactor * 0.025;

    float detail   = GetLowerLayerDetail(tracePosM, offset, noisePersistence);
    float combined = mix(base, base * detail, 0.475);
            combined = max(combined - 0.2, 0.0);
            combined = pow(combined, 1.35) * mult;

    
    float baseAlt   = float(cloudAltitude) - lowerLayerStretch;
    float topAlt    = float(cloudAltitude) + lowerLayerStretch;
    float thick     = max(topAlt - baseAlt, 1e-3);
    float y = tracePos.y + curvatureDrop(lTracePosXZ);

    float lowFade   = smoothstep(baseAlt,            baseAlt + thick * 0.075, y);
    float highFade  = 1.0 - smoothstep(baseAlt + thick * 0.60, topAlt,        y);

    float lowErode  = 1.0 - smoothstep(baseAlt,             baseAlt + thick * 0.13, y);
    float highErode =        smoothstep(baseAlt + thick * 0.20, topAlt,                y);

    float densityFade = 0.1;
            densityFade += smoothstep(baseAlt,               baseAlt + thick*0.20, y) * 0.16;
            densityFade += smoothstep(baseAlt + thick*0.10,  baseAlt + thick*0.50, y) * 0.40;
            densityFade += smoothstep(baseAlt + thick*0.10,  baseAlt + thick*0.60, y) * 1.30;
            densityFade += smoothstep(baseAlt + thick*0.40,  topAlt,               y) * 1.00;

    combined *= mix(12.0, lowFade, 0.6);
    combined *= mix(1.0, highFade, 0.6);
    combined -= lowErode  * 0.081;
    combined -= highErode * 0.05;
    combined  = max(combined, 0.0);
    combined *= densityFade;

    float windTick    = GetWind();

    float coverage      = LOWER_CLOUD_LAYER_COVERAGE;
    float covMul        = mix(0.88, 1.18, coverage); 
    combined *= covMul;
    combined  = max(combined - (1.0 - coverage) * 0.125, 0.0);

    float carve = Noise3D2(tracePosM * 3.9 + offset * 0.5);
    combined    = max(combined - (1.0 - carve) * 0.25, 0.0);

    float densityGain = LC_DensityGain(y, cloudAltitude, lowerLayerStretch);
    combined *= densityGain;

    float thicknessVF   = lowerLayerStretch * 1.25;
    float fadeThickness = max(thicknessVF, 24.0);
    float bottomAlt = float(cloudAltitude) - 0.0001 * fadeThickness;
    float tv = clamp((y - bottomAlt) / fadeThickness, 0.0, 1.0); // y is already curved
          tv = 1.0 - tv; // 1 at top

    float shoulder   = 0.25;
    float rise       = smoothstep(0.0,            shoulder, tv);
    float fall       = 1.0 - smoothstep(1.0 - shoulder, 1.0, tv);
    float trapezoid  = rise * fall;
    float topBias    = mix(1.0, 1.12, smoothstep(0.55, 1.0, tv));

    float verticalFade = clamp(trapezoid * topBias, 0.0, 1.0);

    return clamp(combined * verticalFade, 0.0, 1.0);
}

float PhaseHG(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159 * pow(denom, 1.5));
}

const float invLog2 = 1.0 / log(2.0);

float vc_mie(float x, float g) {
    float t = 1.0 + g*g - 2.0*g*x;
    return (1.0 - g*g) / ((6.0*3.14159265) * t * (t*0.5 + 0.5)) * 0.85;
}

float vc_phase(float cosTheta, float g) {
    float mie1 = vc_mie(cosTheta,  0.5*g) + vc_mie(cosTheta, 0.55*g);
    float mie2 = vc_mie(cosTheta, -0.25*g);
    return mix(mie1 * 0.1, mie2 * 2.0, 0.35);
}

float SampleCloudShadow(vec3 tracePos, vec3 lightDir, float dither, int steps, int cloudAltitude, float stretch, float size, int layer) {
    float shadow = 0.0;
    float density = 0.0;
    vec3 samplePos = tracePos;

    const float shadowDensityScale = 1.0;

    for (int i = 0; i < steps; ++i) {
        samplePos += lightDir * 6.0 + dither;
        
        float dxShadow = length((samplePos - cameraPosition).xz);
        float yCurvedS = samplePos.y + curvatureDrop(dxShadow);
        if (abs(yCurvedS - float(cloudAltitude)) > stretch * 3.0) break;

        float density = clamp(GetLowerLayerCloud(samplePos, steps, cloudAltitude,
                                                dxShadow, yCurvedS - float(cloudAltitude),
                                                0.6, 1.0, size), 0.0, 1.0);

        density *= shadowDensityScale;
        shadow += density / float(i + 1);
    }

    return clamp(shadow / float(steps), 0.0, 1.0);
}

vec2 GetPowder(float density) {
    float powder = 1.0 - exp2(-density * 2.0 * 1.442695041);
    return vec2(0.6 + 0.4 * powder,   // Sun
                0.5 + 0.5 * powder);  // Sky
}


// cloud effects like cloud shadows and crepuscular rays shouldnt be using this but i added LQ_CLOUD macro for future purposes, might end up deleting later tho... 
vec4 GetVolumetricClouds(int cloudAltitude, 
    float distanceThreshold, 
    inout float cloudLinearDepth, 
    float skyFade, 
    float skyMult0, 
    vec3 cameraPos, 
    vec3 nPlayerPos, 
    float lViewPosM, 
    float VdotS, 
    float VdotU, 
    float dither, 
    float noisePersistance, 
    float mult, 
    float size,
    int layer
    )
{
    vec4 volumetricClouds = vec4(0.0);

    #if CLOUD_QUALITY <= 1
        return volumetricClouds;
    #else
        float higherPlaneAltitude = cloudAltitude + lowerLayerStretch;
        float lowerPlaneAltitude  = cloudAltitude - lowerLayerStretch;

        float lowerPlaneDistance  = (lowerPlaneAltitude - cameraPos.y) / nPlayerPos.y;
        float higherPlaneDistance = (higherPlaneAltitude - cameraPos.y) / nPlayerPos.y;
        float minPlaneDistance    = max(min(lowerPlaneDistance, higherPlaneDistance), 0.0);
        float maxPlaneDistance    = max(lowerPlaneDistance, higherPlaneDistance);
        if (maxPlaneDistance < 0.0) return vec4(0.0);
        float planeDistanceDif    = maxPlaneDistance - minPlaneDistance;

        float baseStep   = 16.0 / sqrt(300.0);
        int   sampleCount= int(planeDistanceDif / baseStep + dither + 1);

        // cloud steps are used for the shadow sampling on clouds for directional lighting, not for shadows and crepuscular rays, so we dont need itterate through so many again
        #ifndef LQ_CLOUD
            int   cloudSteps = CLOUD_SHADING_QUALITY;
        #else
            int   cloudSteps = 2;
        #endif

        #ifdef FIX_AMD_REFLECTION_CRASH
            sampleCount = min(sampleCount, 30);
        #endif

        vec3  rayStep   = nPlayerPos * (int(LOWER_CLOUD_LAYER_HEIGHT) / CLOUD_STEP_QUALITY);
            #ifdef LQ_CLOUD || DISTANT_HORIZONS
                rayStep   = nPlayerPos * (int(LOWER_CLOUD_LAYER_HEIGHT) / 1.0);
            #endif

        float stepLen   = length(rayStep);
        vec3  tracePos  = cameraPos + minPlaneDistance * nPlayerPos + rayStep * dither;

        vec3 sunDir   = normalize(mat3(gbufferModelViewInverse) * lightVec);
        float mu      = dot(sunDir, -nPlayerPos);
        float phaseHG = vc_phase(mu, 0.85);

        const float BREAK_THRESHOLD = 0.08;
        float sigma_s = 0.2 * mult;  // scattering
        float sigma_t = 0.1 * mult;  // extinction

        float transmittance = 1.0;
        float firstHitPos   = 0.0;
        float lastLxz       = 0.0;
        float prevDens      = 0.0;
        vec2  scatter       = vec2(0.0); // x: direct sun, y: sky

        for (int i = 0; i < sampleCount; i++) {
            if (transmittance < BREAK_THRESHOLD) break;

            tracePos += rayStep;

            float yCurved = tracePos.y + curvatureDrop(length((tracePos - cameraPos).xz));
            if (abs(yCurved - float(cloudAltitude)) > lowerLayerStretch * 3.0) break;

            vec3  toPos      = tracePos - cameraPos;
            float lTracePos  = length(toPos);
            float lTracePosXZ= length(toPos.xz);
            lastLxz = lTracePosXZ;

            if (lTracePosXZ > distanceThreshold) break;
            if (lTracePos > lViewPosM && skyFade < 0.7) continue;

            float density = GetLowerLayerCloud(tracePos, cloudSteps, cloudAltitude,
                                               lTracePosXZ, toPos.y,
                                               noisePersistance, 1.0, size);
            if (density <= 0.5) continue;

            if (firstHitPos <= 0.0) firstHitPos = lTracePos;

            float shadow     = SampleCloudShadow(tracePos, sunDir, dither, cloudSteps,
                                                 cloudAltitude, lowerLayerStretch, size, 1);
            float lightTrans = 1.0 - clamp(shadow * CLOUD_SHADING_STRENGTH_MULT, 0.0, 1.0);

            float skylight = clamp((yCurved - lowerPlaneAltitude) /
                       max(higherPlaneAltitude - lowerPlaneAltitude, 1e-3), 0.0, 1.0);

            float extinction = density * sigma_t;
            float stepT      = exp2(-extinction * stepLen * 1.442695041);
            float integral   = (sigma_t > 1e-5) ? (1.0 - stepT) / sigma_t : stepLen;

            vec2 powderMul = GetPowder(density);
            float powderSun = powderMul.x;
            float powderSky = powderMul.y;

            float directStep = sigma_s * phaseHG * lightTrans * powderSun;
            float skyStep    = sigma_s * 0.0795775 * (0.4 + 0.6 * skylight) * powderSky;

            scatter.x += transmittance * integral * directStep * 1.15;
            scatter.y += transmittance * integral * skyStep * 1.15;

            scatter.y += transmittance * (1.0 - stepT) * (0.3 + 0.7 * skylight) * 0.06;

            transmittance *= stepT;
            float stepFactor = mix(1.6, 0.8, smoothstep(0.06, 0.35, max(density, prevDens)));
            tracePos += rayStep * (stepFactor - 1.0);
            prevDens = density;
        }

        vec3 skyColor = GetSky(VdotU, VdotS, dither, true, false);
        vec3 directSun = (lightColor * 128.4) * (scatter.x);
        vec3 ambSky    = (skyColor * 2.0) * scatter.y;
        vec3 cloudCol  = directSun + ambSky;

        float cloudFogFactor = 0.0;
        
        if (firstHitPos > 0.0) {
            float distF = clamp((distanceThreshold - lastLxz) / distanceThreshold, 0.0, 1.0);
            cloudFogFactor = distF;
        }

        float skyMult1 = 1.0 - 0.2 * max(sunVisibility2, nightFactor);
        float skyMult2 = 1.0 - 0.33333;
        vec3 finalColor = mix(skyColor, cloudCol * skyMult1, cloudFogFactor * skyMult2 * 0.75);
        finalColor *= pow2(1.0 - maxBlindnessDarkness);

        volumetricClouds.rgb = finalColor;
        volumetricClouds.a   = 1.0 - transmittance;

        if (volumetricClouds.a > 0.5 && firstHitPos > 0.0)
            cloudLinearDepth = sqrt(firstHitPos / renderDistance);

        return volumetricClouds;
    #endif
}

vec4 GetClouds(inout float cloudLinearDepth, float skyFade, vec3 cameraPos, vec3 playerPos,
            float lViewPos, float VdotS, float VdotU, float dither, vec3 auroraBorealis, vec3 nightNebula) {

    vec4 clouds = vec4(0.0);
    
    vec3 nPlayerPos = normalize(playerPos);
    float lViewPosM = lViewPos < renderDistance * 1.5 ? lViewPos - 1.0 : 1000000000.0;
    float skyMult0 = pow2(skyFade * 3.333333 - 2.333333);

    float thresholdMix = pow2(clamp01(VdotU * 5.0));
    float thresholdF = mix(far, float(CLOUD_RENDER_DISTANCE), thresholdMix * 0.5 + 0.5);
    #ifdef DISTANT_HORIZONS
        thresholdF = max(thresholdF, renderDistance * 0.75);
    #endif

    /*
    vec3 cloudColorMult = vec3(1.0);
    #if CLOUD_R != 100 || CLOUD_G != 100 || CLOUD_B != 100
        cloudColorMult *= vec3(CLOUD_R, CLOUD_G, CLOUD_B) * 0.01;
    #endif
    cloudAmbientColor *= cloudColorMult;
    cloudLightColor   *= cloudColorMult;
    */

    #if CLOUD_QUALITY == 3
        #ifdef LOWER_CLOUD_LAYER
        clouds = GetVolumetricClouds(lowerLayerAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                     cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                     LOWER_CLOUD_LAYER_GRANULARITY, LOWER_CLOUD_LAYER_MULT, (200.0 * 0.01), 1);
        #endif
    #else
        clouds = GetVolumetricClouds(lowerLayerAlt, thresholdF, cloudLinearDepth, skyFade, skyMult0,
                                     cameraPos, nPlayerPos, lViewPosM, VdotS, VdotU, dither,
                                     LOWER_CLOUD_LAYER_GRANULARITY, LOWER_CLOUD_LAYER_MULT, (200.0 * 0.01), 1);
    #endif

    #ifdef ATM_COLOR_MULTS
        clouds.rgb *= sqrtAtmColorMult;
    #endif
    #ifdef MOON_PHASE_INF_ATMOSPHERE
        clouds.rgb *= moonPhaseInfluence;
    #endif
    #if AURORA_STYLE > 0
        clouds.rgb += auroraBorealis * 0.1;
    #endif
    #ifdef NIGHT_NEBULA
        clouds.rgb += nightNebula * 0.2;
    #endif

    clouds += (dither - 0.5) / 64;
    
    return clouds;
}
