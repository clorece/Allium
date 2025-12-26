/*
    Bruneton Raymarched Atmospheric Scattering
    Refactored for Allium
*/

#ifndef INCLUDE_PHYSICAL_SKY
#define INCLUDE_PHYSICAL_SKY

const float PI = 3.14159265359;
const float PLANET_RADIUS = 6371.0;        // km
const float ATMOSPHERE_HEIGHT = 100.0;      // km
const float ATMOSPHERE_RADIUS = PLANET_RADIUS + ATMOSPHERE_HEIGHT;
const float RAYLEIGH_SCALE_HEIGHT = 8.0;    // km
const float MIE_SCALE_HEIGHT = 1.2;         // km

const vec3 RAYLEIGH_COEFF = vec3(5.802, 13.558, 33.1) * 1e-3;
const vec3 MIE_COEFF = vec3(3.996e-3);
const vec3 MIE_ABSORPTION = vec3(4.4e-3);
const vec3 OZONE_COEFF = vec3(0.650, 1.881, 0.085) * 1e-3;

const float MIE_G = 0.8;
const float SUN_INTENSITY = 50.0;
const float MOON_INTENSITY = 0.15;

vec2 raySphereIntersect(vec3 rayOrigin, vec3 rayDir, float sphereRadius) {
    float b = dot(rayOrigin, rayDir);
    float c = dot(rayOrigin, rayOrigin) - sphereRadius * sphereRadius;
    float d = b * b - c;
    
    if (d < 0.0) return vec2(-1.0);
    
    d = sqrt(d);
    return vec2(-b - d, -b + d);
}

