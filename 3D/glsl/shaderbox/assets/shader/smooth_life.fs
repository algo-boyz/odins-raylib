#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_resolution;

out vec4 fs_color;

float ra = 2.0;
float b1 = 0.257;
float b2 = 0.336;
float d1 = 0.365;
float d2 = 0.549;
float alpha_n = 0.028;
float alpha_m = 0.147;

#define PI 3.14159265359

float sigma(float x, float a, float alpha) {
    return 1.0 / (1.0 + exp(-(x - a) * 4.0 / alpha));
}

float sigma_n(float x, float a, float b) {
    return sigma(x, a, alpha_n) * (1.0 - sigma(x, b, alpha_n));
}

float sigma_m(float x, float y, float m) {
    return x * (1.0 - sigma(m, 0.5, alpha_m)) + y * sigma(m, 0.5, alpha_m);
}

float s(float n, float m) {
    return sigma_n(n, sigma_m(b1, d1, m), sigma_m(b2, d2, m));
}

// Simple hash function for pseudo-random values
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Function to get cell state - using time-based noise for initial pattern
float grid(float x, float y) {
    vec2 coord = vec2(x, y) / u_resolution.xy;
    
    // Create initial pattern using noise and time
    float noise = hash(coord + floor(u_time * 0.1));
    
    // Add some moving patterns
    float pattern = sin(coord.x * 10.0 + u_time) * cos(coord.y * 10.0 + u_time * 0.7);
    pattern = (pattern + 1.0) * 0.5;
    
    // Combine noise and pattern
    return smoothstep(0.4, 0.6, noise * 0.7 + pattern * 0.3);
}

void main() {
    // Convert UV coordinates to pixel coordinates
    vec2 pixelCoord = vs_uv * u_resolution;
    float cx = pixelCoord.x;
    float cy = pixelCoord.y;

    float ri = ra / 3.0;
    float m = 0.0;
    float M = PI * ri * ri;
    float n = 0.0;
    float N = PI * ra * ra - M;

    // Sample in a circular region
    for (float dy = -ra; dy <= ra; dy += 1.0) {
        for (float dx = -ra; dx <= ra; dx += 1.0) {
            float x = cx + dx;
            float y = cy + dy;
            float dist_sq = dx * dx + dy * dy;
            if (dist_sq <= ri * ri) {
                m += grid(x, y);
            } else if (dist_sq <= ra * ra) {
                n += grid(x, y);
            }
        }
    }
    
    m /= M;
    n /= N;
    
    float q = s(n, m);
    float diff = 2.0 * q - 1.0;
    
    // Use a fixed time step for stability
    float dt = 0.016; // ~60 FPS
    float current_value = grid(cx, cy);
    float v = clamp(current_value + dt * diff, 0.0, 1.0);
    
    // Create a more interesting visual output
    vec3 color = vec3(v);
    
    // Add some color variation based on the local density
    color.r = v;
    color.g = v * (0.5 + 0.5 * sin(u_time + m * 10.0));
    color.b = v * (0.5 + 0.5 * cos(u_time + n * 8.0));
    
    fs_color = vec4(color, 1.0);
}