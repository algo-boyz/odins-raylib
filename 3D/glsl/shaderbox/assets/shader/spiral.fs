#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;

out vec4 fs_color;

#define PI 3.14159

struct PolarPoint {
    float a;
    float r;
};

vec2 uv_to_screen(vec2 uv, float aspect, float zoom) {
    // sp - Screen point in [-1.0, 1.0]
    vec2 sp = (uv * 2.0) - 1.0;

    sp.x *= aspect;
    sp *= zoom;

    return sp;
}

PolarPoint screen_to_polar(vec2 sp) {
    // a - Angle in [0.0, 1.0]
    float a = (atan(sp.y, sp.x) + PI) / (2.0 * PI);
    float r = length(sp);

    return PolarPoint(a, r);
}

vec2 polar_to_screen(PolarPoint pp) {
    float angle = (pp.a * 2.0 * PI) - PI;
    float radius = pp.r;

    return vec2(radius * cos(angle), radius * sin(angle));
}

PolarPoint transform_polar(PolarPoint pp) {
    float a = pp.a;
    float r = pp.r;

    a = a + floor(r - a);
    r = a;

    return PolarPoint(a, r);
}

void main() {
    float zoom = 2.0;

    vec2 sp0 = uv_to_screen(vs_uv, u_aspect, zoom);
    PolarPoint pp0 = screen_to_polar(sp0);
    PolarPoint pp1 = transform_polar(pp0);
    vec2 sp1 = polar_to_screen(pp1);

    vec2 smp0 = uv_to_screen(u_mouse_pos, u_aspect, zoom);
    PolarPoint pmp0 = screen_to_polar(smp0);
    PolarPoint pmp1 = transform_polar(pmp0);
    vec2 smp1 = polar_to_screen(pmp1);

    float d = 1.0 - distance(sp0, sp1);
    d = pow(d, 2.0) * sign(d);
    vec3 color = vec3(d);

    float c1 = 1.0 - smoothstep(-0.002, 0.002, distance(sp0, smp1) - 0.015);
    color = c1 * vec3(1.0, 0.0, 0.0) + (1.0 - c1) * color;

    fs_color = vec4(color, 1.0);
}

