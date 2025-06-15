#if CLOUD_UNBOUND_SIZE_MULT != 100
    #define CLOUD_UNBOUND_SIZE_MULT_M CLOUD_UNBOUND_SIZE_MULT * 0.01
#endif

float cloudStretch = 12.0;
float cloudHeight = cloudStretch * 2.0;


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

vec3 modulo(vec3 m, float n){
  return mod(mod(m, n) + n, n);
}

// 5th order polynomial interpolation
vec3 fade(vec3 t){
    return (t * t * t) * (t * (t * 6.0 - 15.0) + 10.0);
}

#define SIZE 8.0

// https://www.shadertoy.com/view/4djSRW
vec3 hash(vec3 p3){
    p3 = modulo(p3, SIZE);
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return 2.0 * fract((p3.xxy + p3.yxx) * p3.zyx) - 1.0;
}

float gradientNoise(vec3 p){

    vec3 i = floor(p);
    vec3 f = fract(p);
	
	vec3 u = fade(f);
    
    /*
    * For 1D, the gradient of slope g at vertex u has the form h(x) = g * (x - u), where u 
    * is an integer and g is in [-1, 1]. This is the equation for a line with slope g which 
    * intersects the x-axis at u.
    * For N dimensional noise, use dot product instead of multiplication, and do 
    * component-wise interpolation (for 3D, trilinear)
    */
    return mix( mix( mix( dot( hash(i + vec3(0.0,0.0,0.0)), f - vec3(0.0,0.0,0.0)), 
              dot( hash(i + vec3(1.0,0.0,0.0)), f - vec3(1.0,0.0,0.0)), u.x),
         mix( dot( hash(i + vec3(0.0,1.0,0.0)), f - vec3(0.0,1.0,0.0)), 
              dot( hash(i + vec3(1.0,1.0,0.0)), f - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( hash(i + vec3(0.0,0.0,1.0)), f - vec3(0.0,0.0,1.0)), 
              dot( hash(i + vec3(1.0,0.0,1.0)), f - vec3(1.0,0.0,1.0)), u.x),
         mix( dot( hash(i + vec3(0.0,1.0,1.0)), f - vec3(0.0,1.0,1.0)), 
              dot( hash(i + vec3(1.0,1.0,1.0)), f - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

float perlin(vec3 pos, float frequency, float straightness){

	//Compute the sum for each octave.
	float sum = 0.0;
	float weightSum = 0.0;
	float weight = 1.0;

	for(int oct = 0; oct < 3; oct++){

        vec3 p = pos * frequency;
        p.x *= straightness;
        float val = 0.5 + 0.5 * gradientNoise(p);
        sum += val * weight;
        weightSum += weight;

        weight *= 0.5;
        frequency *= 2.0;
	}

	return saturate(sum / weightSum);
}

float worley(vec3 pos, float numCells, float straightness){
	vec3 p = pos * numCells;
    p.x *= straightness;
	float d = 1.0e10;
	for (int x = -1; x <= 1; x++){
		for (int y = -1; y <= 1; y++){
			for (int z = -1; z <= 1; z++){
                vec3 tp = floor(p) + vec3(x, y, z);
                tp = p - tp - (0.5 + 0.5 * hash(mod(tp, numCells)));
                d = min(d, dot(tp, tp));
            }
        }
    }
	return 1.0 - saturate(d);
}

/*
float HybridNoise3D(vec3 p) {
    // Internal constants - tweak these to taste:
    float perlinFreq = 1.5;
    float worleyCells = 4.0;

    // Compute Perlin noise part:
    float perlinValue = getPerlinNoise(p, perlinFreq);

    // Compute Worley noise part:
    float worleyValue = worley(p, worleyCells);

    // Combine the noises - blend weights can be changed:
    float combined = mix(perlinValue, worleyValue, 0.5);

    return combined;
}
*/

float GetCloudNoise(vec3 tracePos, int cloudAltitude, float lTracePosXZ, float cloudPlayerPosY, float noisePersistance, float mult, float straightness, float size) {
    vec3 tracePosM = tracePos.xyz * 0.00016;
    float wind = 0.0006;
    float noise = 0.0;
    float currentPersist = 1.0;
    float total = 0.0;

    #if CLOUD_SPEED_MULT == 100
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        wind *= syncedTime;
    #else
        #define CLOUD_SPEED_MULT_M CLOUD_SPEED_MULT * 0.01
        wind *= frameTimeCounter * CLOUD_SPEED_MULT_M;
    #endif
    
    tracePosM *= size;
    wind *= size;


    int sampleCount = 5;
    float persistance = noisePersistance;
        persistance += (rainFactor * 0.1);
    float noiseMult = 1.0;

    #ifndef DEFERRED1
        noiseMult *= 1.2;
    #endif

    //tracePos.y *= straightness;

    for (int i = 0; i < sampleCount; i++) {
        #if CLOUD_QUALITY >= 2
            noise += worley(tracePosM * 1.5 + 0.1 + vec3(wind, 0.0, 0.0), float(sampleCount), straightness) * currentPersist;
            //noise += worley(tracePosM * 1.5 + vec3(wind, 0.0, 0.0), float(sampleCount)) * 0.1;
            //noise += worley(tracePosM * 2.0 + vec3(wind, 0.0, 0.0), float(sampleCount)) * 0.01;
        #else
            noise += worley(tracePosM * 1.0 + vec3(wind, 0.0, 0.0), float(sampleCount)) * currentPersist;
        #endif
        total += currentPersist;

        tracePosM *= 3.0;
        wind *= 0.5;
        currentPersist *= persistance;
        straightness *= straightness;
    }
    noise = pow2(noise / total);

    #ifndef DISTANT_HORIZONS
        #define CLOUD_BASE_ADD 0.65
        #define CLOUD_FAR_ADD 0.01
        #define CLOUD_ABOVE_ADD 0.1
    #else
        #define CLOUD_BASE_ADD 0.9
        #define CLOUD_FAR_ADD -0.005
        #define CLOUD_ABOVE_ADD 0.03
    #endif

    
    noiseMult *= CLOUD_BASE_ADD
                + CLOUD_FAR_ADD * sqrt(lTracePosXZ + 10.0) // more/less clouds far away
                + CLOUD_ABOVE_ADD * clamp01(-cloudPlayerPosY / cloudHeight) // more clouds when camera is above them
                + CLOUD_UNBOUND_RAIN_ADD * (rainFactor * 2.5); // more clouds during rain
    noise *= noiseMult * mult;

    // Original vertical thresholding for cloud edges
    float threshold = clamp(abs(cloudAltitude - tracePos.y) / cloudStretch, 0.001, 0.999);
    threshold = pow2(pow2(pow2(threshold)));

    return noise - (threshold * 0.0001 + 0.25);
}

float PhaseHG(float cosTheta, float g) {
    float denom = 1.0 + g * g - 2.0 * g * cosTheta;
    return (1.0 - g * g) / (4.0 * 3.14159 * pow(denom, 1.5));
}

vec4 GetVolumetricClouds(int cloudAltitude, float distanceThreshold, inout float cloudLinearDepth, float skyFade, float skyMult0, vec3 cameraPos, vec3 nPlayerPos, float lViewPosM, float VdotS, float VdotU, float dither, float noisePersistance, float mult, float straightness, float size) {
    vec4 volumetricClouds = vec4(0.0);

    #if CLOUD_QUALITY <= 1
        return volumetricClouds;
    #else
        float higherPlaneAltitude = cloudAltitude + cloudStretch;
        float lowerPlaneAltitude  = cloudAltitude - cloudStretch;

        float lowerPlaneDistance  = (lowerPlaneAltitude - cameraPos.y) / nPlayerPos.y;
        float higherPlaneDistance = (higherPlaneAltitude - cameraPos.y) / nPlayerPos.y;
        float minPlaneDistance = min(lowerPlaneDistance, higherPlaneDistance);
            minPlaneDistance = max(minPlaneDistance, 0.0);
        float maxPlaneDistance = max(lowerPlaneDistance, higherPlaneDistance);
        if (maxPlaneDistance < 0.0) return vec4(0.0);
        float planeDistanceDif = maxPlaneDistance - minPlaneDistance;

        #ifndef DEFERRED1
            float stepMult = 32.0;
        #elif CLOUD_QUALITY == 1
            float stepMult = 16.0;
        #elif CLOUD_QUALITY == 2
            float stepMult = 24.0;
        #elif CLOUD_QUALITY == 3
            float stepMult = 16.0;
        #endif

        // > 100
        stepMult = stepMult / sqrt(float(size));
        //#endif

        int sampleCount = int(planeDistanceDif / stepMult + dither + 1);
        vec3 traceAdd = nPlayerPos * stepMult;
        vec3 tracePos = cameraPos + minPlaneDistance * nPlayerPos;
        tracePos += traceAdd * dither;
        tracePos.y -= traceAdd.y;

        float firstHitPos = 0.0;
        float VdotSM1 = max0(sunVisibility > 0.5 ? VdotS : - VdotS);
        float VdotSM1M = VdotSM1 * invRainFactor;
        float VdotSM2 = pow2(VdotSM1) * abs(sunVisibility - 0.5) * 2.0;
        float VdotSM3 = VdotSM2 * (2.5 + rainFactor) + 1.5 * rainFactor;

        #ifdef FIX_AMD_REFLECTION_CRASH
            sampleCount = min(sampleCount, 30); //BFARC
        #endif

        for (int i = 0; i < sampleCount; i++) {
            tracePos += traceAdd;

            if (abs(tracePos.y - cloudAltitude) > cloudStretch * 2.0) break;

            vec3 cloudPlayerPos = tracePos - cameraPos;
            float lTracePos = length(cloudPlayerPos);
            float lTracePosXZ = length(cloudPlayerPos.xz);
            float cloudMult = 1.0;
            if (lTracePosXZ > distanceThreshold) break;
            if (lTracePos > lViewPosM) {
                if (skyFade < 0.7) continue;
                else cloudMult = skyMult0;
            }

            float cloudNoise = GetCloudNoise(tracePos, cloudAltitude, lTracePosXZ, cloudPlayerPos.y, noisePersistance, mult, straightness, size);

            if (cloudNoise > 0.00001) {
                #if defined CLOUD_CLOSED_AREA_CHECK && SHADOW_QUALITY > -1
                    float shadowLength = min(shadowDistance, far) * 0.9166667; //consistent08JJ622
                    if (shadowLength < lTracePos)
                    if (GetShadowOnCloud(tracePos, cameraPos, cloudAltitude, lowerPlaneAltitude, higherPlaneAltitude)) {
                        if (eyeBrightness.y != 240) continue;
                    }
                #endif

                if (firstHitPos < 1.0) {
                    firstHitPos = lTracePos;
                    #if CLOUD_QUALITY == 1 && defined DEFERRED1
                        tracePos.y += 4.0 * (texture2D(noisetex, tracePos.xz * 0.001).r - 0.5);
                    #endif
                }

                float opacityFactor = min1(cloudNoise * 32.0);

                float cloudShading = 1.0 - (higherPlaneAltitude - tracePos.y) / cloudHeight;
                cloudShading *= 1.0 + 0.75 * VdotSM3 * (1.0 - opacityFactor);

                float cosTheta = dot(normalize(sunVec), -nPlayerPos); // light-to-view angle
                float sss = PhaseHG(cosTheta, 1.0); // g=0.3 for mild forward scattering
                cloudShading += sss;

                vec3 colorSample = cloudAmbientColor * (0.7 + 0.2 * cloudShading) + cloudLightColor * cloudShading;
                //vec3 colorSample = 2.5 * cloudLightColor * pow2(cloudShading); // <-- Used this to take the Unbound logo
                vec3 cloudSkyColor = GetSky(VdotU, VdotS, dither, true, false);
                #ifdef ATM_COLOR_MULTS
                    cloudSkyColor *= sqrtAtmColorMult; // C72380KD - Reduced atmColorMult impact on some things
                #endif
                float distanceRatio = (distanceThreshold - lTracePosXZ) / distanceThreshold;
                float cloudDistanceFactor = clamp(distanceRatio, 0.0, 0.8) * 1.25;
                #ifndef DISTANT_HORIZONS
                    float cloudFogFactor = cloudDistanceFactor;
                #else
                    float cloudFogFactor = clamp(distanceRatio, 0.0, 1.0);
                #endif
                float skyMult1 = 1.0 - 0.2 * (1.0 - skyFade) * max(sunVisibility2, nightFactor);
                float skyMult2 = 1.0 - 0.33333 * skyFade;
                colorSample = mix(cloudSkyColor, colorSample * skyMult1, cloudFogFactor * skyMult2 * 0.72);
                colorSample *= pow2(1.0 - maxBlindnessDarkness);

                volumetricClouds.rgb = mix(volumetricClouds.rgb, colorSample, 1.0 - min1(volumetricClouds.a));
                volumetricClouds.a += opacityFactor * pow(cloudDistanceFactor, 0.5 + 10.0 * pow(abs(VdotSM1M), 90.0)) * cloudMult;

                if (volumetricClouds.a > 0.9) {
                    volumetricClouds.a = 1.0;
                    break;
                }
            }
        }

        if (volumetricClouds.a > 0.5) cloudLinearDepth = sqrt(firstHitPos / renderDistance);
        return volumetricClouds;
    #endif
}