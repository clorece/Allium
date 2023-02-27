float autoExposure(float x) {
    x += x * 8.0 / max(x * 4.0, (eyeBrightnessSmooth.y / 16.0));
    return x;
}

vec3 saturate(vec3 x) {
    return clamp(x, vec3(0.0), vec3(1.0));
}

vec3 getTonemap(vec3 color) {  
    float adjustedExposure = autoExposure(exposure);


    color = max(vec3(0.0), color - vec3(contrast / adjustedExposure));
	color = (color * (adjustedExposure * color + 0.5)) / (color * (adjustedExposure * color + 1.7) + 0.5);
    color = pow(color, vec3(1.0 / gamma));

    color = saturate(color * 1.33);

    return color;
}