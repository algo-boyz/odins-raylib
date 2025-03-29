#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define PI 3.141592

// -----------------------------------------------------------------------
// Simplex 3D Noise
// by Ian McEwan, Stefan Gustavson (https://github.com/stegu/webgl-noise)
vec4 permute(vec4 x) {
    return mod(((x * 34.0) + 1.0) * x, 289.0);
}
vec4 taylorInvSqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    //  x0 = x0 - 0. + 0.0 * C
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1. + 3.0 * C.xxx;

    // Permutations
    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(
                    i.z + vec4(0.0, i1.z, i2.z, 1.0))
                    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
                + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // Gradients
    // ( N*N points uniformly over a square, mapped onto an octahedron.)
    float n_ = 1.0 / 7.0; // N=7
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z); //  mod(p,N*N)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_); // mod(j,N)

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    //Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    float n = 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1),
                    dot(p2, x2), dot(p3, x3))); // [-1 ... +1]

    return n;
}

float snoise01(vec3 v) {
    float n = snoise(v);
    return 0.5 * (n + 1.0);
}

void main() {
    vec2 sp = vs_uv;
    sp.x -= 0.5;
    sp.x *= u_aspect;

    float N0 = snoise(vec3(sp, u_time));

    mat3 freqs_mat = mat3(
            1.0, 1.0, 1.0,
            2.0, 2.0, 10.0,
            8.0, 8.0, 30.0
        );
    float spread = pow(sp.y * 3, 4.0) / (1.0 + pow(2.0 * sp.y, 4.0)) - 1.0 * sp.y;
    vec3 ampls = spread * vec3(2.5, 1.0, 0.2);
    vec2 n_trunks = vec2(6.0, 18.0) / 4.5;
    vec2 dither = vec2(500.0, 500.0);

    float base_time = u_time * 0.025;

    float trunks_dt = 10;
    vec2 trunk_idx = mod(floor(sp * dither), n_trunks);
    float trunk_width = 0.04 * trunk_idx.y + 0.02;
    float trunk_smoothness = 0.035;

    float trunk_time = dot(trunk_idx * trunks_dt, vec2(1.0, 1.0));
    float time = base_time + trunk_time;
    vec3 noise_vars = vec3(sp.x, sp.y, time);
    vec3 noise = ampls * vec3(
                snoise(freqs_mat[0] * noise_vars),
                snoise(freqs_mat[1] * noise_vars),
                snoise(freqs_mat[2] * noise_vars)
            );

    float x = abs(sp.x + dot(vec3(1.0 / 3.0), noise));
    float trunk = 1.0 - smoothstep(0.0, trunk_smoothness, x - trunk_width);
    float ground = 1.0 - trunk;
    float brightness = trunk_idx.y * 0.2;
    vec3 trunk_color = mix(vec3(0.6, 1.0, 0.2), vec3(0.5, 0.35, 0.1), 1.0 - sp.y);
    trunk_color.g *= (1.0 + 2.0 * brightness + 2.0 * sp.y);
    trunk_color.r *= (1.0 + 2.0 * brightness + 0.5 * (1.0 - sp.y));

    float c = float(mod(trunk_idx.y, 6.0) == 0);
    trunk_color = trunk_color + c * vec3(0.5) - (1.0 - c) * vec3(0.5);

    vec3 color = trunk * trunk_color;
    fs_color = vec4(color, 1.0);
}
