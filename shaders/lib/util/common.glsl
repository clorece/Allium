#ifndef COMMON_GLSL
#define COMMON_GLSL


#define texelSize (vec2(1.0) / vec2(viewWidth, viewHeight))


float rand(float seed) {
    return fract(sin(seed) * 43758.5453123) * 2.0 - 1.0;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float distx(float dist){
	return (((dist - near) * far) / ((far - near) * dist));
}

float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

vec2 octEncodeNormal(vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    vec2 e = (n.z >= 0.0)
        ? n.xy
        : (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    return e * 0.5 + 0.5;
}

vec3 octDecodeNormal(vec2 f) {
    f = f * 2.0 - 1.0;
    vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
    float t = max(-n.z, 0.0);
    n.x += (n.x >= 0.0) ? -t : t;
    n.y += (n.y >= 0.0) ? -t : t;
    return normalize(n);
}

float packColor565(vec3 c) {
    c = clamp(c, 0.0, 1.0);
    uint r = uint(c.r * 31.0 + 0.5);
    uint g = uint(c.g * 63.0 + 0.5);
    uint b = uint(c.b * 31.0 + 0.5);
    return float((r << 11) | (g << 5) | b) / 65535.0;
}

vec3 unpackColor565(float v) {
    uint p = uint(v * 65535.0 + 0.5);
    return vec3(float((p >> 11) & 31u) / 31.0,
                float((p >>  5) & 63u) / 63.0,
                float( p        & 31u) / 31.0);
}

bool isInShadow(vec3 worldPosCamRel) {
    vec4 sp = shadowProjection * shadowModelView * vec4(worldPosCamRel, 1.0);
    sp /= sp.w;

    float distortedDist = length(sp.xy);
    float distortFactor = (1.0 - SHADOW_MAP_BIAS) + distortedDist * SHADOW_MAP_BIAS;
    sp.xy /= distortFactor;
    sp = sp * 0.5 + 0.5;

    if (sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0 || sp.z < 0.0 || sp.z > 1.0) {
        return false;
    }

    float bias = 0.0015 * (4096.0 / float(SHADOW_RESOLUTION));
    float depth = texture(shadowtex1, sp.xy).r;
    return depth < (sp.z - bias);
}

#endif
