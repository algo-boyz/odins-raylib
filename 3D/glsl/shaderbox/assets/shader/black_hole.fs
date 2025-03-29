// -----------------------------------------------------------------------
// black hole simulation using ray marching
// -----------------------------------------------------------------------
#version 330
in vec2 vs_uv;

uniform float u_time;

out vec4 fs_color;

#define EPS 0.001
#define MAX_DIST 200.0
#define MAX_N_STEPS 128

const vec3 HOLE_CENTER = vec3(0.0);
const float HOLE_RADIUS = 2.0;
const float DISK_RADIUS = HOLE_RADIUS * 4.0;
const float SMOOTH_K = 0.8;
const float CAMERA_ROTATION_SPEED = 0.01;

// -----------------------------------------------------------------------
// Simplex 3D Noise
// source: https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
// NOTE: Not needed for the actual black hole simulation, I just draw the space with it
vec4 permute(vec4 x) {
    return mod(((x * 34.0) + 1.0) * x, 289.0);
}

vec4 taylor_inv_sqrt(vec4 r) {
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

    // x0 = x0 - 0. + 0.0 * C
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1.0 + 3.0 * C.xxx;

    // Permutations
    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(
                    i.z + vec4(0.0, i1.z, i2.z, 1.0))
                    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
                + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // Gradients
    float n_ = 1.0 / 7.0; // N=7
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z); // mod(p, N*N)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_); // mod(j, N)

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

    // Normalize gradients
    vec4 norm = taylor_inv_sqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    float n = 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1),
                    dot(p2, x2), dot(p3, x3)));

    n = 0.5 * (n + 1.0);

    return n;
}

// -----------------------------------------------------------------------
// Signed distances
float sd_sphere(vec3 p) {
    return length(HOLE_CENTER - p) - HOLE_RADIUS;
}

float sd_disk(vec3 p) {
    float radius = DISK_RADIUS;
    float thickness = 0.001;

    // Project point onto the disk plane (assuming disk is on XZ plane)
    vec2 q = vec2(length(p.xz), p.y);

    // Calculate distances
    vec2 d = abs(q) - vec2(radius, thickness * 0.5);
    float radial_dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);

    // Check if we're beyond the radius
    radial_dist = max(radial_dist, q.x - radius);

    return radial_dist;
}

float smooth_min(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// -----------------------------------------------------------------------
// Color Functions
vec3 get_space_color(vec3 rd) {
    vec3 color = vec3(0.0);

    // Stars
    float n = snoise(rd * 80.0);
    n = pow(n, 80.0) * 50.0;
    color += vec3(n);

    // Nebula 1
    n = snoise(rd * 1.0);
    color += 0.15 * vec3(n, 0.0, n);

    // Nebula 2
    n = snoise(rd * 2.0);
    color += 0.1 * vec3(0.0, n, 0.0);

    // Nebula 3
    n = snoise(rd * 4.0);
    n = pow(n, 2.0);
    color += 0.05 * vec3(0.0, n, n);

    return color;
}

vec3 get_disk_color(vec3 p) {
    float n = length(p) / DISK_RADIUS;
    float k = fract(n * (4.0 + (sin(u_time) + 1.0) / 4.0));
    k = pow(k, 8.0);
    return vec3(k * 18.0, k, 0.0);
}

// -----------------------------------------------------------------------
// Camera

// Ray origin (i.e camera position)
vec3 get_ro(float time, float camera_distance, float camera_height) {
    float angle = time * CAMERA_ROTATION_SPEED;
    float x = camera_distance * cos(angle);
    float z = camera_distance * sin(angle);
    return vec3(x, camera_height, z);
}

// Ray direction (i.e view ray)
vec3 get_rd(vec2 uv, vec3 ro) {
    vec3 look_at = HOLE_CENTER;
    vec3 forward = normalize(look_at - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    vec3 rd = normalize(uv.x * right + uv.y * up + forward);

    return rd;
}

// -----------------------------------------------------------------------
// Let's go
void main() {
    // Normalize UV coordinates
    vec2 uv = vs_uv * 2.0 - 1.0;

    // Add some periodic movement to make image less static
    float hole_strength = 0.9 + 0.1 * sin(0.15 * u_time);
    float camera_distance = 20.0 + 5.0 * sin(0.08 * u_time);
    float camera_height = 0.5 + 4.0 * (sin(0.12 * u_time) + 1.0) / 2.0;

    // Camera
    vec3 ro = get_ro(u_time, camera_distance, camera_height);
    vec3 rd = get_rd(uv, ro);

    // Ray marching loop
    vec3 color = vec3(0.0);
    vec3 p = ro;

    for (int i = 0; i < MAX_N_STEPS; ++i) {
        float sphere_dist = sd_sphere(p);
        float disk_dist = sd_disk(p);
        float d = smooth_min(sphere_dist, disk_dist, SMOOTH_K);

        // Detect the hit and get the color, depending on what we did hit
        if (d < EPS) {
            if (disk_dist < sphere_dist) color = get_disk_color(p);
            break;
        } else if (d >= MAX_DIST || i == MAX_N_STEPS - 1) {
            color = get_space_color(rd);
            break;
        }

        // Bend the view ray (black hole gravity)
        // NOTE: I'm not sure that this is physically correct way to bend the view ray, but it's more or less working and it's simple
        vec3 to_center = HOLE_CENTER - p;
        float dist_to_center = length(to_center);
        to_center = normalize(to_center);

        vec3 bend = to_center;
        rd += hole_strength * (1.0 / dist_to_center) * bend;
        p += rd * d;
    }

    fs_color = vec4(color, 1.0);
}
