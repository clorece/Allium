/*
Shadertoy Atmospheric Scattering
https://www.shadertoy.com/view/4tVSRt
By: robobo1221
*/

float mie(vec3 fragPosition){
	return pow(dot(normalize(fragPosition), sunVector)* 0.5 + 0.5, 3.14 * 10.0);
}

float sun(vec3 fragPosition){
    float size = 7000.0;
	return pow(dot(normalize(fragPosition), sunVector) * 0.5 + 0.5, 3.14 * size);
}

vec3 getSky(vec3 fragPosition){
	vec3 fogColor = vec3(0.3294, 0.5373, 0.9804);
	vec3 normalizeFragPosition = normalize(fragPosition);
	float horizon = 0.1 / max(dot(normalizeFragPosition, upVector), 0.0);
	    horizon = clamp(horizon, 0.0, 10.0);

	vec3 color = fogColor * horizon;

    color = max(color, 0.0);

	color = max(mix(pow(color, 1.0 - color), color / (1.5 * color + 0.1 - color), clamp(dot(sunVector, upVector) * 0.5 + 0.5, 0.2, 1.0) + lightColor * 0.5),0.0);
    color /= 1.0 + pow(dot(normalizeFragPosition, upVector) * 0.5 + 0.5, 1.0);
    color += lightColor * (mie(fragPosition) * 0.5);

	float underscatter = distance(dot(sunVector, upVector) * 0.5 + 0.5, 1.0);
	
	color = mix(color, vec3(0.0), clamp(underscatter, 0.0, 1.0));

    return color;
}