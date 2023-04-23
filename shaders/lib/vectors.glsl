sunVector = normalize(sunPosition);
moonVector = normalize(-sunPosition);
upVector = normalize(upPosition);

// 23250 < worldTime < 12700
if (worldTime < 12700 || worldTime > 23250) {
	lightVector = normalize(sunPosition);
} else {
	lightVector = normalize(-sunPosition);
}