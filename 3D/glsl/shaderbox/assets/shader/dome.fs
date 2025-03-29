#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

// Ray marching constants
#define RM_MAX_N_STEPS 512
#define RM_MAX_DIST 100.0
#define RM_EPS 0.0001

// -----------------------------------------------------------------------
// Utils
float sin01(float x) {
    return 0.5 * (sin(x) + 1.0);
}

float cos01(float x) {
    return 0.5 * (cos(x) + 1.0);
}

float sin_pulse(float bias, float strength, float freq) {
    return bias + strength * sin01(freq * u_time);
}

vec3 smoothstep3(float e1, float e2, float s, float x) {
    float st1 = smoothstep(e1 - 0.5 * s, e1 + 0.5 * s, x);
    float st2 = smoothstep(e2 - 0.5 * s, e2 + 0.5 * s, x);

    vec3 res = vec3(0.0);
    res.x = 1.0 - st1;
    res.y = st1 - st2;
    res.z = st2;

    return res;
}

// -----------------------------------------------------------------------
// Visual style

// Color quantization, palette, etc
float DERIVATIVE_STEP = 0.015;
float QUANTIZATION_ANGLE = radians(50.0);

// Light and shadows
vec3 LIGHT_POS = vec3(100.0, 100.0, 0.0);
float SHADOW_SOFTNESS = 30.0;

// -----------------------------------------------------------------------
// Camera
struct Camera {
    vec3 ndc;
    vec3 pos;
    vec3 target;
};

vec3 get_ndc() {
    vec2 ndc_xy = vs_uv * 2.0 - 1.0;
    ndc_xy.x *= u_aspect;
    vec3 ndc = vec3(ndc_xy, 1.0);

    return ndc;
}

vec3 get_rd(Camera cam) {
    // --------------------------------
    // Ray direction (rd)

    // Calculate camera basis:
    vec3 forward = normalize(cam.target - cam.pos);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    mat3 to_camera = mat3(right, up, forward);

    // Transform NDC to camera view:
    vec3 rd = to_camera * cam.ndc;

    // Normalize the ray direction:
    rd = normalize(rd);

    return rd;
}

// -----------------------------------------------------------------------
// SDFs
float get_sd_pillar(vec3 p) {
    // modulated time
    float ft = 0.5 * sin01(u_time);

    // radius
    float r = 1.0;
    r *= 1.0 + ft;

    return length(p) - r;
}

float get_sd_ground(vec3 p) {
    return dot(p, vec3(0.0, 1.0, 0.0));
}

// -----------------------------------------------------------------------
// Outline
vec3 add_outline(vec3 base_color, float sd) {
    vec3 outline_color = vec3(
            20.0,
            1.0,
            sin_pulse(
                0.0, // bias
                0.4, // strength
                4.0 // freq
            )
        );

    float width = sin_pulse(
            0.01, // bias
            0.01, // strength
            4.0 // freq
        );

    float a = smoothstep(0.0, width, sd);
    float b = 1.0 - smoothstep(width, 2.0 * width, sd);
    float t = a * b;

    return mix(base_color, outline_color, t);
}

// -----------------------------------------------------------------------
// Ray marching
struct RayMarchResult {
    int i;
    vec3 p;
    vec3 ro;
    vec3 rd;

    float d_total;

    float sd_last;
    float sd_best;
    float sd_best_pillar;
    float sd_best_ground;
};

bool rm_should_finish(RayMarchResult rm) {
    return rm.sd_last < RM_EPS || rm.d_total > RM_MAX_DIST || rm.i == RM_MAX_N_STEPS - 1;
}

RayMarchResult march(Camera cam) {
    vec3 rd = get_rd(cam);

    RayMarchResult rm = RayMarchResult(
            0, // i - current ray march iteration
            cam.pos, // p - last position
            cam.pos, // ro - ray oridin (camera position)
            rd, // rd - ray direction at p
            0.0, // d_total - ray total traveled distance
            0.0, // sd_last - last signed distance
            RM_MAX_DIST, // sd_best - best (smallest) signed distance
            RM_MAX_DIST, // sd_best_pillar - best to pillar
            RM_MAX_DIST // sd_best_ground
        );

    for (; rm.i < RM_MAX_N_STEPS; ++rm.i) {
        rm.p = rm.ro + rm.rd * rm.d_total;

        float sd_step_pillar = get_sd_pillar(rm.p);
        float sd_step_ground = get_sd_ground(rm.p);

        rm.sd_best_pillar = min(rm.sd_best_pillar, sd_step_pillar);
        rm.sd_best_ground = min(rm.sd_best_ground, sd_step_ground);

        rm.sd_last = RM_MAX_DIST;
        rm.sd_last = min(rm.sd_last, sd_step_pillar);
        rm.sd_last = min(rm.sd_last, sd_step_ground);

        rm.sd_best = min(rm.sd_best, rm.sd_last);

        rm.d_total += rm.sd_last;

        if (rm_should_finish(rm)) break;
    }

    return rm;
}

// -----------------------------------------------------------------------
// Normals
vec3 get_normal_pillar(vec3 p) {
    vec2 e = vec2(DERIVATIVE_STEP, 0.0);

    return normalize(vec3(
            get_sd_pillar(p + e.xyy) - get_sd_pillar(p - e.xyy),
            get_sd_pillar(p + e.yxy) - get_sd_pillar(p - e.yxy),
            get_sd_pillar(p + e.yyx) - get_sd_pillar(p - e.yyx)
        ));
}

