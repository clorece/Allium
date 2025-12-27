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
        
        const float kernel[3] = float[3](1.0, 2.0, 1.0);
        
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {

                ivec2 samplePixel = ivec2(gl_FragCoord.xy) + ivec2(x, y) * stepSize;
                
                // --- NEW CHECK: Skip neighbor if it was one of the skipped pixels ---
                if (!IsActivePixel(vec2(samplePixel))) continue;

                vec2 offset = vec2(x, y) * float(stepSize) / vec2(viewWidth, viewHeight);
                vec2 sampleCoord = texCoord + offset;

                float spatialWeight = kernel[abs(x)] * kernel[abs(y)];

                float sampleDepth = GetLinearDepth(texture2D(depthtex0, sampleCoord).r);
                float depthDiff = abs(centerDepth - sampleDepth) * far;
                float depthWeight = exp(-depthDiff * depthDiff * 1.0);

                vec3 sampleTexture5 = texture2D(colortex5, sampleCoord).rgb;
                vec3 sampleNormal = mat3(gbufferModelView) * sampleTexture5;
                float normalDot = max(dot(centerNormal, sampleNormal), 0.0);
                float normalWeight = pow(normalDot, 8.0);
                // Sample emissive
                vec4 sampleEmissiveData = texture2D(colortex9, sampleCoord);
                vec3 sampleEmissive = sampleEmissiveData.rgb;
                vec3 sampleAO = vec3(sampleEmissiveData.a);
                // Sample GI
                vec3 sampleGI = texture2D(colortex11, sampleCoord).rgb;
                
                float weight = spatialWeight * depthWeight * normalWeight;
                
                emissiveFiltered += sampleEmissive * weight;
                giFiltered += sampleGI * weight;
                aoFiltered += sampleAO * weight;
                totalWeight += weight;
            }
        }
        
        if (totalWeight > 0.0001) {
            emissiveFiltered /= totalWeight;
            giFiltered /= totalWeight;
            aoFiltered /= totalWeight;
        } else {
            emissiveFiltered = rawEmissive;
            giFiltered = rawGI;
            aoFiltered = rawAO;
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