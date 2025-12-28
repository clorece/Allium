/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

flat in vec3 upVec, sunVec;

//Pipeline Constants//

//Common Variables//
#include "/lib/commonVariables.glsl"
#include "/lib/commonFunctions.glsl"

//Common Functions//
float GetLinearDepth2(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/util/spaceConversion.glsl"

bool IsActivePixel(vec2 fragCoord) {
    #if PT_RENDER_RESOLUTION == 3
        return true;
    #elif PT_RENDER_RESOLUTION == 2
        ivec2 p = ivec2(fragCoord);
        return !((p.x & 1) != 0 && (p.y & 1) != 0);
    #elif PT_RENDER_RESOLUTION == 1
        ivec2 p = ivec2(fragCoord);
        return ((p.x + p.y) & 1) == 0;
    #elif PT_RENDER_RESOLUTION == 0
        ivec2 p = ivec2(fragCoord);
        return ((p.x & 1) == 0 && (p.y & 1) == 0);
    #endif
    return true;
}

//Program//
void main() {
    
    float z0 = texelFetch(depthtex0, texelCoord, 0).r;
    
    vec3 emissiveFiltered = vec3(0.0);
    vec3 giFiltered = vec3(0.0);
    vec3 aoFiltered = vec3(0.0);
    
    #if GLOBAL_ILLUMINATION == 2
        vec4 rawEmissiveData = texture2D(colortex9, texCoord);
        vec3 rawEmissive = rawEmissiveData.rgb;
        vec3 rawAO = vec3(rawEmissiveData.a);
        
        vec4 rawGIData = texture2D(colortex11, texCoord);
        vec3 rawGI = rawGIData.rgb;
        
        float centerDepth = GetLinearDepth(z0);
        vec3 texture5 = texelFetch(colortex5, texelCoord, 0).rgb;
        vec3 centerNormal = mat3(gbufferModelView) * texture5;
        
        #ifdef DENOISER_ENABLED
        int stepSize = 1 * DENOISER_STEP_SIZE;
        float totalWeight = 0.0;
        float totalWeightEmissive = 0.0;
        
        const float kernel[3] = float[3](1.0, 2.0, 1.0);
        
        // First pass: compute local mean for firefly detection
        // Don't skip inactive pixels - texture filtering will pick up nearest valid data
        vec3 localEmissiveMean = vec3(0.0);
        float localMeanWeight = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 offset = vec2(x, y) * float(stepSize) / vec2(viewWidth, viewHeight);
                vec2 sampleCoord = texCoord + offset;
                vec3 sampleEmissive = texture2D(colortex9, sampleCoord).rgb;
                float w = kernel[abs(x)] * kernel[abs(y)];
                localEmissiveMean += sampleEmissive * w;
                localMeanWeight += w;
            }
        }
        localEmissiveMean /= max(localMeanWeight, 0.001);
        
        // Clamp the raw emissive to reject fireflies (soft clamp to local mean)
        float rawLum = dot(rawEmissive, vec3(0.2126, 0.7152, 0.0722));
        float meanLum = dot(localEmissiveMean, vec3(0.2126, 0.7152, 0.0722));
        float maxAllowedLum = meanLum * 3.0 + 0.1; // Allow 3x the local mean before clamping
        if (rawLum > maxAllowedLum && meanLum > 0.001) {
            rawEmissive = rawEmissive * (maxAllowedLum / rawLum);
        }
        
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {

                ivec2 samplePixel = ivec2(gl_FragCoord.xy) + ivec2(x, y) * stepSize;
                bool isActive = IsActivePixel(vec2(samplePixel));

                vec2 offset = vec2(x, y) * float(stepSize) / vec2(viewWidth, viewHeight);
                vec2 sampleCoord = texCoord + offset;

                float spatialWeight = kernel[abs(x)] * kernel[abs(y)];

                float sampleDepth = GetLinearDepth(texture2D(depthtex0, sampleCoord).r);
                float depthDiff = abs(centerDepth - sampleDepth) * far;
                float depthWeight = exp(-depthDiff * depthDiff * 1.0);

                vec3 sampleTexture5 = texture2D(colortex5, sampleCoord).rgb;
                vec3 sampleNormal = mat3(gbufferModelView) * sampleTexture5;
                float normalDot = max(dot(centerNormal, sampleNormal), 0.0);
                float normalWeightGI = pow(normalDot, 8.0);
                float normalWeightEmissive = pow(normalDot, 2.0); // Softer edge-stopping for noisy emissives
                
                // Sample emissive - from ALL pixels (texture filtering handles inactive)
                vec4 sampleEmissiveData = texture2D(colortex9, sampleCoord);
                vec3 sampleEmissive = sampleEmissiveData.rgb;
                vec3 sampleAO = vec3(sampleEmissiveData.a);
                
                // Clamp neighbor samples for firefly rejection
                float sampleLum = dot(sampleEmissive, vec3(0.2126, 0.7152, 0.0722));
                if (sampleLum > maxAllowedLum && meanLum > 0.001) {
                    sampleEmissive = sampleEmissive * (maxAllowedLum / sampleLum);
                }
                
                float weightEmissive = spatialWeight * depthWeight * normalWeightEmissive;
                emissiveFiltered += sampleEmissive * weightEmissive;
                totalWeightEmissive += weightEmissive;
                
                // GI/AO - only from active pixels
                if (isActive) {
                    vec3 sampleGI = texture2D(colortex11, sampleCoord).rgb;
                    float weightGI = spatialWeight * depthWeight * normalWeightGI;
                    giFiltered += sampleGI * weightGI;
                    aoFiltered += sampleAO * weightGI;
                    totalWeight += weightGI;
                }
            }
        }
        
        if (totalWeight > 0.0001) {
            giFiltered /= totalWeight;
            aoFiltered /= totalWeight;
        } else {
            giFiltered = rawGI;
            aoFiltered = rawAO;
        }
        if (totalWeightEmissive > 0.0001) {
            emissiveFiltered /= totalWeightEmissive;
        } else {
            emissiveFiltered = rawEmissive;
        }
        #else
            emissiveFiltered = rawEmissive;
            giFiltered = rawGI;
            aoFiltered = rawAO;
        #endif
    #endif

    emissiveFiltered = max(emissiveFiltered, 0.0);
    giFiltered = max(giFiltered, 0.0);
    aoFiltered = max(aoFiltered, 0.0);
    
    /* RENDERTARGETS: 8,11 */
    gl_FragData[0] = vec4(emissiveFiltered, aoFiltered.r);
    gl_FragData[1] = vec4(giFiltered, 1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;
flat out vec3 upVec, sunVec;

//Program//
void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = normalize(sunPosition);
}

#endif