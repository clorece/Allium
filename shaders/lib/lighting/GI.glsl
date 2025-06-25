#define GI_SAMPLES      4 //[2 3 4 5 6 7 8 9 10 12 14 16 18 20 22 24]
#define GI_STEPS        12 //[2 3 4 5 6 7 8 9 10 12 14 16 18 20 22 24]
#define GI_RADIUS       1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0]
#define GI_INTENSITY    0.75 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0]
#define GI_INV_SAMPLES  (1.0 / float(GI_SAMPLES))
#define GI_FADE_SCALE (1.0 / (GI_RADIUS * 0.1))
#define GI_INV_STEPS  (1.0 / float(GI_STEPS))

vec2 texelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);

float rand(float dither, int i) {
    return fract(dither + float(i)*0.61803398875);
}

vec3 CosineSampleHemisphere(float x, vec3 n) {
    float r     = sqrt(x);
    float theta = 6.2831853 * x;
    vec3 tangent   = normalize(cross(n, vec3(0,1,0)));
    vec3 bitangent = cross(n, tangent);
    return normalize(
        r*cos(theta)*tangent +
        r*sin(theta)*bitangent +
        sqrt(1.0 - x)*n
    );
}

vec3 GetSkyIllumination(vec3 normalM, vec3 viewPos, vec3 nViewPos, float dither, float skyLightFactor, vec3 shadowMult, float VdotU, float VdotS) {
    float sampleCount = 2;

    vec3 nrm     = normalM;
    #if defined(GBUFFERS_WATER) && WATER_STYLE==1 && defined(GENERATED_NORMALS)
        nrm = normalize(mix(geoNormal, normalM, 0.05));
    #endif

    float inv   = 1.0 / float(2);

    vec3 giAccum = vec3(0.0);

    for (int i = 0; i < sampleCount; ++i) {
        vec3 dir   = CosineSampleHemisphere(rand(dither, i), normalM);

        // sky fallback
        float U = dot(dir, upVec), S = dot(dir, sunVec);
        //#ifdef DEFERRED1
        #ifdef OVERWORLD
            giAccum += GetSky(U, S, dither,true,true) * 2.5 * skyLightFactor;
        #endif
    }

    return giAccum * inv;
}

// temporary gi solution :p
vec3 GlobalIllumination(vec3 viewPos, vec3 playerPos, vec3 normal, vec3 viewDir, float skyLightFactor, float linearZ0, float dither) {
    vec3 gi = vec3(0.0);
    vec3 base = viewPos + normal * 0.1;

    for (int i = 0; i < GI_SAMPLES; ++i) {
        vec3 dir = CosineSampleHemisphere(rand(dither, i), normal);

        float rayLen = far * GI_RADIUS;
        float stepLen = rayLen / float(GI_STEPS);
        vec3 rayStep = dir * stepLen;

        vec3 pos = base + rayStep * dither;

        for (int j = 0; j < GI_STEPS; ++j) {
            vec4 clip = gbufferProjection * vec4(pos, 1.0);
            if (clip.w <= 0.0) break;

            vec2 screenUV = (clip.xy / clip.w) * 0.5 + 0.5;
            if (any(lessThan(screenUV, vec2(0.0))) || any(greaterThan(screenUV, vec2(1.0)))) break;

            ivec2 uv = ivec2(screenUV / texelSize);
            float d = texelFetch(depthtex1, uv, 0).r;

            if (d < 1.0) {
                float sceneZ = GetLinearDepth(d);
                float rayZ = -pos.z;

                if (sceneZ < rayZ) {
                    vec3 col = texelFetch(colortex2, uv, 0).rgb;
                    float fade = exp(-max((rayZ - sceneZ) * 0.01 * GI_RADIUS, 0.0));
                    gi += col * fade;
                    break;
                }
            }

            pos += rayStep;
        }
    }

    return gi / float(GI_SAMPLES);
}

vec3 GITonemap(vec3 color) {
    // === Adjustable parameters ===

    float exposure = GI_INTENSITY;   // >1.0 = brighter, <1.0 = darker
    float saturation = 1.2; // >1.0 = more vibrant, <1.0 = more gray
    float gamma = 1.0;      // sRGB standard gamma
    float contrast = 1.4;   // >1.0 = higher contrast, <1.0 = flatter

    color *= exposure;

    const mat3 m1 = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777
    );
    const mat3 m2 = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602
    );

    vec3 v = m1 * color;
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    vec3 tonemapped = m2 * (a / b);

    float luminance = dot(tonemapped, vec3(0.2126, 0.7152, 0.0722));
    tonemapped = mix(vec3(luminance), tonemapped, saturation);

    tonemapped = mix(vec3(0.5), tonemapped, contrast);

    return pow(clamp(tonemapped, 0.0, 1.0), vec3(1.0 / gamma));
}