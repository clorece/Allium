vec3 getBloom() {
    vec3 blur = vec3(1.0);
    //int weight = 0;
    int quality = 256;
    
    for(int i = 0; i < 6; i++){
            blur += texture2D(colortex3, texCoord + vec2(i, i) * rotation / quality).rgb;
            blur += texture2D(colortex3, texCoord + vec2(-i, i) * rotation / quality).rgb;
            blur += texture2D(colortex3, texCoord + vec2(i, -i) * rotation / quality).rgb;
            blur += texture2D(colortex3, texCoord + vec2(-i, -i) * rotation / quality).rgb;
    }
    //blur *= 2.0;
    
    return max(vec3(0.0), blur - vec3(1.0));
}