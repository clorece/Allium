/* 
    Jupiter Code is heavily derived from Jupiter II Shadertoy by viclw
    https://www.shadertoy.com/view/XsVBWG
*/

#define JUPITER
#define JUPITER_SCALE 40.0 

float GetEnderStarNoise(vec2 pos) {
    return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
}

mat2 Rot2D(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s,
                s,  c);
}

vec3 JupiterSwirl(vec2 uv, float time) {
    float timeScale = 0.0001;
    vec2 zoom = vec2(30.0, 4.5);
    vec2 offset = vec2(2.0, 1.0);

    vec2 point = uv * zoom + offset;

    float a_x = 0.2;
    float a_y = 0.2;

    for (int i = 1; i <= 10; i++) {
        float fi = float(i);
        point.x -= a_x * sin(fi * point.y + time * timeScale);
        point.y -= a_y * cos(fi * point.x + time * 0.01);
    }

    float r = cos(point.x + point.y + 2.0) * 0.5 + 0.5;
    float g = sin(point.x + point.y + 2.2) * 0.5 + 0.5;
    float b = (sin(point.x + point.y + 1.0) + cos(point.x + point.y + 1.5)) * 0.5 + 0.5;

    vec3 col = vec3(r, g, b);
    col += vec3(0.5); 

    return col;
}



vec3 GetEndSky(vec3 viewPos, float VdotU) {
    float VdotS = dot(viewPos, sunVec);
    vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos * 1000.0, 1.0)).xyz);

    vec3 starCoord = 0.65 * wpos / (abs(wpos.y) + length(wpos.xz));
    vec2 starCoord2 = starCoord.xz * 0.5;
    if (VdotU < 0.0) starCoord2 += 100.0;
    float starFactor = 4096.0;
    starCoord2 = floor(starCoord2 * starFactor) / starFactor;

    float star = 1.0;
    star *= GetEnderStarNoise(starCoord2.xy);
    star *= GetEnderStarNoise(starCoord2.xy + 0.1);
    star *= GetEnderStarNoise(starCoord2.xy + 0.23);
    star = max(star - 0.7, 0.0);
    star *= star;

    vec3 enderStars = star * endSkyColor * 3000.0;

    float VdotUM1 = abs(VdotU);
    float VdotUM2 = pow(1.0 - VdotUM1, 2.0);
    enderStars *= VdotUM1 * VdotUM1 * (VdotUM2 + 0.015) + 0.015;

    #ifdef JUPITER
        vec3 jupiterDir_world = normalize(vec3(-5.5, -1.0, -0.85));
        vec3 jupiterDir_view = normalize(mat3(gbufferModelView) * jupiterDir_world);

        float cosAngle = dot(normalize(viewPos), jupiterDir_view);

        float jupiterAngularRadius = 0.02 * JUPITER_SCALE;

        float circle = smoothstep(cos(jupiterAngularRadius + 0.005), cos(jupiterAngularRadius), cosAngle);

        vec3 jupiterColor = vec3(0.0);

        if (circle > 0.0) {
            vec3 jupiterToView_world = normalize((gbufferModelViewInverse * vec4(viewPos, 0.0)).xyz - jupiterDir_world);

            vec3 jupiterUp_world = vec3(0.0, 1.0, 0.0);
            if (abs(dot(jupiterDir_world, jupiterUp_world)) > 0.99) jupiterUp_world = vec3(1.0, 0.0, 0.0);
            vec3 jupiterRight_world = normalize(cross(jupiterUp_world, jupiterDir_world));
            jupiterUp_world = normalize(cross(jupiterDir_world, jupiterRight_world));

            vec2 uv = vec2(dot(jupiterToView_world, jupiterRight_world), dot(jupiterToView_world, jupiterUp_world));
                uv = uv / sin(jupiterAngularRadius) * 0.5 + 0.5;
                uv *= 0.5;

            float swirlAngle = radians(270.0);
            vec2 rotatedUV = Rot2D(swirlAngle) * uv;

            vec3 swirlCol = JupiterSwirl(rotatedUV, frameTimeCounter);

            float dist = distance(uv, vec2(0.4));
            float ambient = pow(smoothstep(0.5, 0.0, dist), 1.5);

            jupiterColor = vec3(1.0, 0.85, 0.6) * swirlCol * 8.0;
            jupiterColor *= ambient;

            float highlight = smoothstep(1.0, 0.0, dist) * 1.0;
            highlight = pow(highlight, 2.0);

            vec3 highlightColor = jupiterColor * 2.0;

            enderStars = (jupiterColor * circle + highlightColor * highlight * (1.0 - circle)) * 0.175;
            enderStars *= (1.0 - circle); // prevent stars from rendering in the circle
        }

        float angleFromCenter = acos(clamp(cosAngle, -1.0, 1.0));

        float glowStart = jupiterAngularRadius;
        float glowEnd   = jupiterAngularRadius * 3.0;

        float glow = smoothstep(glowEnd, glowStart, angleFromCenter);
        glow = pow(glow, 2.0); 

        vec3 glowColor = vec3(1.0, 0.74, 0.55) * 1.0;

        enderStars += (jupiterColor * circle + glowColor * glow * (1.0 - circle)) * 0.175;
        #endif

    return enderStars;
}