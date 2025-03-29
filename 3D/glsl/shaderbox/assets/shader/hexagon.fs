#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define PI 3.141592

vec2 uv_to_sp(vec2 uv) {
    return (uv * 2) - 1;
}

vec2 sp_to_uv(vec2 sp) {
    return (sp + 1) / 2;
}

vec2 sp_to_ar(vec2 sp) {
    float a = (atan(sp.y, sp.x) / PI + 1) / 2;
    float r = length(sp);
    return vec2(a, r);
}

vec2 ar_to_sp(vec2 ar) {
    float a = ar.x * 2 * PI - PI;
    return vec2(ar.y * cos(a), ar.y * sin(a));
}

float cross2(vec2 a, vec2 b) {
    return a.x * b.y - a.y * b.x;
}

float calculate_r_offset(float a, float r, float n_splits) {
    float alpha = 2 * PI / n_splits;
    float betta = a * alpha;

    vec2 A = r * vec2(sin(0.5 * alpha), cos(0.5 * alpha));
    vec2 C = r * vec2(sin(0.5 * alpha - betta), cos(0.5 * alpha - betta));
    vec2 G = vec2(C.x, A.y);

    return distance(C, G) / sin(0.5 * (PI - alpha));
}

void main() {
    vec2 uv = vs_uv;

    vec2 sp = uv_to_sp(uv);

    vec2 ar = sp_to_ar(sp);
    float a = ar.x;
    float r = ar.y;

    float n_splits = 6;
    float sector = floor(a * n_splits);
    a = fract(n_splits * a);

    float curvature = 0.0;
    float r_offset = calculate_r_offset(a, r, n_splits);
    r = r + (1.0 - curvature) * r_offset;

    ar = vec2(a, r);
    float line_smoothness = 0.0025;
    float line_width = 0.05;
    float r_line = 1.0 - smoothstep(
                0.0, line_smoothness,
                abs(r - 1.0) - line_width
            );

    sp = ar_to_sp(ar);
    uv = sp_to_uv(sp);

    vec3 color = r_line * vec3(0.9, 0.7, 0.6);

    fs_color = vec4(color, 1.0);
}
