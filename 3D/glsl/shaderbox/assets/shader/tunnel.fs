//Credit: https://www.shadertoy.com/view/MlsfWS
#version 330

uniform vec2 resolution;
uniform float time;

out vec4 fragColor;

#define PI 3.14159
#define TAU (2.0 * PI)
#define I_MAX 200.0
#define E 0.0001
#define FAR 50.0

vec3 ret_col;
vec3 h;

float mylength(vec2 p) {
    p = p * p * p * p;
    p = p * p;
    float ret = pow(p.x + p.y, 1.0 / 8.0);
    return ret;
}

vec2 modA(vec2 p, float count) {
    float an = TAU / count;
    float a = atan(p.y, p.x) + an * 0.5;
    a = mod(a, an) - an * 0.5;
    return vec2(cos(a), sin(a)) * length(p);
}

void rotate(inout vec2 v, float angle) {
    v = vec2(cos(angle) * v.x + sin(angle) * v.y, -sin(angle) * v.x + cos(angle) * v.y);
}

vec2 rot(vec2 p, vec2 ang) {
    float c = cos(ang.x);
    float s = sin(ang.y);
    mat2 m = mat2(c, -s, s, c);
    return p * m;
}

vec3 camera(vec2 uv) {
    float fov = 1.0;
    vec3 forw = vec3(0.0, 0.0, -1.0);
    vec3 right = vec3(1.0, 0.0, 0.0);
    vec3 up = vec3(0.0, 1.0, 0.0);
    return normalize((uv.x) * right + (uv.y) * up + fov * forw);
}

float scene(vec3 p) {
    float var;
    float mind = 1e5;
    vec3 op = p;

    var = atan(p.x, p.y);
    var = cos(var + floor(p.z) + time * (mod(floor(p.z), 2.0) - 1.0 == 0.0 ? -1.0 : 1.0));
    
    ret_col = 1.0 - vec3(0.5 - var * 0.5, 0.5, 0.3 + var * 0.5);
    mind = length(p.xy) - 1.0 + 0.1 * var;
    mind = max(mind, -(length(p.xy) - 0.9 + 0.1 * var));

    p.xy = modA(p.yx, 50.0 + 50.0 * sin(p.z * 0.25));
    p.z = fract(p.z * 3.0) - 0.5;

    float dist_cylinder = length(p.zy) - 0.0251 - 0.25 * sin(op.z * 5.5);
    dist_cylinder = max(dist_cylinder, -p.x + 0.4 + clamp(var, 0.0, 1.0));

    mind = min(mind, dist_cylinder);

    h += vec3(0.5, 0.8, 0.5) * (var != 0.0 ? 1.0 : 0.0) * 0.0125 / (0.01 + max(mind - var * 0.1, 0.0001) * max(mind - var * 0.1, 0.0001));

    return mind;
}

vec2 march(vec3 pos, vec3 dir) {
    vec2 dist = vec2(0.0, 0.0);
    vec3 p;

    for (float i = 0.0; i < I_MAX; ++i) {
        p = pos + dir * dist.y;
        dist.x = scene(p);
        dist.y += dist.x * 0.2;
        if (dist.x < E || dist.y > FAR) break;
    }

    return vec2(dist.y < FAR ? 1.0 : 0.0, dist.y);
}

void main() {
    h = vec3(0.0);
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution.xy) / resolution.y;
    vec3 dir = camera(uv);
    vec3 pos = vec3(0.0, 0.0, 4.5 - time * 2.0);

    vec2 inter = march(pos, dir);
    vec3 col = vec3(0.0);

    if (inter.y <= FAR)
        col = ret_col * (1.0 - inter.x * 0.0025);

    col += h * 0.005125;
    fragColor = vec4(col, 1.0);
}