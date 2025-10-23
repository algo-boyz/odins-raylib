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
    
    // Convert to polar coordinates
    vec2 delta = uv - center;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);
    
    // Create tunnel effect
    float tunnel = 1.0 / (radius + 0.1);
    vec2 tunnelUV = vec2(
        angle / (3.14159 * 2.0) + time * 0.1,
        tunnel + time * 2.0
    );
    
    // Sample original texture with tunnel distortion
    vec2 distortedUV = center + delta * (1.0 + sin(radius * 10.0 - time * 5.0) * 0.1);
    
    vec4 originalColor = texture(texture0, distortedUV);
    
    // Add streaking light effects
    float streaks = abs(sin(angle * 8.0 + time * 4.0)) * (1.0 - radius);
    
    finalColor = originalColor + vec4(streaks * 0.3, streaks * 0.5, streaks * 0.8, 0.0);
    finalColor *= fragColor;
}
