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

    // n = 0.5 * (n + 1.0); // [0 ... +1]

    return n;
}

float snoise01(vec3 v) {
    float n = snoise(v);
    return 0.5 * (n + 1.0);
}

void main() {
    vec3 color = vec3(0.0);

    // -------------------------------------------------------------------
    // Space
    vec2 sp;
    float a;
    float r;
    float aw;

    {
        float aspect = u_aspect;
        float zoomout = 1.5;

        // Cartesian coordinates
        sp = (vs_uv * 2.0) - 1.0;
        sp.x *= aspect;
        sp *= zoomout;

        // Polar coordinates
        r = length(sp);
        a = 0.5 * (atan(sp.y, sp.x) / PI + 1.0);
        aw = 2.0 * abs(a - 0.5); // [1.0 -> 0.0 -> 1.0]
    }

    // Entropy sources
    float n0;
    float n1;
    float n2;
    vec2 sp1;
    {
        float t = u_time;

        n1 = snoise(vec3(sp.x - t, 0.0, 0.0));
        n1 *= 0.5;

        // Transform space
        sp1 = sp - 0.1 * n1;
        n2 = snoise(vec3(0.0, 20 * sp1.x, 20 * sp1.y));
        n0 = snoise(vec3(0.0, 50 * sp1.x - 0.4 * n1, 50 * sp1.y - 0.4 * n1));
    }

    // -------------------------------------------------------------------
    // Shapes and signed distances
    float sd;
    float shape_idx;

    {
        float sd_square = 1.0 - max(abs(sp1.x), abs(sp1.y));
        float sd_circle = length(sp1) - 1.0;

        sd = sd_square;
        sd = min(sd, sd_circle);

        shape_idx = float(sd == sd_square);
    }

    // -------------------------------------------------------------------
    // Drawing

    // Line
    vec3 line_color;

    {
        vec3 color = mix(vec3(0.8, 1.0, 0.8), vec3(1.0, 0.8, 0.8), shape_idx);
        color *= (1.0 + sign(n0) * pow(abs(n0), 2.0));

        float line_width = 0.025 + 0.005 * n0 + 0.005 * n1;
        float line_smoothness = 0.025;
        float line = 1.0 - smoothstep(0.0, line_smoothness, abs(sd) - line_width);

        line_color = color * line;
    }

    // Fabric
    vec3 fabric_color;

    {
        float max_sp = max(abs(sp1.x), abs(sp1.y));
        float fabric = 1.0 - smoothstep(0.0, 0.05, abs(sp1.y) - 1.3);

        float n2_01 = 0.5 * (n2 + 1.0);
        float frame = fabric;
        frame *=
            (n2_01) * snoise01(vec3(36.0 * sp1.y, 0.0, 0.0))
                + (1.0 - n2_01) * snoise01(vec3(36.0 * sp1.x, 0.0, 0.0));
        frame = pow(frame, 8.0);

        vec3 color = 0.5 * vec3(1.0, 0.5, 1.0);
        color *= (1.0 + 0.05 * sign(n2) * pow(abs(n2), 0.5));
        color *= (1.0 + 0.10 * sign(n0) * pow(abs(n0), 0.5));
        color *= (1.0 + 0.20 * sign(n1) * pow(abs(n1), 0.8));

        fabric_color = fabric * color + frame * color;
    }

    // Lighting
    vec3 light_color;

    {
        vec3 color = 0.25 * vec3(1.0, 0.9, 0.8);
        color *= (1.0 + 1.0 * pow(1.0 + n1, 2.0));

        light_color = color;
    }

    color = (line_color + fabric_color) * light_color;
    fs_color = vec4(color, 1.0);
}
