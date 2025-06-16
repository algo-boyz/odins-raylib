#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec2 viewSize;

// Output fragment color
out vec4 finalColor;

// Simple bloom parameters
const float bloom_intensity = 0.8;
const int samples = 10;
const float quality = 0.7;
const float blur_step = 2.0;

void main()
{
    // Base color from the game texture
    vec4 base_color = texture(texture0, fragTexCoord);
    vec4 bloom_sum = vec4(0);

    // Sample pixels in a cross pattern around the current fragment
    for (int i = 1; i <= samples; i++) {
        float current_step = float(i) * blur_step / viewSize.x;
        
        // Horizontal samples
        bloom_sum += texture(texture0, fragTexCoord + vec2(current_step, 0.0));
        bloom_sum += texture(texture0, fragTexCoord - vec2(current_step, 0.0));

        // Vertical samples
        bloom_sum += texture(texture0, fragTexCoord + vec2(0.0, current_step));
        bloom_sum += texture(texture0, fragTexCoord - vec2(0.0, current_step));
    }
    
    // Average the bloom samples and apply quality/intensity
    bloom_sum *= quality / float(samples * 4);
    
    // Add the bloom effect to the base color (additive blending)
    finalColor = base_color + bloom_sum * bloom_intensity;
}