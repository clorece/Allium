vec3 getShadow(float nDotL) {
    int samples = SHADOW_FILTER_QUALITY;

    float shading = 0.0;
    float shading1 = 0.0;
    float scatterAmount = SCATTER_AMOUNT;
    vec3 finalShading = vec3(0.0);
    vec4 shading2 = vec4(0.0);

    vec4 worldPosition = toShadowSpace(nDotL);

    #ifdef SHADOW_FILTER
        for(int i = 0; i < samples; i++){
            //for(int y = 0; y < samples; y++){
                #ifdef DITHER_FILTER
                    vec2 offset = vec2(cos(i), cos(i)) * (rotation / shadowMapResolution);
                #else
                    vec2 offset = vec2(i, i) / shadowMapResolution;
                #endif
                
                #ifdef FAKE_SSS
                    if (nDotL == 1.0) {
                        offset *= 2.0 * scatterAmount;
                    }
                #endif
                
                shading = step(worldPosition.z - 0.0001, texture2D(shadowtex0, worldPosition.xy + offset).x);
                shading1 = step(worldPosition.z - 0.0001, texture2D(shadowtex1, worldPosition.xy + offset).x);
                shading2 = texture2D(shadowcolor0, worldPosition.xy + offset);

                finalShading += mix(shading2.rgb * shading1, vec3(1.0), shading);
            //}
        }
        finalShading /= samples;
    #else
        shading = step(worldPosition.z - 0.0001, texture2D(shadowtex0, worldPosition.xy).x);
        shading1 = step(worldPosition.z - 0.0001, texture2D(shadowtex1, worldPosition.xy).x);
        shading2 = texture2D(shadowcolor0, worldPosition.xy);
        finalShading = mix(shading2.rgb * shading1, vec3(1.0), shading);
    #endif

    return finalShading;
}