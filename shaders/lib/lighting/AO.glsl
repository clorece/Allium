float rand(float dither, int i) {
    return fract(dither + float(i)*0.61803398875);
}

#if SSAO_QUALI == 3
    float geometryAwareOcclusion(vec3 surfaceNormal, vec3 viewDir, vec3 hitPos, vec3 viewPos) {
        // Estimate normal of the hit position using screen-space derivatives
        vec3 hitNormal = normalize(cross(dFdx(hitPos), dFdy(hitPos)));

        // Check if the hit surface is facing toward the view position
        float facing = dot(hitNormal, surfaceNormal);

        // Reject AO from back-facing geometry (e.g., through fences)
        if (facing < 0.3) return 0.0;

        // Optional: fade based on alignment to preserve softer edges
        return smoothstep(0.3, 1.0, facing);
    }

    #define SSRAO_QUALITY 12 //[2 8 12 16 20]
    #define SSRAO_I 1.0 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define SSRAO_STEP 4
    #define SSRAO_RADIUS 1.0 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
    #define DEPTH_TOLERANCE 12.0 //[1.0 2.0 8.0 12.0 16.0 24.0 32.0]

    float SSRAO(vec3 color, vec3 normalM, vec3 viewPos, sampler2D depthtex, float dither) {

        const int NUM_SAMPLES = SSRAO_QUALITY;
        const int MAX_STEPS = SSRAO_STEP;
        const float AO_RADIUS = SSRAO_RADIUS;

        float occlusion = 0.0;

        // Tangent space basis
        vec3 up = abs(normalM.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 tangent = normalize(cross(up, normalM));
        vec3 bitangent = cross(normalM, tangent);

        float invSamples = 1.0 / float(NUM_SAMPLES);
        float stepSize = AO_RADIUS / float(MAX_STEPS);

        for (int i = 0; i < NUM_SAMPLES; ++i) {
            
            float fi = float(i);
            float rand = fract(fi * 0.73 + dither * SSRAO_STEP);
            float phi = 6.2831 * (rand);
            float cosTheta = sqrt(1.0 - fi * invSamples);
            float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

            vec3 hemiDir = sinTheta * cos(phi) * tangent +
                        sinTheta * sin(phi) * bitangent +
                        cosTheta * normalM;

            vec3 rayDir = hemiDir * stepSize;
            vec3 rayPos = viewPos + normalM * 0.01 * color;

            for (int j = 0; j < MAX_STEPS; ++j) {
                rayPos += rayDir;

                vec4 projected = gbufferProjection * vec4(rayPos, 1.0);
                if (projected.w <= 0.0) break;

                vec2 screenUV = projected.xy / projected.w * 0.5 + 0.5;
                if (abs(screenUV.x - 0.5) > view.x || abs(screenUV.y - 0.5) > view.y) break;

                float sceneZ = texture2D(depthtex1, screenUV).r;
                vec4 hitClip = vec4(screenUV * 2.0 - 1.0, sceneZ * 2.0 - 1.0, 1.0);
                vec4 hitPos4 = gbufferProjectionInverse * hitClip;
                vec3 hitPos = hitPos4.xyz / hitPos4.w;

                float dz = hitPos.z - rayPos.z;
                float depthDiff = abs(hitPos.z - viewPos.z);

                if (dz > 0.001 && dz < stepSize * DEPTH_TOLERANCE && depthDiff < AO_RADIUS * 32.0) {
                    float geomFactor = geometryAwareOcclusion(normalM, rayDir, hitPos, viewPos);
                    float weight = (1.0 - smoothstep(0.0, stepSize * DEPTH_TOLERANCE, dz));
                    //occlusion -= geomFactor;
                    occlusion += weight * SSRAO_I;
                    break;
                }
            }
        }
        occlusion *= 0.5;

        float ao = 1.0 - (occlusion * invSamples);
        return clamp(ao, 0.0, 1.0);

    }
#endif

#if SSAO_QUALI == 2
float hash1(float x) {
    return fract(sin(x * 12.9898 + 78.233) * 43758.5453);
}

float SSAO(vec3 normalM, vec3 viewPos, sampler2D depthtex, float dither) {
    #define SSAO_SAMPLES 2
    #define SSAO_STEPS   12
    #define SSAO_RADIUS  1.0

    const vec2 rEdge = vec2(0.6, 0.55);

    // Build tangent basis
    vec3 upV = abs(normalM.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(upV, normalM));
    vec3 B = cross(normalM, T);

    float occlusion = 0.0;

    for (int i = 0; i < SSAO_SAMPLES; i++) {
        float rnd   = hash1(float(i) + dither);
        float phi   = 6.2831853 * rnd;
        float cosTh = sqrt(1.0 - rnd);
        float sinTh = sqrt(1.0 - cosTh * cosTh); // keep this version

        vec3 sampleDir = T * (cos(phi) * sinTh)
                       + B * (sin(phi) * sinTh)
                       + normalM * cosTh;

        for (int j = 1; j <= SSAO_STEPS; j++) {
            float t = float(j) / float(SSAO_STEPS) * SSAO_RADIUS;
            vec3 sampPos = viewPos + sampleDir * t;

            // Project to clip space
            vec4 clip = gbufferProjection * vec4(sampPos, 1.0);
            if (clip.w <= 0.0) break;
            vec2 uv = clip.xy / clip.w * 0.5 + 0.5;

            // Skip if offscreen
            if (abs(uv.x - 0.5) > rEdge.x || abs(uv.y - 0.5) > rEdge.y)
                break;

            // Reconstruct view-space position
            float sceneZ = texture2D(depthtex0, uv).r;
            vec4 projected = vec4(uv * 2.0 - 1.0, sceneZ * 2.0 - 1.0, 1.0);
            vec4 sceneVS4 = gbufferProjectionInverse * projected;
            vec3 sceneVS = sceneVS4.xyz / sceneVS4.w; // DO NOT skip this divide

            // AO test
            float bias = 0.005;
            if (sceneVS.z > sampPos.z + bias) {
                occlusion += 1.0;
                break;
            }
        }
    }

    float ao = 1.0 - occlusion / float(SSAO_SAMPLES * SSAO_STEPS);
    return clamp(ao, 0.0, 1.0);
}
#endif