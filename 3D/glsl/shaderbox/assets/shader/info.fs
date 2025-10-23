#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

void main() {
    // Use the normalized UV coordinates from vertex shader
    vec2 uv = (vs_uv - 0.5) * 2.0;  // Convert [0,1] to [-1,1]
    uv.x *= u_aspect;  // Apply aspect ratio correction

    // Rotate coordinates over time
    float angle = u_time * 0.5;
    mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    uv = rot * uv;

    // Radii definitions
    float r_main = 0.9;
    float r_half = r_main * 0.5;
    float r_dot = r_half * 0.3;

    float dist = length(uv);
    float mask = step(dist, r_main);

    // Yin-Yang base: white if right of center, black otherwise
    float base = step(0.0, uv.x);  // 1.0 (white) if x >= 0, else 0.0 (black)

    // Small circle centers
    vec2 centerTop = vec2(0.0, r_half);
    vec2 centerBottom = vec2(0.0, -r_half);

    float dTop = length(uv - centerTop);
    float dBottom = length(uv - centerBottom);
   
    // Switch colors based on small circle inclusion
    if (dTop < r_half) base = 0.0;
    if (dBottom < r_half) base = 1.0;

    // Draw inner dots
    if (dTop < r_dot) base = 1.0;
    if (dBottom < r_dot) base = 0.0;

    vec3 color = vec3(base) * mask;
    fs_color = vec4(color, mask); // Smooth edge using alpha
}