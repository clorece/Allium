#version 130

out vec2 texCoord;
out vec3 lightColor;
out vec3 ambientColor;
out vec3 lightVector;
out vec3 upVector;
out vec3 sunVector;
out vec3 moonVector;

uniform int worldTime;		//<ticks> = worldTicks % 24000
uniform vec3 sunPosition;
uniform vec3 upPosition;

void main() {
  	gl_Position = ftransform();
  	texCoord = gl_MultiTexCoord0.xy;

	lightColor = vec3(1.0, 1.0, 1.0); // noon
	ambientColor = vec3(0.0667, 0.0941, 0.1608); // day

  	sunVector = normalize(sunPosition);
	moonVector = normalize(-sunPosition);
  	upVector = normalize(upPosition);
  
  	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(-sunPosition);
		lightColor = vec3(0.0, 0.0784, 0.4196) * 0.75; // night
		ambientColor = vec3(0.0, 0.251, 0.8863) * 0.25; 
	}

	if ((worldTime <= 23250 && worldTime <= 3000) || (worldTime >= 11000 && worldTime <= 12700)) {
		lightColor = vec3(1.0, 0.6588, 0.4588); // sunrise / sunset
	}
}