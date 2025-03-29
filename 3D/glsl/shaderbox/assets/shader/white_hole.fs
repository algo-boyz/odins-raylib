#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;

out vec4 fs_color;

#define PI 3.14159

vec3 get_color(vec2 uv) {
    float time = u_time;
    vec3 color = vec3(0.0);

    vec2 p = uv;
    int n_levels = 10;
    for (int i_level = 0; i_level < n_levels; ++i_level) {
        float true_scale = pow(2.0, i_level);

        // ---------------------------------------------------------------
        // Level parameters
        float scale_factor = true_scale;
        float line_width = 0.05 * scale_factor;
        float line_smoothness = line_width * 5.0;
        float brightness = 1.0 / pow(0.8 * scale_factor, 2.0);

        // ---------------------------------------------------------------
        // Level local space

        // Transform space in cartesian
        p = (p * 2.0) - 1.0;
        p.x *= u_aspect;

        p.y = mix(p.y, exp(0.8 * p.y) - 1.2, 0.1 * sin(time));

        // Transform space in polar
        float r = length(p);
        float a = (atan(p.y, p.x) / PI + 1.0) * 0.5;
        a = 4 * r * pow(a, mix(0.4, 1.0, a));
        a += fract(0.1 * time);

        // Do some "artistic" stuff with brightness
        brightness *= 12.0 * exp(-6.0 * r);
        brightness -= pow(0.05 * r, 0.8);
        brightness += 0.11 * sin(2.0 * r);

        a = a * 2.0 * PI - PI;
        p = vec2(r * cos(a), r * sin(a));

        // Draw in cartesian

        // circle
        float sd0;
        {
            float r = 0.5 - 0.3 * p.y;
            r = r + 0.03 * sin(6 * a * PI);
            sd0 = length(p) - r;
        }

        // horizontal line
        float sd1 = abs(p.y);

        // sd
        float sd = min(sd0, sd1);

        float line = 1.0 - smoothstep(0.0, line_smoothness, abs(sd) - line_width);

        vec3 _color = line * vec3(1.0, 0.6, 0.4);
        _color *= brightness;

        color += _color;
        p = fract(p);
    }

    return color;
}

void main() {
    vec2 uv = vs_uv;
    vec3 color = get_color(uv);

    fs_color = vec4(color, 1.0);
}
