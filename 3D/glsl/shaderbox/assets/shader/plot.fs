// plot.fs
#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

float hash(float n) {
    n = fract(n * 17.0371);
    n *= n + 33.33;
    n *= sin(n) * 43758.5453123;
    return fract(n);
}

void main() {
    vec3 color;
    vec2 screen_sp;
    {
        screen_sp = vs_uv * 2.0 - 1.0;
        screen_sp.x *= u_aspect;
    }
    float axis_thickness = 0.0025;
    float axis_smoothness = 0.001;

    vec3 axis_color;
    {
        float line = smoothstep(
                0.5 * axis_thickness + axis_smoothness,
                0.5 * axis_thickness,
                min(abs(screen_sp.y), abs(screen_sp.x))
            );
        axis_color = vec3(line);
    }
    float circles_density = 50.0;
    float circle_radius = 0.015;
    float circle_smoothness = 0.05;
    vec3 circle_base_color = vec3(1.0, 0.5, 0.2);

    vec3 circle_color;
    {
        float x = fract(screen_sp.x * circles_density) * 2.0 - 1.0;
        vec2 p = vec2(x, screen_sp.y * circles_density * 2.0);

        float circle_idx = floor(screen_sp.x * circles_density);
        float circle_y = hash(circle_idx) * 2.0 - 1.0;
        float d = distance(p, vec2(0.0, circle_y * circles_density * 1.25));
        float r = circles_density * circle_radius;
        float circle = 1.0 - smoothstep(r, r + circle_smoothness, d);

        circle_color = circle * circle_base_color;
    }
    color = axis_color + circle_color;
    fs_color = vec4(color, 1.0);
}
