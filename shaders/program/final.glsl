/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

//Pipeline Constants//
#include "/lib/pipelineSettings.glsl"

//Common Variables//
#if defined MC_ANISOTROPIC_FILTERING || COLORED_LIGHTING > 0
    #define ANY_ERROR_MESSAGE
#endif

#ifdef MC_ANISOTROPIC_FILTERING
    #define OPTIFINE_AF_ERROR
#endif

#if COLORED_LIGHTING > 0 && !defined IS_IRIS
    #define OPTIFINE_ACL_ERROR
#endif

#if COLORED_LIGHTING > 0 && defined MC_OS_MAC
    #define APPLE_ACL_ERROR
#endif

#if COLORED_LIGHTING > 0
    #define COORDINATES_ACL_ERROR
    #define SHADOWDISTANCE_ACL_ERROR
#endif

//Common Functions//
//Common Functions//
// Sharpening replaced by FSR RCAS in main()

//Includes//
#ifdef ANY_ERROR_MESSAGE
    #include "/lib/textRendering/textRenderer.glsl"

    void beginTextM(int textSize, vec2 offset) {
        float scale = 860;
        beginText(ivec2(vec2(scale * viewWidth / viewHeight, scale) * texCoord) / textSize, ivec2(0 + offset.x, scale / textSize - offset.y));
        text.bgCol = vec4(0.0);
    }
#endif

//Program//
    // Includes
    #include "/lib/antialiasing/upscale.glsl"

    // Program
    void main() {
        #if defined TAA && RENDER_SCALE < 1.0
            vec2 texCoordM = texCoord;
        #else
            vec2 texCoordM = texCoord;
        #endif

        #ifdef UNDERWATER_DISTORTION
            if (isEyeInWater == 1)
                texCoordM += WATER_REFRACTION_INTENSITY * 0.00035 * sin((texCoord.x + texCoord.y) * 25.0 + frameTimeCounter * 3.0);
        #endif

        vec3 color;
        
        #if TAA_MODE != 0 && RENDER_SCALE < 1.0
            if (texCoordM.x > 1.0 || texCoordM.y > 1.0) {
                color = vec3(0.0);
            } else {
                vec2 sourcePixelSize = 1.0 / (vec2(viewWidth, viewHeight) * RENDER_SCALE);
                float sharpness = IMAGE_SHARPENING;
                sharpness = clamp(sharpness, 0.0, 1.2);

                if (sharpness > 0.001) {
                    color = FsrRcas(colortex3, texCoordM, sourcePixelSize, sharpness);
                } else {
                    #if RENDER_SCALE < 1.0
                        vec2 sourceRes = vec2(viewWidth, viewHeight) * RENDER_SCALE;
                        color = textureEASU(colortex3, texCoordM, sourceRes);
                    #endif
                }
            }
        #else
            color = texture2D(colortex3, texCoordM).rgb;
        #endif


        #if CHROMA_ABERRATION > 0
            vec2 scaledCenter = vec2(RENDER_SCALE * 0.5);
            vec2 scale = vec2(1.0, viewHeight / viewWidth);
            vec2 aberration = (texCoordM - scaledCenter) * (2.0 / vec2(viewWidth, viewHeight)) * scale * CHROMA_ABERRATION * RENDER_SCALE;
            color.rb = vec2(texture2D(colortex3, texCoordM + aberration).r, texture2D(colortex3, texCoordM - aberration).b);
        #endif

    #ifdef OPTIFINE_AF_ERROR
        #include "/lib/textRendering/error_optifine_af.glsl"
    #elif defined OPTIFINE_ACL_ERROR
        #include "/lib/textRendering/error_optifine_acl.glsl"
    #elif defined APPLE_ACL_ERROR
        #include "/lib/textRendering/error_apple_acl.glsl"
    #else
        #ifdef COORDINATES_ACL_ERROR
            ivec2 absCameraPositionIntXZ = abs(cameraPositionInt.xz);
            if (max(absCameraPositionIntXZ.x, absCameraPositionIntXZ.y) > 8388550) {
                #include "/lib/textRendering/error_coordinates_acl.glsl"
            }
        #endif
        #ifdef SHADOWDISTANCE_ACL_ERROR
            if (COLORED_LIGHTING_INTERNAL > shadowDistance*2) {
                #include "/lib/textRendering/error_shadowdistance_acl.glsl"
            }
        #endif
    #endif

    #ifdef VIGNETTE_R
        vec2 texCoordMin = texCoordM.xy - 0.5;
        float vignette = 1.0 - dot(texCoordMin, texCoordMin) * (1.0 - GetLuminance(color));
        color *= vignette;
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
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
