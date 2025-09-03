#ifndef INCLUDE_WATER_FOG
    #define INCLUDE_WATER_FOG
    
    #define WATER_LEVEL 63.0
    #define WATER_FOG_DISTANCE 1.0

    float wtrFogSRATA = WATER_LEVEL + 0.1;
    float wtrFogCRFTM = 30.0;

    /*
        Pretty much just complementary's atmospheric and border fogs but for water
    */

    float GetWaterLevel(float altitude) {
        return pow2(1.0 - clamp(altitude - wtrFogSRATA, 0.0, wtrFogCRFTM) / wtrFogCRFTM);;
    }

    float GetWaterFog(float lViewPos, vec3 playerPos) {
        float fog = pow2(1.0 - exp(-max0(lViewPos - 40.0) * (0.7 + 0.7 * rainFactor) / WATER_FOG_DISTANCE));

        float altitudeFactorRaw = GetWaterLevel(playerPos.y + cameraPosition.y);

        float altitudeFactor = altitudeFactorRaw * 0.9 + 0.1;
            altitudeFactor *= 1.0 - 0.1 * GetWaterLevel(cameraPosition.y) * invRainFactor;

        fog *= altitudeFactor;

        if (fog > 0.0) {
            fog = clamp(fog, 0.0, 1.0);
        }

        return fog;
    }
#endif