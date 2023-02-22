#version 130

in vec2 texCoord;
in vec3 lightColor;
in vec3 ambientColor;
in vec3 lightVector;
in vec3 upVector;
in vec3 sunVector;
in vec3 moonVector;

uniform int worldTime;
uniform float rainStrength;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

float depth0 = texture2D(depthtex0, texCoord).x;
float depth1 = texture2D(depthtex1, texCoord).x;
vec3 clipSpace0 = vec3(texCoord, depth0) * 2.0 - 1.0;
vec3 clipSpace1 = vec3(texCoord, depth1) * 2.0 - 1.0;

float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec4 getFragPosition() {
    vec4 fragPosition = gbufferProjectionInverse * vec4(clipSpace0, 1.0);
    fragPosition.xyz /= fragPosition.w;

    return fragPosition;
}

vec4 getFragPosition2() {
    vec4 fragPosition = gbufferProjectionInverse * vec4(clipSpace1, 1.0);
    fragPosition.xyz /= fragPosition.w;

    return fragPosition;
}

vec4 getWorldPosition() {
    vec4 fragPosition = getFragPosition();
    vec4 worldPosition = gbufferModelViewInverse * vec4(fragPosition.xyz, 1.0);

    return worldPosition;
}

/*
Shadertoy Atmospheric Scattering
https://www.shadertoy.com/view/4tVSRt
By: robobo1221
*/

float mie(vec3 fragPosition){
	return pow(dot(normalize(fragPosition), sunVector)* 0.5 + 0.5, 3.14 * 10.0);
}

float sun(vec3 fragPosition){
    float size = 700.0;
	return pow(dot(normalize(fragPosition), sunVector) * 0.5 + 0.5, 3.14 * size);
}

vec3 getSky(vec3 fragPosition){
	vec3 fogColor = vec3(0.3294, 0.5373, 0.9804);
	vec3 normalizeFragPosition = normalize(fragPosition);
	float horizon = 0.1 / max(dot(normalizeFragPosition, upVector), 0.0);
	    horizon = clamp(horizon, 0.0, 10.0);

	vec3 color = fogColor * horizon;

    color = max(color, 0.0);

	color = max(mix(pow(color, 1.0 - color), color / (1.5 * color + 0.1 - color), clamp(dot(sunVector, upVector) * 0.5 + 0.5, 0.2, 1.0)),0.0);
    color += lightColor * (sun(fragPosition) * 5.0);
    color += lightColor * (mie(fragPosition) * 0.5);
    color /= 1.0 + pow(dot(normalizeFragPosition, upVector) * 0.5 + 0.5, 1.0);

	float underscatter = distance(dot(sunVector, upVector) * 0.5 + 0.5, 1.0);
	
	color = mix(color, vec3(0.0), clamp(underscatter, 0.0, 1.0));

    return color;
}

void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;

	vec4 fragPosition0 = getFragPosition();

    if (depth0 == 1 && (worldTime < 12700 || worldTime > 23250)) {
        color = getSky(fragPosition0.xyz); 
    }

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}