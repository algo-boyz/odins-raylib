#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform float time;
uniform vec2 resolution;

out vec4 finalColor;

void main()
{
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = fragTexCoord;
    
    vec4 color = vec4(0.0);
    int samples = 8;
    
    // Motion blur towards center
    vec2 direction = normalize(center - uv);
    float intensity = distance(uv, center) * 0.5;
    
    for(int i = 0; i < samples; i++)
    {
        float offset = float(i) / float(samples - 1);
        vec2 sampleUV = uv + direction * intensity * offset * 0.1;
        color += texture(texture0, sampleUV);
    }
    
    color /= float(samples);
    
    // Add brightness boost for distant objects
    float brightness = 1.0 + distance(uv, center) * 0.8;
    
    finalColor = color * brightness * fragColor;
}