#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

out vec4 fs_color;

// Simple hash function for pseudo-random values (replaces texture lookup)
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 GetGradient(vec2 intPos, float t) {
    // Use calculated rand instead of texture lookup
    float rand = hash(intPos);
    
    // Rotate gradient: random starting rotation, random rotation rate
    float angle = 6.283185 * rand + 4.0 * t * rand;
    return vec2(cos(angle), sin(angle));
}

float Pseudo3dNoise(vec3 pos) {
    vec2 i = floor(pos.xy);
    vec2 f = pos.xy - i;
    vec2 blend = f * f * (3.0 - 2.0 * f);
    float noiseVal = 
        mix(
            mix(
                dot(GetGradient(i + vec2(0, 0), pos.z), f - vec2(0, 0)),
                dot(GetGradient(i + vec2(1, 0), pos.z), f - vec2(1, 0)),
                blend.x),
            mix(
                dot(GetGradient(i + vec2(0, 1), pos.z), f - vec2(0, 1)),
                dot(GetGradient(i + vec2(1, 1), pos.z), f - vec2(1, 1)),
                blend.x),
        blend.y
    );
    return noiseVal / 0.7; // normalize to about [-1..1]
}

void main() {
    vec2 p = vs_uv;
    p -= 0.5;
    p.x *= u_aspect;
    
    // Convert to coordinate system similar to Shadertoy
    vec2 uv = p * 5.0; // Scale factor to match original appearance
    
    // Use mouse position to switch between modes
    // When mouse is on left side: show single noise channel
    // When mouse is on right side: show layered noise with color palette
    if (u_mouse_pos.x < 0.5) {
        float noiseVal = 0.5 + 0.5 * Pseudo3dNoise(vec3(uv * 2.0, u_time));
        fs_color = vec4(vec3(noiseVal), 1.0);
    }
    else {
        // Layered noise
        const int ITERATIONS = 10;
        float noiseVal = 0.0;
        float sum = 0.0;
        float multiplier = 1.0;
        vec2 layered_uv = uv;
        
        for (int i = 0; i < ITERATIONS; i++) {
            vec3 noisePos = vec3(layered_uv, 0.2 * u_time / multiplier);
            noiseVal += multiplier * abs(Pseudo3dNoise(noisePos));
            sum += multiplier;
            multiplier *= 0.6;
            layered_uv = 2.0 * layered_uv + 4.3;
        }
        noiseVal /= sum;
        
        // Map to a color palette
        vec3 color = 0.5 + 0.5 * cos(6.283185 * (3.0 * noiseVal + vec3(0.15, 0.0, 0.0)));
        fs_color = vec4(color, 1.0);
    }
}