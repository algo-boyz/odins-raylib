#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

float SEED = 0.0 * u_time;

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
    v += SEED;
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

float hash(float p) {
    vec2 p2 = fract(vec2(p) * vec2(0.1031, 0.1030));
    p2 += dot(p2, p2.yx + 33.33);
    return fract((p2.x + p2.y) * p2.x);
}

void main() {
    float RANDOMNESS = 1.0;
    float TIME = 0.25 * u_time;

    vec3 color;

    // -------------------------------------------------------------------
    // screen_p - point on the screen, centered by x
    vec2 screen_p;
    {
        vec2 screen_uv = vs_uv;
        screen_p = vec2(u_aspect * 2.0 * (screen_uv.x - 0.5), screen_uv.y);
    }

    // -------------------------------------------------------------------
    // stripe_uv - screen vertical stripes UVs
    float zoomout = 5.0;

    vec2 stripe_uv;
    float building_idx; // index of this vertical stripe
    {
        screen_p *= zoomout;
        float x = screen_p.x * 0.5;
        building_idx = floor(x);
        stripe_uv = vec2(fract(x), screen_p.y);
    }

    // -------------------------------------------------------------------
    // building
    float building_stretch = 2.0;
    float building_base_height = 3.0;
    float building_roof_quant = 15.0;
    float building_roof_freq = 1.0;
    float building_smooth_y = 0.05;

    vec2 building_sp;
    float building_mask;
    float building_height;
    vec3 building_color;
    {
        float k = hash(building_idx);
        float quant = building_roof_quant * (0.000001 + k);
        building_height = building_base_height + building_stretch * snoise(vec3(building_roof_freq * floor(stripe_uv.x * quant) / quant, 0.0, building_idx));

        building_sp = vec2(stripe_uv.x, fract(stripe_uv.y + (1.0 - building_height)) - (1.0 - building_height));
        building_sp.x = building_sp.x * 2.0 - 1.0;

        // building_mask = 1.0 - step(building_height, stripe_uv.y);
        building_mask = 1.0 - smoothstep(building_height, building_height + building_smooth_y, stripe_uv.y);
        building_sp.xy = building_mask * building_sp.xy;

        float building = 0.05 + hash(building_idx * 0.1) * 0.1 * snoise(vec3(screen_p.x * 2, 80 * screen_p.y, building_idx));
        building = pow(building * 6.0 + 0.2 * snoise01(vec3(building_idx, screen_p.y, TIME + building_idx + screen_p.y)), 8.0);
        building = clamp(building, 0.0, 1.0);
        building_color = vec3(building);
        building_color *= building_mask;
    }

    // -------------------------------------------------------------------
    // floor
    float floors_base_density = 15.0;

    float n_floors;
    vec2 floor_sp;
    float floor_idx;
    {
        float floors_density = floors_base_density + RANDOMNESS * 0.5 * floors_base_density * snoise(vec3(0.0, 0.0, building_idx));
        floors_density = clamp(floors_density, 1.0, floors_density);
        n_floors = building_height * floors_density;

        floor_sp = building_sp;
        floor_sp.y = fract(floor_sp.y * floors_density) * 2.0 - 1.0;

        floor_idx = floor(building_sp.y * floors_density);
    }

    // -------------------------------------------------------------------
    // room
    float n_rooms_base = 16.0;

    vec2 room_sp;
    float room_idx;
    float n_rooms;
    {
        n_rooms = n_rooms_base + RANDOMNESS * 0.5 * n_rooms_base * snoise(vec3(building_idx, 0.0, 0.0));
        room_sp.y = floor_sp.y;
        room_sp.x = fract(floor_sp.x * n_rooms * 0.5) * 2.0 - 1.0;

        room_idx = floor(floor_sp.x * n_rooms * 0.5);
    }

    // -------------------------------------------------------------------
    // window
    float window_aspect = 1.2;
    float window_base_size = 0.5;
    float window_smoothness = 0.5;

    float window;
    float window_size;
    float window_brightness;
    vec3 window_tint;
    vec3 window_color;
    {
        window_size = window_base_size + RANDOMNESS * 0.5 * window_base_size * pow(snoise01(vec3(building_idx, 0.1 * floor_idx, 0.0)), 4.0);

        window_brightness = snoise01(vec3(building_idx, floor_idx * 0.3, room_idx * 0.3) + TIME * vec3(0.1, 0.0, 0.1));
        window_brightness = pow(1.3 * window_brightness, 8.0);
        window_brightness *= building_mask;

        float d = max(2.0 * abs(room_sp.y - 0.5) * window_aspect, abs(room_sp.x));
        window = smoothstep(window_size + window_smoothness, window_size, d);
        window *= building_mask;

        vec3 window_tint_0 = mix(
                vec3(1.0, 0.8, 0.8),
                vec3(0.7, 0.8, 0.6),
                snoise01(vec3(building_idx, floor_idx, room_idx))
            );
        vec3 window_tint_1 = mix(
                vec3(0.6, 0.4, 0.6),
                vec3(0.6, 0.4, 0.6),
                snoise01(vec3(building_idx, floor_idx, room_idx) + 17)
            );

        float k = snoise01(vec3(building_idx, floor_idx * 0.5, room_idx * 0.5) + 33);
        k = pow(abs(k - 0.5) * 4.0, 5.0);
        k = clamp(k, 0.0, 1.0);

        vec3 window_tint = mix(
                window_tint_0,
                window_tint_1,
                k
            );
        window_color = window * window_brightness * window_tint;
    }

    // -------------------------------------------------------------------
    // floor color
    float floor_base_brightness = 0.3;

    vec3 floor_color;
    {
        float floor_brightness = snoise01(vec3(building_idx, floor_idx, room_idx));
        floor_brightness = floor_base_brightness * pow(floor_brightness, 8.0);

        float line = abs(floor_sp.y - 0.5) * 2.0;
        line = 1 - smoothstep(window_size, window_size + 0.5, abs(line));
        floor_color = vec3(line * floor_brightness * building_mask);

        floor_color *= building_mask;
    }

    // -------------------------------------------------------------------
    // sky color
    vec3 sky_color;
    {
        float noise = snoise01(vec3(15 * vs_uv.y, 2 * vs_uv.x, 0.02 * TIME));

        vec3 horizon_color = vec3(0.98, 0.45, 0.15);
        vec3 mid_color = vec3(0.85, 0.35, 0.55);
        vec3 zenith_color = vec3(0.15, 0.25, 0.45);

        float mid_point = 0.3;

        vec3 lower_mix = mix(horizon_color, mid_color, smoothstep(0.0, mid_point, vs_uv.y));
        vec3 upper_mix = mix(mid_color, zenith_color, smoothstep(mid_point, 1.0, vs_uv.y));

        sky_color = mix(lower_mix, upper_mix, step(mid_point, vs_uv.y));
        sky_color = mix(sky_color, sky_color * 0.95, noise) * (1 - building_mask);
    }

    // -------------------------------------------------------------------
    color = window_color + sky_color + building_color;
    color += (1.0 - (window * window_brightness)) * floor_color;

    // color = vec3(screen_p, 0.0);
    fs_color = vec4(color, 1.0);
}