vec3 quantize_normal(vec3 v, float q) {
    // Convert to spherical coordinates
    float t = atan(v.y, v.x);
    float p = acos(v.z);

    // Quantize the angles
    float qt = round(t / q) * q;
    float qp = round(p / q) * q;

    // Convert back to Cartesian coordinates
    float sp = sin(qp);
    return vec3(
        sp * cos(qt),
        sp * sin(qt),
        cos(qp)
    );
}

vec3 quantize_normal(vec3 v) {
    return quantize_normal(v, QUANTIZATION_ANGLE);
}

float quantize_normal_f(vec3 v, float q) {
    float t = atan(v.y, v.x);
    float p = acos(v.z);

    int qt = int(round(t / q));
    int qp = int(round(p / q));

    int t_clusters = int(2.0 * 3.14159 / q);
    int total_clusters = t_clusters * int(3.14159 / q);

    return float(qt + qp * t_clusters) / float(total_clusters);
}

float quantize_normal_f(vec3 v) {
    return quantize_normal_f(v, QUANTIZATION_ANGLE);
}

// -----------------------------------------------------------------------
// Shadows
float get_shadow(vec3 ro, vec3 rd) {
    float res = 1.0;
    float t = RM_EPS;
    for (int i = 0; i < RM_MAX_N_STEPS && t < RM_MAX_DIST; i++) {
        float h = min(get_sd_pillar(ro + rd * t), get_sd_ground(ro + rd * t));
        if (h < RM_EPS) return 0.0;
        res = min(res, SHADOW_SOFTNESS * h / t);
        t += h;
    }
    return res;
}

// -----------------------------------------------------------------------
// Fog
float get_fog(vec3 ro, vec3 p) {
    const float density = 0.05;
    const float visibility = 500.0;
    const float smoothness = 0.95;

    float f = max(0.0, min(distance(ro, p) / visibility, density));
    f = pow(f, 1.0 - smoothness);
    return f;
}

// -----------------------------------------------------------------------
// Colors
const vec3 palette[8] = vec3[8](
        vec3(0.348, 0.36, 0.1), // Ground
        vec3(0.4, 0.314, 0.369), // Sky
        vec3(1.0, 0.87, 0.275), // Outline
        vec3(0.33, 0.26, 0.086), // Shadow
        vec3(0.902, 0.263, 0.098), // Red
        vec3(0.353, 0.769, 0.102), // Green
        vec3(0.352, 0.263, 0.678), // Blue
        vec3(0.031, 0.263, 0.110) // Dark green
    );

vec3 quantize_color(vec3 color) {
    // Human perception weights
    // https://stackoverflow.com/questions/596216/formula-to-determine-perceived-brightness-of-rgb-color
    vec3 weights = vec3(0.299, 0.587, 0.114);

    float min_dist = 1000000.0;
    vec3 nearest_color = palette[0];

    for (int i = 0; i < 8; i++) {
        vec3 delta = color - palette[i];
        float dist = dot(delta * delta, weights);
        if (dist < min_dist) {
            min_dist = dist;
            nearest_color = palette[i];
        }
    }

    return nearest_color;
}

vec3 get_color_pillar(RayMarchResult rm) {
    vec3 normal = get_normal_pillar(rm.p);

    vec3 normal0 = quantize_normal(normal, radians(100.0));
    vec3 normal1 = quantize_normal(normal, radians(50.0));
    vec3 normal2 = quantize_normal(normal, radians(25.0));
    normal = (normal0 + normal1 + normal2) / 3.0;

    vec3 color = normal * normal * normal * 3.0;
    color = color + vec3(0.1);

    return color;
}

vec3 get_color_ground(RayMarchResult rm) {
    float k = distance(rm.ro, rm.p) / RM_MAX_DIST;
    k = pow(k, 0.8);

    vec3 color = vec3(0.1, 0.6, 0.1);
    color = mix(color, vec3(0.5), k);

    // shadow on the ground
    vec3 light_dir = normalize(LIGHT_POS - rm.p);
    float shadow = get_shadow(rm.p + light_dir * RM_EPS, light_dir);
    color *= mix(0.2, 1.0, shadow);

    return color;
}

vec3 get_color_sky(RayMarchResult rm) {
    vec3 color = vec3(0.1, 0.1, 0.9);
    color = color + 0.7 * (1.0 - normalize(rm.p).y);
    color = color * color;
    return color;
}

vec3 get_color_scene(RayMarchResult rm) {
    const vec3 fog_color = vec3(0.4, 0.3, 0.1);

    vec3 color = vec3(0.0);

    if (rm.sd_best_pillar <= RM_EPS) color = get_color_pillar(rm);
    else if (rm.sd_best_ground <= RM_EPS) color = get_color_ground(rm);
    else color = get_color_sky(rm);

    color = mix(color, fog_color, get_fog(rm.ro, rm.p));
    color = add_outline(color, rm.sd_best_pillar);

    return color;
}

// -----------------------------------------------------------------------
// Let's go
void main() {
    vec3 ndc = get_ndc();
    vec3 cam_pos = vec3(5.0 * sin(0.5 * u_time), 2.0, 5.0 * cos(0.5 * u_time));
    vec3 target = vec3(0.2 * sin(u_time), 1.5 + 0.1 * cos(u_time), 0.0);
    Camera camera = Camera(ndc, cam_pos, target);

    RayMarchResult rm = march(camera);
    vec3 color = get_color_scene(rm);
    // color = quantize_color(color);

    fs_color = vec4(color, 1.0);
}
