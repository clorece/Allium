#ifndef INCLUDE_SKY
    #define INCLUDE_SKY

    #include "/lib/colors/lightAndAmbientColors.glsl"
    #include "/lib/colors/skyColors.glsl"

    #ifdef CAVE_FOG
        #include "/lib/atmospherics/fog/caveFactor.glsl"
    #endif

    vec3 GetLowQualitySky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
        // Prepare variables
        float VdotUmax0 = max(VdotU, 0.0);
        float VdotUmax0M = 1.0 - pow2(VdotUmax0);

        // Prepare colors
        vec3 upColor = mix(nightUpSkyColor, dayUpSkyColor, sunFactor);
        vec3 middleColor = mix(nightMiddleSkyColor, dayMiddleSkyColor, sunFactor);

        // Mix the colors
            // Set sky gradient
            float VdotUM1 = pow2(1.0 - VdotUmax0);
                //VdotUM1 = mix(VdotUM1, 1.0, rainFactor2 * 0.2);
            vec3 finalSky = mix(upColor, middleColor, VdotUM1);

            // Add sunset color
            float VdotUM2 = pow2(1.0 - abs(VdotU));
                  VdotUM2 *= invNoonFactor * sunFactor * (0.8 + 0.2 * VdotS);
            finalSky = mix(finalSky, sunsetDownSkyColorP * (shadowTime * 0.6 + 0.2), VdotUM2 * invRainFactor);
        //

        // Sky Ground
        finalSky *= pow2(pow2(1.0 + min(VdotU, 0.0)));

        // Apply Underwater Fog
        if (isEyeInWater == 1)
            finalSky = mix(finalSky, waterFogColor, VdotUmax0M);

        // Sun/Moon Glare
        finalSky *= 1.0 + mix(nightFactor, 0.5 + 0.7 * noonFactor, VdotS * 0.5 + 0.5) * pow2(pow2(pow2(VdotS)));

        #ifdef CAVE_FOG
            // Apply Cave Fog
            finalSky = mix(finalSky, caveFogColor, GetCaveFactor() * VdotUmax0M);
        #endif

        return finalSky;
    }
    

    // helpers
#define saturate(x) clamp((x), 0.0, 1.0)
#define PI 3.14159265359

// Simple Rayleigh phase
float rayleighPhase(float mu) { return 3.0/(16.0*PI) * (1.0 + mu*mu); }
float hgPhase(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159265359 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}

// Spectral coefficients (normalized 1/λ^4 for R,G,B)
vec3 rayleighRGB()
{
    // wavelengths (nm)
    const vec3 nm = vec3(680.0, 550.0, 440.0);
    vec3 inv = 1.0 / (nm*nm*nm*nm);
    return inv / dot(inv, vec3(1.0)); // normalize
}

// Approx ozone cross-section (Chappuis band 450–800nm; strongest in G/Y)
// Coeffs are relative; we just need the shape.
vec3 ozoneXS()
{
    // more absorption in G, medium in R, low in B
    return vec3(0.35, 1.0, 0.15);
}

vec3 GetSky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround)
{
    float nightFactorSqrt2 = sqrt2(nightFactor);
    float nightFactorM = sqrt2(nightFactorSqrt2) * 0.4;
    float VdotSM1 = pow2(max(VdotS, 0.0));
    float VdotSM2 = pow2(VdotSM1);
    float VdotSM3 = pow2(pow2(max(-VdotS, 0.0)));
    float VdotSML = sunVisibility > 0.5 ? VdotS : -VdotS;

    float VdotUmax0  = max(VdotU, 0.0);
    float VdotUmax0M = 1.0 - VdotUmax0*VdotUmax0;

    // base colors
    vec3 upColor     = mix(nightUpSkyColor * (1.5 - 0.5*nightFactorSqrt2 + nightFactorM*VdotSM3*1.5),
                           dayUpSkyColor, sunFactor);
    vec3 middleColor = mix(nightMiddleSkyColor * (3.0 - 2.0*nightFactorSqrt2),
                           dayMiddleSkyColor * 0.8 * (1.0 + VdotSM2*0.3), sunFactor);
    vec3 downColor   = mix(nightDownSkyColor, dayDownSkyColor * 0.75, (sunFactor + sunVisibility)*0.5);

    float VdotUM1 = pow2(1.0 - VdotUmax0);
          VdotUM1 = pow(VdotUM1, 1.0 - VdotSM2*0.4);
          VdotUM1 = mix(VdotUM1, 1.0, rainFactor2*0.15);
    vec3 finalSky = mix(upColor, middleColor, VdotUM1);

    // sunset band
    float VdotUM2 = pow2(1.0 - abs(VdotU + 0.08));
          VdotUM2 = VdotUM2*VdotUM2*(3.0 - 2.0*VdotUM2);
          VdotUM2 *= (0.7 - nightFactorM + VdotSM1*(0.3 + nightFactorM)) * invNoonFactor * sunFactor;
    finalSky = mix(finalSky, lightColor*(1.0 + VdotSM1*0.3), VdotUM2*invRainFactor);

    // ground scatter blend
    float VdotUM3 = min(max0(-VdotU + 0.125)/0.35, 1.0);
          VdotUM3 = smoothstep1(VdotUM3);
    vec3 scatteredGroundMixer = vec3(VdotUM3 * VdotUM3, sqrt1(VdotUM3), sqrt3(VdotUM3));
         scatteredGroundMixer = mix(vec3(VdotUM3), scatteredGroundMixer, 0.75 - 0.5*rainFactor);
    finalSky = mix(finalSky, pow(downColor * 1.5, vec3(1.5)) + nightFactor * 0.1, scatteredGroundMixer) * 1.5;
    finalSky = mix(finalSky, rainAmbientColor * 0.5 - nightFactor * 0.1, rainFactor);
    //finalSky += invNoonFactor2 * 0.1;

    if (doGround) finalSky *= smoothstep1(pow2(1.0 + min(VdotU, 0.0)));

    if (isEyeInWater == 1) finalSky = mix(finalSky*3.0, waterFogColor, VdotUmax0M);

    
    if (doGlare) {
        float glareScatter = 4.0*(2.0 - clamp01(VdotS*1000.0));
        float VdotSM4 = pow(abs(VdotS), glareScatter);
        float visfactor = 0.075;
        float glare = visfactor/(1.0 - (1.0 - visfactor)*VdotSM4) - visfactor;
        glare *= 0.5 + pow2(noonFactor)*1.2;
        glare *= 1.0 - rainFactor*0.5;
        float glareWaterFactor = isEyeInWater * sunVisibility;
        vec3 glareColor = mix(vec3(0.38,0.4,0.5)*0.7, vec3(0.5), sunVisibility);
             glareColor += glareWaterFactor*vec3(7.0);
        finalSky += glare*shadowTime*lightColor;
    }

    #ifdef CAVE_FOG
        finalSky = mix(finalSky, caveFogColor, GetCaveFactor()*VdotUmax0M);
    #endif
    finalSky += max((dither - 0.5), 0.0)/32.0;
    return pow(finalSky * 1.5, vec3(1.0 / 1.5));
}
#endif //INCLUDE_SKY