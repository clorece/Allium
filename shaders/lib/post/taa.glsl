const bool colortex5Clear = false;

vec4 calculateNeighborhoodAverage(vec2 pixelPos, float radius, vec2 screenSize, sampler2D tex) {
  vec4 colorSum = vec4(0.0);
  float weightSum = 0.0;
  vec2 pixelUV = pixelPos / screenSize;

  for (float x = -radius; x <= radius; x += 1.0) {
    for (float y = -radius; y <= radius; y += 1.0) {
      vec2 offset = vec2(x, y);
      vec2 sampleUV = (pixelPos + offset) / screenSize;
      vec4 sampleColor = texture2D(tex, sampleUV);
      float distance = length(offset);
      float weight = 1.0 - smoothstep(radius - 0.5, radius + 0.5, distance);
      colorSum += sampleColor * weight;
      weightSum += weight;
    }
  }

  return colorSum / weightSum;
}

vec4 taa(vec2 currentPos, vec2 screenSize, sampler2D currentFrame, sampler2D historyFrame) {
    vec4 color = texture2D(currentFrame, texCoord);

    // Add jittering to the current pixel's position
    vec2 jitter = vec2(
        (fract(sin(dot(gl_FragCoord.xy, vec2(12.9898,78.233))) * 43758.5453 * TAA_JITTER_SPREAD) - 0.5) * TAA_JITTER_AMOUNT,
        (fract(sin(dot(gl_FragCoord.xy, vec2(39.968, 21.17))) * 43758.5453 * TAA_JITTER_SPREAD) - 0.5) * TAA_JITTER_AMOUNT
    );
    //currentPos += jitter;
    currentPos += mix(vec2(0.0), jitter, smoothstep(0.0, 1.0, length(jitter)));

    // Sample the color of the current pixel and the previous pixel
    vec4 currentColor = texture2D(currentFrame, currentPos);
    vec4 prevColor = texture2D(historyFrame, texCoord);

    // Temporal filter to blend the current and previous color based on history
    color += mix(currentColor, prevColor, 1.0);

    // Neighborhood clamp filter to limit color bleeding and reduce noise
    vec4 neighborhoodAverage = calculateNeighborhoodAverage(currentPos, 1.0, screenSize, currentFrame);
    color = mix(color, neighborhoodAverage, 0.5) / 1.5;

    return color;
}





