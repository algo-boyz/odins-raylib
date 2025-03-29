#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define PI 3.141592

//	Simplex 3D Noise
//	by Ian McEwan, Stefan Gustavson (https://github.com/stegu/webgl-noise)
//
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

    n = 0.5 * (n + 1.0); // [0 ... +1]

    return n;
}

void main() {
    float time = u_time;
    time = time * 0.2 + 2.0 * length(vs_uv);

    vec2 uv = vs_uv;

    vec2 sp = (uv * 2.0) - 1.0;
    float zoomout = 1.5;
    sp = sp * zoomout;
    sp.x *= u_aspect;

    float r = length(sp);
    float a = (atan(sp.y, sp.x) / PI + 1.0) * 0.5;
    int rgb_idx = int(floor(a * 3.0));

    float k = 2.0;
    float k_gain = 2.0;

    float low_freq = 0.08 * sin(k * a * pow(k_gain, 0.0) * PI + 1.0 * time);
    float mid_freq = 0.04 * sin(k * a * pow(k_gain, 1.0) * PI + 1.0 * time)
            + 0.002 * sin(16.0 * a * pow(k_gain, 2.0) * PI + 2.0 * time);
    float high_freq = 0.001 * sin(10.0 * a * pow(k_gain, 3.0) * PI + 16.0 * time);

    r = 0.6 + low_freq + mid_freq + high_freq;

    float beat = abs(sin(8 * time));
    r = r + pow(abs(0.55 * pow(beat, 8.0)), 4.0) * sin(8.0 * abs((a - 0.5) * 2));

    float a_ = (a * 2 * PI) - PI;
    vec2 sp_1 = vec2(r * cos(a_), r * sin(a_));

    float brightness = 2.5 * (sin(8.0 * time) + 1.0) + 1.0;
    float d = distance(sp, sp_1);
    d = brightness / (1.0 + 30.0 * d + 15.0 * d * d);

    vec3 color = vec3(
            1.0,
            0.1 * d,
            100.0 * high_freq - 10.0 * low_freq
        ) * (sin(4.0 * time) + 1.0 * abs(a - 0.5));
    color = color * d;

    float N0;
    {
        float n0 = 0.70 * snoise(vec3(sp, 0.0));
        float n1 = 0.30 * snoise(vec3(sp * 2.0, 0.0));
        float n3 =
            (0.05 + 0.01 * pow((sin(time * 3) + 1.0) * 0.5 * 1.5, 4)) // ampl *
                * snoise(vec3(sp * 8.0, 0.0) + time); // noise in [0 .. 1]

        N0 = n0 + n1 + n3;
    }

    float N1;
    {
        float n0 = 1.0 * snoise(vec3(sp.x + 0.25 * time, sp.y + 4.0 * time, time));

        N1 = n0;
    }

    float N2;
    {
        float x = sp.x + time;
        float y = sp.y + 0.5 * x;
        float n0 = 1.0 * snoise(4.0 * vec3(x + time, y + time, beat) * (1.0 + 4.0 * a));

        N2 = n0;
    }

    color = (color + vec3(0.2, 0.05, 1.0) * pow(abs((0.25 + 0.2 * sin(time) * (0.25 + r)) * N0), 0.5)) * 0.3 * N1;
    color = color * (1.0 + 0.4 * beat * N2);

    // fog
    vec2 uv_ = 2.0 * (uv - 0.5);
    float fog = max(abs(uv_.x), abs(uv_.y));
    fog = 1.0 / (1.0 + 0.1 * fog + 0.0 * fog * fog);
    fog = 1.0 - fog;
    fog = pow(fog * 6.0, 4.0);

    color = color + fog;

    color = pow(color, vec3(mix(0.6, 1.0, 0.5 * (sin(time * 4) + 1.0))));

    // tiling
    {
        float n = snoise(vec3(sp.x, sp.y, 0.0));
        float tiling = 1.0 + 1.5 * n * length(color);

        vec2 tile_id = floor(sp * tiling);
        vec2 tile_uv = fract(sp * tiling);
        vec2 tile_sp = tile_uv * 2.0 - 1.0;

        float d = min(abs(tile_sp.x), abs(tile_sp.y));
        float line_width = 0.025;
        float line_smoothness = line_width * 0.25;
        d = 1.0 - smoothstep(0.0, line_smoothness, d - line_width);

        color = color * (1.0 + 0.5 * vec3(d));
    }

    // high freq details
    {
        float n = snoise(8 * vec3(sp.x + time, sp.y + time, 0.0));
        n = pow(n, 8.0);

        color = color * (1.0 + n);
    }

    fs_color = vec4(color, 1.0);
}
