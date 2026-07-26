#include "/lib/options.glsl"

#ifdef VERTEX

#include "/lib/util/jitter.glsl"

out vec2 texCoord;
out vec2 lightmapCoord;
out vec3 normal;
out vec4 color;
flat out float isWater;
flat out float matFlag;

attribute vec4 mc_Entity;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;

    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;

    float eid = mc_Entity.x;
    isWater = (eid == 10006.0) ? 1.0 : 0.0;
    matFlag = (eid == 10006.0) ? 1.0 :   // water
              (eid == 10004.0) ? 0.75 :  // glass / stained glass / panes
              (eid == 10007.0) ? 0.5  :  // clear ice (ice, frosted_ice)
              (eid == 10008.0) ? 0.25 :  // solid ice (packed_ice, blue_ice)
              0.75;                       // fallback: unknown translucent -> glass

    #ifdef TAA
        gl_Position.xy += getTaaJitter() * 2.0 * gl_Position.w / vec2(viewWidth, viewHeight);
    #endif

    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
}

#endif

#ifdef FRAGMENT

#include "/lib/util/common.glsl"

in vec2 texCoord;
in vec2 lightmapCoord;
in vec3 normal;
in vec4 color;
flat in float isWater;
flat in float matFlag;

void main() {
    vec4 albedo = texture(texture, texCoord) * color;

    // Blend is off for gbuffers_hand_water, discard cutout/transparent texels.
    if (isWater < 0.5 && albedo.a < 0.1) discard;

    // For water hand items, c_water will process it if matFlag == 1.0.
    // We just write normal to colortex1, and lightmap+flag+colour to colortex2.
    /* DRAWBUFFERS:12 */
    gl_FragData[0] = vec4(normal * 0.5 + 0.5, 0.5);                          // colortex1: normal
    gl_FragData[1] = vec4(lightmapCoord, matFlag, packColor565(albedo.rgb)); // colortex2: lightmap, flag, packed colour
}

#endif
