uniform float near; 
uniform float far;
uniform float viewWidth;                    
uniform float viewHeight;  

vec2 texelSize = vec2(1.0) / vec2(viewWidth, viewHeight);

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