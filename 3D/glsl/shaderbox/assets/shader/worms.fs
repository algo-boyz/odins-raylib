#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;

out vec4 fs_color;

#define PI 3.14159

void main() {
    float time = 0.1 * u_time;

    // -------------------------------------------------------------------
    // sp - Screen point
    vec2 sp = (vs_uv * 2.0) - 1.0;

    float root_zoom = 8.0;

    sp *= root_zoom * 0.5;
    sp.x *= u_aspect;

    // -------------------------------------------------------------------
    // Polar transformations
    float a = 0.5 * (atan(-sp.y, -sp.x) / PI + 1.0);
    float r = length(sp);
    float turn = (floor(r) + 1.0);
    float rotation_speed = -0.01 * turn - 0.01;

    a = fract(a - time * rotation_speed);

    // -------------------------------------------------------------------
    // Local sector space
    vec3 color;
    {
        float split = 1.0;
        float compactness = 1.6;

        vec2 p0 = vec2(
                fract(split * turn * a),
                (fract(r) * 2.0) - 1.0
            );
        p0.x *= compactness;
        p0.y /= compactness;

        vec2 p1 = vec2(0.5, 0.0);

        float size = 0.22;
        float m = 0.025 * sin(10.0 * p0.x - 0.5 * turn * u_time);
        size = size + m;

        float rings = 16.0;
        vec3 base_color = vec3(1.0, 0.9, 0.83);
        vec3 base_tint = vec3(0.9, 0.9, 0.8);
        float body_brightness = 0.6;
        float light = -60.0;
        float luminosity = 0.0;
        float emission = 30.0;
        float metalness = 0.0;
        float bot_light = 0.5;

        float d = distance(p0, p1);
        float sd = d - size;
        float body = 1.0 - smoothstep(0.0, 0.05, sd - 0.01);
        float strips = 0.5 * abs(abs((fract(p0.x * rings * size) - 0.5) * 2.0) - 0.5);

        vec3 body_color = body_brightness * body * base_color;
        color = body_color + (10 * (exp(emission * abs(m)) - 1.0)) * body * strips * base_tint;
        color = color * (1.0 + luminosity * abs(p0.y) * strips);
        color = color * exp(1.5 * size);
        color = color * (1.0 - d);
        color = color + light * pow(d, 4.0);

        color = min(color, vec3(1.0));
        color = max(color, vec3(0.0));

        color = color * pow(body * (1.0 - d), metalness);
        color = color * (1.0 - body * pow(d, bot_light));
    }

    fs_color = vec4(color, 1.0);
}
