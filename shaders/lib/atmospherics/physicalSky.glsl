/*
    Bruneton Raymarched Atmospheric Scattering
    Based on Eric Bruneton's Precomputed Atmospheric Scattering
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

const float SUN_INTENSITY = 20.0;
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


vec3 computeOpticalDepth(vec3 rayOrigin, vec3 rayDir, float rayLength, int numSamples) {
    float stepSize = rayLength / float(numSamples);
    vec3 opticalDepth = vec3(0.0);
    
    for (int i = 0; i < numSamples; i++) {
        float t = (float(i) + 0.5) * stepSize;
        vec3 samplePos = rayOrigin + rayDir * t;
        float altitude = length(samplePos) - PLANET_RADIUS;
        
        if (altitude < 0.0) break;
        
        vec3 density = getAtmosphereDensity(altitude);
        opticalDepth += density * stepSize;
    }
    
    return opticalDepth;
}

vec3 computeTransmittance(vec3 opticalDepth) {
    vec3 extinction = RAYLEIGH_COEFF * opticalDepth.x 
                    + (MIE_COEFF + MIE_ABSORPTION) * opticalDepth.y
                    + OZONE_COEFF * opticalDepth.z;
    return exp(-extinction);
}


vec3 calculateSkyColor(
    vec3 viewDir,
    vec3 sunDir,
    float altitudeMeters,
    float dither
) {
    float altitude = altitudeMeters * 0.001;
    
    vec3 cameraPos = vec3(0.0, PLANET_RADIUS + altitude, 0.0);

    vec2 atmosphereHit = raySphereIntersect(cameraPos, viewDir, ATMOSPHERE_RADIUS);
    if (atmosphereHit.y < 0.0) return vec3(0.0);
    
    vec2 groundHit = raySphereIntersect(cameraPos, viewDir, PLANET_RADIUS * 0.998);
    bool planetIntersected = groundHit.y >= 0.0;
    
    float planetGround = pow(clamp(viewDir.y + 1.0, 0.0, 1.0), 2.0);
    float groundDarkening = max(planetGround * 0.7 + 0.3, clamp(sunDir.y * 2.0, 0.0, 1.0));

    vec2 sd = vec2(
        (planetIntersected && groundHit.x < 0.0) ? groundHit.y : max(atmosphereHit.x, 0.0),
        (planetIntersected && groundHit.x > 0.0) ? groundHit.x : atmosphereHit.y
    );
    
    float rayLength = sd.y - sd.x;
    if (rayLength <= 0.0) return vec3(0.0);

    const int VIEW_SAMPLES = 16;
    const int LIGHT_SAMPLES = 4;
    
    float stepSize = rayLength / float(VIEW_SAMPLES);

    float cosTheta = dot(viewDir, sunDir);
    float rayleighP = rayleighPhase(cosTheta);
    float mieP = miePhase(cosTheta, MIE_G);

    vec3 scatteringSun = vec3(0.0);
    vec3 scatteringMoon = vec3(0.0);
    vec3 scatteringAmbient = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    
    vec3 increment = viewDir * stepSize;
    vec3 position = viewDir * sd.x + cameraPos;
    position += increment * (0.34 * dither);
    
    float horizonBlend = mix(0.3, 1.0, smoothstep(-0.5, 0.1, viewDir.y));

    vec3 moonDir = -sunDir;
    float moonCosTheta = dot(viewDir, moonDir);
    float moonRayleighP = rayleighPhase(moonCosTheta);
    float moonMieP = miePhase(moonCosTheta, MIE_G);

    for (int i = 0; i < VIEW_SAMPLES; i++) {
        float sampleAltitude = length(position) - PLANET_RADIUS;
        vec3 density = getAtmosphereDensity(sampleAltitude);
        if (density.y > 1e35) break;
        
        vec3 stepAirmass = density * stepSize;
        vec3 stepOpticalDepth = (RAYLEIGH_COEFF * stepAirmass.x + MIE_COEFF * stepAirmass.y + OZONE_COEFF * stepAirmass.z);
        vec3 stepTransmittance = exp(-stepOpticalDepth);
        vec3 stepTransmittedFraction = clamp((stepTransmittance - 1.0) / -max(stepOpticalDepth, vec3(1e-6)), 0.0, 1.0);
        vec3 stepScatteringVisible = transmittance * stepTransmittedFraction * groundDarkening;

        vec2 sunHit = raySphereIntersect(position, sunDir, ATMOSPHERE_RADIUS);
        if (sunHit.y > 0.0) {
            vec2 sunGroundHit = raySphereIntersect(position, sunDir, PLANET_RADIUS);
            if (sunGroundHit.x < 0.0) {
                vec3 lightOpticalDepth = computeOpticalDepth(position, sunDir, sunHit.y, LIGHT_SAMPLES);
                vec3 lightTransmittance = computeTransmittance(lightOpticalDepth);
                
                vec3 scattering = (RAYLEIGH_COEFF * stepAirmass.x + MIE_COEFF * stepAirmass.y);
                scatteringSun += scattering * stepScatteringVisible * lightTransmittance * horizonBlend;
            }
        }

        vec2 moonHit = raySphereIntersect(position, moonDir, ATMOSPHERE_RADIUS);
        if (moonHit.y > 0.0) {
            vec2 moonGroundHit = raySphereIntersect(position, moonDir, PLANET_RADIUS);
            if (moonGroundHit.x < 0.0) {
                vec3 lightOpticalDepth = computeOpticalDepth(position, moonDir, moonHit.y, LIGHT_SAMPLES);
                vec3 lightTransmittance = computeTransmittance(lightOpticalDepth);
                
                vec3 scattering = (RAYLEIGH_COEFF * stepAirmass.x + MIE_COEFF * stepAirmass.y);
                scatteringMoon += scattering * stepScatteringVisible * lightTransmittance * horizonBlend;
            }
        }
        
        scatteringAmbient += (RAYLEIGH_COEFF * stepAirmass.x + MIE_COEFF * stepAirmass.y) * stepScatteringVisible;
        
        transmittance *= stepTransmittance;
        position += increment;
    }
    vec3 sunColor = vec3(1.0, 0.98, 0.95);
    vec3 moonColor = vec3(0.6, 0.7, 1.0);
    vec3 ambientColor = mix(sunColor * 0.3, moonColor * 0.1, smoothstep(0.0, -0.3, sunDir.y));
    
    vec3 skyColor = scatteringSun * rayleighP * sunColor * SUN_INTENSITY
                  + scatteringMoon * moonRayleighP * moonColor * MOON_INTENSITY
                  + scatteringAmbient * ambientColor;

    float horizonFactor = pow(1.0 - abs(viewDir.y), 8.0);
    float sunsetFactor = smoothstep(-0.1, 0.1, sunDir.y) * smoothstep(0.4, 0.0, sunDir.y);
    if (sunsetFactor > 0.0) {
        vec3 sunsetColor = vec3(1.0, 0.3, 0.1);
        skyColor += sunsetColor * sunsetFactor * horizonFactor * transmittance * 0.5;
    }

    skyColor = skyColor / (1.0 + skyColor);

    skyColor += (dither - 0.5) / 128.0;
    
    return skyColor;
}

#endif // INCLUDE_PHYSICAL_SKY
