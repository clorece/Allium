#include "/lib/options.glsl"

// gbuffers_water : deferred water G-buffer writer.
//
// Blending is OFF (see shaders.properties) and the program writes colortex1 +
// colortex2 (DRAWBUFFERS:12), NOT colortex0 — so colortex0's lit scene is left
// untouched and composite `c_water` gets an intact refraction background.
//
// Water (block id 10006) stores its view-space wave normal in colortex1.rgb and a
// water flag in colortex2.b (= 1.0). colortex2 is the lightmap buffer, but it is
// only read by the deferred chain (d0_restir / d7), which runs BEFORE this pass, so
// it is free to repurpose afterward. The flag is used instead of colortex1.a + a
// depth test because (a) emissive blocks also carry colortex1.a=1.0 and (b) this
// pack's depthtex1 doesn't separate translucents, so a depth test can't isolate
// water. colortex2.b is 0 for all opaque geometry -> unambiguous water mask.
// Glass / ice render invisible for now (they no longer write colortex0); basic
// glass shading can be added to c_water later.

#ifdef VERTEX

#include "/lib/util/jitter.glsl"
// pure FBM height + trochoidal displacement (no fragment-only deps)
#include "/lib/fragment/water.glsl"

out vec2 texCoord;
out vec2 lightmapCoord;
out vec3 viewNormal;
out vec3 worldPos;
out vec4 color;
flat out float isWater;
flat out float matFlag; // colortex2.b material code: 0.25 solid ice / 0.5 clear ice / 0.75 glass / 1.0 water
out vec3 viewTangent;
out float tangentW;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

void main() {
    gl_Position = ftransform();
    texCoord = gl_MultiTexCoord0.xy;

    color = gl_Color;
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    tangentW = at_tangent.w;
    lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;

    float eid = mc_Entity.x;
    isWater = (eid == 10006.0) ? 1.0 : 0.0;
    matFlag = (eid == 10006.0) ? 1.0 :   // water
              (eid == 10004.0) ? 0.75 :  // glass / stained glass / panes
              (eid == 10007.0) ? 0.5  :  // clear ice (ice, frosted_ice)
              (eid == 10008.0) ? 0.25 :  // solid ice (packed_ice, blue_ice)
              0.75;                       // fallback: unknown translucent -> glass

    #ifdef WATER_DISPLACEMENT
    if (isWater > 0.5) {

        vec3 worldDisp = waterDisplacement(worldPos.xz, frameTimeCounter * WATER_WAVE_SPEED);
        worldPos += worldDisp;
        viewPos  += mat3(gbufferModelView) * worldDisp;
        gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
    }
    #endif

    #ifdef TAA
        gl_Position.xy += getTaaJitter() * 2.0 * gl_Position.w / vec2(viewWidth, viewHeight);
    #endif

    gl_Position.xy = gl_Position.xy * renderScale + gl_Position.w * (renderScale - 1.0);
}

#endif

#ifdef FRAGMENT

#include "/lib/util/common.glsl"
#include "/lib/fragment/water.glsl"

in vec2 texCoord;
in vec2 lightmapCoord;
in vec3 viewNormal;
in vec3 worldPos;
in vec4 color;
flat in float isWater;
flat in float matFlag;
in vec3 viewTangent;
in float tangentW;

/* DRAWBUFFERS:12 */

void main() {
    vec4 albedo = texture(texture, texCoord) * color;

    if (isWater < 0.5 && albedo.a < 0.1) discard;

    if (isWater > 0.5) {
        vec3 worldGeoN = normalize(mat3(gbufferModelViewInverse) * viewNormal);
        vec3 worldN = worldGeoN;

        #ifdef WATER_WAVES
        {
            float t = frameTimeCounter * WATER_WAVE_SPEED;

            float camDist = length(worldPos - cameraPosition);
            float lod = clamp(camDist / WATER_NORMAL_FADE, 0.0, 1.0);
            float fadeMin = WATER_NORMAL_FADE_MIN * 0.01;
            float strength = WATER_NORMAL_STRENGTH * mix(1.0, fadeMin, lod);
            float eps = mix(0.10, 0.45, lod);

            worldN = waterSurfaceNormal(worldPos, worldGeoN, t, WATER_WAVE_AMPLITUDE, strength, eps);
        }
        #endif

        vec3 viewWaveN = normalize(mat3(gbufferModelView) * worldN);
        gl_FragData[0] = vec4(viewWaveN * 0.5 + 0.5, 1.0);     // colortex1: wave normal
        gl_FragData[1] = vec4(lightmapCoord, 1.0, 1.0);        // colortex2: .rg lightmap, .b=1 water flag
    } else {

        const float GEN_NORMAL_STRENGTH = 2.0;
        const vec3  LUMA = vec3(0.2126, 0.7152, 0.0722);
        vec2  atlasTexel = 1.0 / vec2(textureSize(texture, 0));
        float l  = dot(albedo.rgb, LUMA);
        float lu = dot((texture(texture, texCoord + vec2(atlasTexel.x, 0.0)) * color).rgb, LUMA);
        float lv = dot((texture(texture, texCoord + vec2(0.0, atlasTexel.y)) * color).rgb, LUMA);
        vec3 T = normalize(viewTangent);
        vec3 B = normalize(cross(viewNormal, T) * tangentW);
        vec3 fN = normalize(viewNormal - GEN_NORMAL_STRENGTH * ((lu - l) * T + (lv - l) * B));

        gl_FragData[0] = vec4(fN * 0.5 + 0.5, 0.5);                          // colortex1: generated normal
        gl_FragData[1] = vec4(lightmapCoord, matFlag, packColor565(albedo.rgb)); // colortex2: lightmap, flag, packed colour
    }
}

#endif
