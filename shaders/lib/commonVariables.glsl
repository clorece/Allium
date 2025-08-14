//Common Variables//
float SdotU = dot(sunVec, upVec);
float sunFactor = SdotU < 0.0 ? clamp(SdotU + 0.375, 0.0, 0.75) / 0.75 : clamp(SdotU + 0.03125, 0.0, 0.0625) / 0.0625;
float sunVisibility = clamp(SdotU + 0.0625, 0.0, 0.125) / 0.125;
float sunVisibility2 = sunVisibility * sunVisibility;
float shadowTimeVar1 = abs(sunVisibility - 0.5) * 2.0;
float shadowTimeVar2 = shadowTimeVar1 * shadowTimeVar1;
float shadowTime = shadowTimeVar2 * shadowTimeVar2;
float farMinusNear = far - near;

#ifdef LIGHTSHAFTS_ACTIVE
    float vlTime = min(abs(SdotU) - 0.05, 0.15) / 0.15;
#endif

vec2 view = vec2(viewWidth, viewHeight);

#ifdef OVERWORLD
    vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
#else
    vec3 lightVec = sunVec;
#endif