float rayleighPhase(float cosTheta) {
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

float miePhase(float cosTheta, float g) {
    float g2 = g * g;
    float num = (1.0 - g2);
    float denom = 4.0 * PI * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
    return num / denom;
}

vec3 getAtmosphereDensity(float altitude) {
    float rayleighDensity = exp(-altitude / RAYLEIGH_SCALE_HEIGHT);
    float mieDensity = exp(-altitude / MIE_SCALE_HEIGHT);
    
    float ozoneAltitude = altitude - 25.0;
    float ozoneDensity = max(0.0, 1.0 - abs(ozoneAltitude) / 15.0);
    
    return vec3(rayleighDensity, mieDensity, ozoneDensity);
}

vec3 computeOpticalDepth(vec3 rayOrigin, vec3 rayDir, float rayLength) {
    const int SAMPLES = 2;
    float stepSize = rayLength / float(SAMPLES);
    vec3 opticalDepth = vec3(0.0);
    
    for (int i = 0; i < SAMPLES; i++) {
        float t = (float(i) + 0.5) * stepSize;
        vec3 pos = rayOrigin + rayDir * t;
        float h = abs(length(pos) - PLANET_RADIUS);
        opticalDepth += getAtmosphereDensity(h) * stepSize;
    }
    return opticalDepth;
}

vec3 computeTransmittance(vec3 opticalDepth) {
    return exp(-(RAYLEIGH_COEFF * opticalDepth.x + (MIE_COEFF + MIE_ABSORPTION) * opticalDepth.y + OZONE_COEFF * opticalDepth.z));
}

float getPlanetShadow(vec3 p, vec3 dir) {
    float b = dot(p, dir);
    float t = -b;
    if (t < 0.0) return 1.0;
    
    vec3 pClosest = p + t * dir;
    float distSq = dot(pClosest, pClosest);
    float dist = sqrt(distSq);
    
    return smoothstep(PLANET_RADIUS - 10.0, PLANET_RADIUS + 10.0, dist);
}

void integrateScattering(
    vec3 rayOrigin, vec3 rayDir, float rayLength, float dither,
    vec3 sunDir, vec3 moonDir,
    inout vec3 opticalDepth, inout vec3 scatteringSun, inout vec3 scatteringMoon, inout vec3 scatteringAmbient, inout vec3 transmittance,
    int numSamples
) {
    float stepSize = rayLength / float(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
        float t = (float(i)) * stepSize;
        vec3 p = rayOrigin + rayDir * t;
        float h = abs(length(p) - PLANET_RADIUS);
        
        vec3 density = getAtmosphereDensity(h);
        vec3 stepAirmass = density * stepSize;
        vec3 stepOpticalDepth = density * stepSize;

        vec3 stepExtinction = RAYLEIGH_COEFF * density.x + (MIE_COEFF + MIE_ABSORPTION) * density.y + OZONE_COEFF * density.z;
        vec3 stepTrans = exp(-stepExtinction * stepSize);

        opticalDepth += stepAirmass;

        vec3 currentTransmittance = transmittance * exp(-stepExtinction * stepSize * 0.5); 

        transmittance *= stepTrans;

        float sunVis = getPlanetShadow(p, sunDir);
        vec2 sunHit = raySphereIntersect(p, sunDir, ATMOSPHERE_RADIUS);
        if (sunHit.y > 0.0 && sunVis > 1e-4) {
            vec3 sunOD = computeOpticalDepth(p, sunDir, sunHit.y);
            vec3 sunTrans = computeTransmittance(sunOD);
            vec3 scatterTerm = (RAYLEIGH_COEFF * density.x + MIE_COEFF * density.y);
            scatteringSun += scatterTerm * sunTrans * currentTransmittance * stepSize * sunVis;
        }

        float moonVis = getPlanetShadow(p, moonDir);
        vec2 moonHit = raySphereIntersect(p, moonDir, ATMOSPHERE_RADIUS);
        if (moonHit.y > 0.0 && moonVis > 1e-4) {
            vec3 moonOD = computeOpticalDepth(p, moonDir, moonHit.y);
            vec3 moonTrans = computeTransmittance(moonOD);
            vec3 scatterTerm = (RAYLEIGH_COEFF * density.x + MIE_COEFF * density.y);
            scatteringMoon += scatterTerm * moonTrans * currentTransmittance * stepSize * moonVis;
        }

        scatteringAmbient += (RAYLEIGH_COEFF * density.x + MIE_COEFF * density.y) * currentTransmittance * stepSize;
        stepSize *= 2.0;
    }
}


vec3 getSunMoonColor(vec3 viewDir, vec3 sunDir, vec3 background, vec3 transmittance) {
    vec3 color = background;
    float VdotS = dot(viewDir, sunDir);
    float SdotU = sunDir.y;

    float sunSize = 0.9996;

    
    if (VdotS > sunSize) {
        float sunEdge = smoothstep(sunSize, sunSize + 0.002, VdotS);
        
        vec3 sunColor = vec3(1.0, 0.98, 0.95);

        sunColor *= 60000000.0 * SUN_INTENSITY; 
        
        #ifdef SUN_MOON_DURING_RAIN
             sunColor *= 1.0 - rainFactor * 0.8;
        #endif

        return color + sunColor * transmittance * sunEdge;
    }

    float moonSize = 0.9996;
    float VdotM = dot(viewDir, -sunDir);
    if (VdotM > moonSize) {
        float moonEdge = smoothstep(moonSize, moonSize + 0.001, VdotM);
        
        vec3 moonColor = vec3(0.54, 0.58, 0.65); // Bluish grey

        moonColor *= 50.0 * MOON_INTENSITY;
        
        return color + moonColor * transmittance * moonEdge;
    }
                

    
    return color;
}
vec3 calculateSkyColor(
    vec3 viewDir,
    vec3 sunDir,
    float altitudeMeters,
    float dither
) {
    float altitude = altitudeMeters * 0.001;
    vec3 cameraPos = vec3(0.0, PLANET_RADIUS + altitude, 0.0);

    vec3 viewDirScattering = normalize(vec3(viewDir.x, max(viewDir.y, 0.0), viewDir.z));

    vec2 atmosphereHit = raySphereIntersect(cameraPos, viewDirScattering, ATMOSPHERE_RADIUS);
    if (atmosphereHit.y < 0.0) return vec3(0.0);
    
    float tStart = max(atmosphereHit.x, 0.0);
    float tEnd = atmosphereHit.y;
    
    vec3 sunColor = vec3(1.0, 0.98, 0.95);
    vec3 moonColor = vec3(0.6, 0.7, 1.0);
    vec3 moonDir = -sunDir;
    
    vec3 opticalDepth = vec3(0.0);
    vec3 scatteringSun = vec3(0.0);
    vec3 scatteringMoon = vec3(0.0);
    vec3 scatteringAmbient = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    
    integrateScattering(cameraPos + viewDirScattering * tStart, viewDirScattering, tEnd - tStart, dither,
        sunDir, moonDir, opticalDepth, scatteringSun, scatteringMoon, scatteringAmbient, transmittance, 12);

    float cosTheta = dot(viewDirScattering, sunDir);
    float rayleighP = rayleighPhase(cosTheta);
    float mieP = miePhase(cosTheta, MIE_G);
    
    float moonCosTheta = dot(viewDirScattering, moonDir);
    float moonRayleighP = rayleighPhase(moonCosTheta);
    float moonMieP = miePhase(moonCosTheta, MIE_G);
    
    vec3 ambientColor = mix(sunColor * 0.3, moonColor * 0.1, smoothstep(0.0, -0.3, sunDir.y));

    vec3 skyColor = scatteringSun * rayleighP * sunColor * SUN_INTENSITY
                  + scatteringMoon * moonRayleighP * moonColor * MOON_INTENSITY
                  + scatteringSun * mieP * sunColor * SUN_INTENSITY
                  + scatteringMoon * moonMieP * moonColor * MOON_INTENSITY
                  + scatteringAmbient * ambientColor;

    skyColor = getSunMoonColor(viewDir, sunDir, skyColor, transmittance);

    float luma = dot(skyColor, vec3(0.2126, 0.7152, 0.0722));
    vec3 tv = skyColor / (1.0 + skyColor);
    skyColor = mix(skyColor / (1.0 + luma), tv, tv);
    
    skyColor += (dither - 0.5) / 128.0;

    return skyColor;
}

#endif // INCLUDE_PHYSICAL_SKY
