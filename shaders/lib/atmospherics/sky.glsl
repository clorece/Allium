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
    

    // I CANT DO THIS ANYMORE
    // https://www.shadertoy.com/view/XsKfWz
    const float R0   = 6360e3;
    const float Ra   = 6380e3;
    const float HR   = 8e3;
    const float HM   = 1.2e3;
    const float Ha   = Ra - R0;
    const vec3  bR   = vec3(58e-7, 135e-7, 331e-7);
    const vec3  bMs  = vec3(2e-5);
    const vec3  bMe  = bMs * 1.0;
    const float SunI = 200.0;
    const float seaLevel = 70.0;

    const float R_PHASE = 0.0597;
    const float M_PHASE = 0.0196; 
    float hgDen(float mu) { return pow(1.58 - 1.52 * mu, 1.5); }

    float safe_rcp(float x)  { return 1.0 / max(x, 1e-4); }
    float saturate(float x)  { return clamp(x, 0.0, 1.0); }

    // this pmo
    float tauFlat(float H, float h, float L, float mu) {
        float em = exp(-h / H);
        float amu = abs(mu);
        if (amu < 1e-4) {
            return L * em;
        }
        float k = mu / H;
        return (em / k) * (1.0 - exp(-k * L));
    }

    // please help
    float tauToTOA(float H, float h, float muSunZ)
    {
        const float eps = 0.015;

        float hh = clamp(h, 0.0, Ha - 1.0);
        float mu = clamp(muSunZ, -1.0, 1.0);
        float muEff = sqrt(mu*mu + eps*eps);
        float Ls = (Ha - hh) / muEff;
        float tau = tauFlat(H, hh, Ls, muEff);
        float below = smoothstep(-0.20, 0.0, -mu);

        tau += 80.0 * below;                    

        return tau;
    }

    // im going insane
    vec3 GetSky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround)
{
    vec3 Up  = normalize(upVec);
    vec3 Sun = normalize(sunVec);

    float muV  = clamp(VdotU, -1.0, 1.0);
    float muS  = clamp(VdotS, -1.0, 1.0);
    float cameraHeight = cameraPosition.y;

    float muV_soft = max(0.05, muV + 0.15);
    float L        = Ha * safe_rcp(muV_soft);

    const int STEPS = 2;
    float horizonW = saturate(1.0 - muV);
    float tExp = mix(1.0, 2.0, horizonW);

    vec3 I_R = vec3(0.0);
    vec3 I_M = vec3(0.0);

    float muPhase = muS;
    vec3 phaseR   = vec3(R_PHASE * (1.0 + muPhase * muPhase));
    float mieDen  = hgDen(muPhase);
    vec3 phaseM   = vec3(M_PHASE / mieDen);

    for (int i = 0; i < STEPS; ++i) {
        float t0   = pow(float(i)   / float(STEPS), tExp);
        float t1   = pow(float(i+1) / float(STEPS), tExp);
        float sMid = L * 0.5 * (t0 + t1);
        float ds   = L * (t1 - t0);

        float h  = max(0.0, sMid * muV + cameraHeight - seaLevel);

        float rhoR = exp(-h / HR);
        float rhoM = exp(-h / HM);

        float tauVR = tauFlat(HR, seaLevel, sMid, muV);
        float tauVM = tauFlat(HM, seaLevel, sMid, muV);
        vec3  Tview = exp(-bR * tauVR - bMe * tauVM);

        float tauSR = tauToTOA(HR, h, dot(Sun, Up));
        float tauSM = tauToTOA(HM, h, dot(Sun, Up));
        vec3  Tsun  = exp(-bR * tauSR - bMe * tauSM);

        vec3 A = Tview * Tsun;
        I_R += A * rhoR * ds;
        I_M += A * rhoM * ds;
    }

    float tauR_full = tauFlat(HR, seaLevel, L, muV);
    float tauM_full = tauFlat(HM, seaLevel, L, muV);
    vec3  transV    = exp(-bR * tauR_full - bMe * tauM_full);
    vec3  col       = vec3(0.0) * transV;

    vec3 rayleigh = I_R * bR * phaseR * 1.0;
    vec3 mie      = I_M * bMs * phaseM * lightColor * 2.5;
    col += SunI * (rayleigh + mie) + lightColor;

    if (doGround) {
        col *= pow2(pow2(1.0 + min(VdotU, 0.0)));
    }

    if (doGlare) {
        float glare = pow(max(0.0, muS), 64.0);
        col += lightColor * glare * 2.0;
    }

    // --- NIGHT / BELOW-HORIZON OVERRIDE ------------------------------
    // Make the sky below the horizon equal to lightColor (smooth transition).
    
    const float HSOFT = 0.1;                // ~1.7° softness around horizon
    float below = smoothstep(0.0, HSOFT, -muV); // 0 above, 1 deeper below
    col = mix(col, ambientColor * 0.5 + lightColor * 5.0, below);       // ← added
    
    // ------------------------------------------------------------------

    // remove the nightFactor hack divide
     col /= (1.0 + nightFactor * 32.0);    // ← removed

    col += (dither - 0.5) / 32.0;
    col  = sqrt(max(col, 0.0));
    return max(col, 0.0);
}
#endif //INCLUDE_SKY