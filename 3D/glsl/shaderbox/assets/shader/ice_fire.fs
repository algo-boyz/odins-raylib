#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define PI 3.14159

// -----------------------------------------------------------------------
// Simplex Noise
// by Ian McEwan, Stefan Gustavson
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

    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;

    // Permutations
    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(
                    i.z + vec4(0.0, i1.z, i2.z, 1.0))
                    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
                + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // Gradients
    float n_ = 1.0 / 7.0;
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

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

    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;

    float n = 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
    n = (n + 1.0) * 0.5;
    return n;
}

vec3 rotate3D(vec3 p, vec3 angle) {
    float sx = sin(angle.x);
    float cx = cos(angle.x);
    float sy = sin(angle.y);
    float cy = cos(angle.y);
    float sz = sin(angle.z);
    float cz = cos(angle.z);

    vec3 qx = vec3(p.x, p.y * cx - p.z * sx, p.y * sx + p.z * cx);
    vec3 qy = vec3(qx.x * cy + qx.z * sy, qx.y, -qx.x * sy + qx.z * cy);
    vec3 qz = vec3(qy.x * cz - qy.y * sz, qy.x * sz + qy.y * cz, qy.z);

    return qz;
}

float octave_noise(
    vec3 p,
    int n_octaves,
    float freq_multiplier,
    float ampl_multiplier,
    bool normalise
) {
    float freq = 1.0;
    float ampl = 1.0;
    float sum = 0.0;
    float weight_sum = 0.0;

    for (int i = 0; i < n_octaves; ++i) {
        sum += ampl * snoise(p * freq);
        weight_sum += ampl;

        freq *= freq_multiplier;
        ampl *= ampl_multiplier;
    }

    return normalise ? sum / weight_sum : sum;
}

void main() {
    vec2 sp = vs_uv * 2.0 - 1.0;
    sp *= 1.5;
    float r = length(sp);

    sp.x *= u_aspect;
    vec2 orig_sp = sp;

    float n = octave_noise(vec3(sp, 0.0), 2, 2.0, 0.5, true);
    float a = 0.5 * (atan(sp.y, sp.x) / PI + 1.0);
    float orig_a = a;

    float spiral = min(0.1, r) / (1.0 + 4.0 * r);
    spiral = pow(10.0 * spiral, 8.0);
    r = r + r * spiral * sin(PI * 10.0 * a + 100.0 * r);

    a = 0.5 * pow(n, 1.0);

    a = (a * 2.0 * PI) - PI;
    sp = vec2(r * cos(a), r * sin(a));

    float blurry_ground = octave_noise(vec3(sp, u_time * 0.1), 2, 6.0, 1.0 / 2.0, true);
    float isoline = 0.5;
    float thickness = 0.015;
    float outside = 1.0 - smoothstep(isoline - 0.5 * thickness, isoline + 0.1 - 0.5 * thickness, blurry_ground);
    float inside = smoothstep(isoline + 0.5 * thickness, isoline + 0.5 * thickness + 0.1, blurry_ground);
    float outline = 1.0 - (outside + inside);
    float ambient = clamp(0.8 + 1.0 - smoothstep(0.5, 0.525, blurry_ground), 0.0, 1.0);

    float static_noise = octave_noise(vec3(sp, u_time * 0.05), 8, 80.0, 1.0 / 2.0, true);
    static_noise = 1.0 - 0.1 * smoothstep(0.4, 0.6, static_noise);

    float detailed_ground = octave_noise(vec3(sp, u_time * 0.05), 8, 8.0, 1.0 / 2.0, true);

    float light = 0.1 * ambient + 8.0 * pow(detailed_ground, 8.0);
    light = 10.0 * light / (1.0 + (1.0 * r) + (3.0 * r * r));

    float darkness_noise = 1.0 - octave_noise(vec3(sp, u_time * 0.05), 4, 80.0, 1.0 / 2.0, true);

    float snow = octave_noise(
            vec3(sp.x, sp.y, 1.0),
            2,
            8.0,
            1.0 / 8.0,
            false
        );
    snow = 1.0 - smoothstep(0.1, 0.5, snow);
    snow = pow(1.1 * snow, 8.0);
    snow = pow(snow, 1.0 + 4.0 * pow(sin(4.0 * u_time), 2.0) * 0.5 * (sin(2.0 * u_time) + 1.0));

    vec3 light_near_color = vec3(1.0, 0.4, 0.0);
    vec3 light_far_color = vec3(0.0, 0.2, 1.0);
    vec3 light_color = r * light_far_color + (1.0 - r) * light_near_color;
    light_color = pow(light_color, vec3(4.0));

    vec3 color = light_color * light * detailed_ground + light_near_color * snow;
    color += 0.2 * darkness_noise * (1.0 - light);
    color *= static_noise;
    color += 0.005 * vec3(1.0, 0.5, 0.3) * outline / pow(r, 2.0);

    fs_color = vec4(vec3(color), 1.0);
}
