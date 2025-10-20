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
    
    // Calculate distance from center
    float dist = distance(uv, center);
    
    // Create pulsing zoom effect
    float zoom = 1.0 + sin(time * 2.0) * 0.1;
    
    // Apply radial distortion for "warp speed" effect
    vec2 dir = normalize(uv - center);
    float warp = pow(dist, 1.5) * 0.3;
    
    // Combine effects
    vec2 newUV = center + (uv - center) * zoom + dir * warp * sin(time * 3.0);
    
    // Sample texture with chromatic aberration
    float aberration = dist * 0.02;
    vec4 colorR = texture(texture0, newUV + vec2(aberration, 0.0));
    vec4 colorG = texture(texture0, newUV);
    vec4 colorB = texture(texture0, newUV - vec2(aberration, 0.0));
    
    finalColor = vec4(colorR.r, colorG.g, colorB.b, colorG.a) * fragColor;
}
