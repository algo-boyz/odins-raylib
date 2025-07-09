#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
out vec4 fs_color;
#define PI 3.141592

struct RayMarchResult {
    int i;
    vec3 p;
    vec3 n;
    vec3 ro;
    vec3 rd;
    float dist;
    float sd_last;
    float sd_min;
    float sd_min_shape;
};

float get_sd_shape(vec3 p) {
    float d = length(max(abs(p) - 1.0, 0.0)) - 0.2;
    return d;
}

#define RM_MAX_DIST 10000.0
#define RM_MAX_N_STEPS 64
#define RM_EPS 0.0001
#define NORMAL_DERIVATIVE_STEP 0.015
RayMarchResult march(vec3 ro, vec3 rd) { // Signed distances
    RayMarchResult rm = RayMarchResult(
            0, // i - ray march last iteration index
            ro, // p - ray's last position
            vec3(0.0), // n - normal, will be 0-vec if the ray hits nothing
            ro, // ro - ray origin, i.e camera position (doesn't change)
            rd, // rd - ray direction at very beginning (doesn't change)
            0.0, // dist - ray total traveled distance
            0.0, // sd_last - min sd only on the last step
            RM_MAX_DIST, // sd_min - min sd ever seen
            RM_MAX_DIST // sd_min_shape - min sd to the shape ever seen
        );
    for (; rm.i < RM_MAX_N_STEPS; ++rm.i) {
        rm.p = rm.p + rm.rd * rm.sd_last;

        float sd_step_shape = get_sd_shape(rm.p);

        rm.sd_last = sd_step_shape;
        rm.sd_min_shape = min(rm.sd_min_shape, sd_step_shape);
        rm.sd_min = min(rm.sd_min, sd_step_shape);

        rm.dist += length(rm.p - rm.ro);

        if (rm.sd_last < RM_EPS || rm.dist > RM_MAX_DIST) {
            if (rm.sd_last < RM_EPS) {
                rm.n = vec3(1.0);
            }
            break;
        }
    }
    // Normals
    if (rm.sd_last < RM_EPS) {
        float h = RM_EPS;
        vec3 eps = vec3(h, 0.0, 0.0);
        rm.n = vec3(0.0);

        if (rm.sd_last == rm.sd_min_shape) {
            vec2 e = vec2(NORMAL_DERIVATIVE_STEP, 0.0);
            rm.n = normalize(vec3(
                        get_sd_shape(rm.p + e.xyy) - get_sd_shape(rm.p - e.xyy),
                        get_sd_shape(rm.p + e.yxy) - get_sd_shape(rm.p - e.yxy),
                        get_sd_shape(rm.p + e.yyx) - get_sd_shape(rm.p - e.yyx)
                    ));
        }
    }
    return rm;
}

float sin01(float x, float a, float f, float phase) {
    return a * 0.5 * (sin(PI * f * (x + phase)) + 1.0);
}

float attenuate(float d, vec3 coeffs) {
    return 1.0 / (coeffs.x + coeffs.y * d + coeffs.z * d * d);
}

void main() {
    // Point on the screen x, y in [-1, 1], z == 0.0
    vec2 screen_pos = vs_uv * 2.0 - 1.0;
    screen_pos.x *= u_aspect; // Correct for aspect ratio

    // Camera setup
    float fov = radians(70.0);
    float screen_dist = 1.0 / tan(0.5 * fov);
    vec3 cam_pos = vec3(5.0, 5.0, 5.0);
    vec3 look_at = vec3(0.0, 0.0, 0.0);

    // Calculate camera basis vectors
    vec3 forward = normalize(look_at - cam_pos);
    vec3 world_up = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(forward, world_up));
    vec3 up = normalize(cross(right, forward));

    RayMarchResult rm; {
        // Perspective
        vec3 screen_center = cam_pos + forward * screen_dist;
        vec3 sp = screen_center +
                right * screen_pos.x +
                up * screen_pos.y;

        vec3 ro0 = cam_pos;
        vec3 rd0 = normalize(sp - cam_pos);
        // Orthographic
        vec3 ro1 = sp * 4.0;
        vec3 rd1 = normalize(look_at - cam_pos);
        // Mix
        vec3 ro = mix(ro0, ro1, 1.0);
        vec3 rd = mix(rd0, rd1, 1.0);
        rm = march(ro, rd);
    }
    // Color
    vec3 color = vec3(0.0);
    float d = abs(max(0.0, rm.sd_min_shape));
    float a = attenuate(d, vec3(0.01, 8.0, 8.0));
    color = 1.0 * abs(rm.n);
    fs_color = vec4(color, 1.0);
}
