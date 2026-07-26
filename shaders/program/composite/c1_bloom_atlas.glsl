#include "/lib/options.glsl"

#ifdef VERTEX

out vec2 texCoord;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FRAGMENT

in vec2 texCoord;

#include "/lib/util/common.glsl"
#include "/lib/post/bloom.glsl"

void main() {
    vec3 sceneColor = texture(colortex0, texCoord).rgb;

    float exposure = texelFetch(colortex0, ivec2(0), 0).a;
    if (exposure <= 0.001 || isnan(exposure) || isinf(exposure)) {
        exposure = 1.3;
    }

    vec3 bloomAtlas = vec3(0.0);
    #ifdef BLOOM
        vec2 scaledCoord = texCoord * bloomAtlasRescale();
        bloomAtlas = BuildBloomAtlas(scaledCoord);
    #endif

    /* DRAWBUFFERS:35 */
    gl_FragData[0] = vec4(bloomAtlas, 1.0);   // colortex3 = packed atlas
    gl_FragData[1] = vec4(sceneColor, exposure); // colortex5 = TAA history + exposure
}

#endif
