#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;

out vec4 fs_color;

#define PI 3.14159

void main() {
    float zoom = 4.0;
    vec2 sp0 = 2.0 * vs_uv - 1.0;
    sp0.x *= u_aspect;
    sp0 *= zoom;

    float r = length(sp0);
    float a = 0.5 * (atan(sp0.y, sp0.x) / PI + 1.0);

    float q = 10.0;
    float sector = abs(2.0 * (fract(a * q) - 0.5));

    // Spiral line
    float spiral;
    {
        float line_width = 0.02 + 0.01 * r;
        float line_smoothness = 0.25 * line_width;
        spiral = fract(
                r
                    + a
                    + r * 0.2 * pow(sector, 0.5)
            );

        spiral = 1.0 - smoothstep(0.0, line_smoothness, spiral - line_width);
        spiral *= float(r < 4.5);
    }

    // Radial lines
    float radials;
    {
        float line_width = 0.01 + 0.01 * r;
        float line_smoothness = 0.25 * line_width;
        radials = min(sector, 1.0 - sector);
        radials = 1.0 - smoothstep(0.0, line_smoothness, radials - line_width);
        radials *= float(r < 4.0);
    }

    float c = spiral + radials;
    vec3 color = c * vec3(1.0, 0.3, 0.2);

    fs_color = vec4(color, 1.0);
}
