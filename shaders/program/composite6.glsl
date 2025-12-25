/////////////////////////////////////
// TAA Neighborhood Bounds Pre-pass //
// Computes 3x3 min/max for TAAU    //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

//Pipeline Constants//

//Common Variables//
vec2 view = vec2(viewWidth, viewHeight);

//Common Functions//

//Program//
void main() {
    
    ivec2 texel = ivec2(gl_FragCoord.xy);
    ivec2 maxTexel = ivec2(view * RENDER_SCALE) - 1;
    
    vec3 minColor = vec3(99999.0);
    vec3 maxColor = vec3(-99999.0);
    vec3 crossMin = vec3(99999.0);
    vec3 crossMax = vec3(-99999.0);

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            ivec2 sampleCoord = clamp(texel + ivec2(x, y), ivec2(0), maxTexel);
            
            vec3 sampleColor = texelFetch(colortex3, sampleCoord, 0).rgb;
            
            minColor = min(minColor, sampleColor);
            maxColor = max(maxColor, sampleColor);
            
            if (x == 0 || y == 0) {
                crossMin = min(crossMin, sampleColor);
                crossMax = max(crossMax, sampleColor);
            }
        }
    }
    
    minColor = mix(minColor, crossMin, 0.5);
    maxColor = mix(maxColor, crossMax, 0.5);

    minColor = max(minColor, vec3(0.0));
    maxColor = max(maxColor, minColor);

    /* RENDERTARGETS:14,15 */
    gl_FragData[0] = vec4(minColor, 1.0);
    gl_FragData[1] = vec4(maxColor, 1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

//Attributes//

//Common Variables//

//Common Functions//

//Includes//

//Program//
void main() {
    gl_Position = ftransform();

    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif
