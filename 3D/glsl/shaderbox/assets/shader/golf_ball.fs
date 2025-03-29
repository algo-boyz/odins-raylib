#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define PI 3.1415

// Ray marching constants
#define RM_MAX_N_STEPS 512
#define RM_MAX_DIST 1000000.0
#define RM_EPS 0.0001

// Visuals
#define AO_STRENGTH 0.12

const vec3 GROUND_COLOR = vec3(0.0, 0.2, 0.0);

// -----------------------------------------------------------------------
// Utils
float min3(float x1, float x2, float x3) {
    return min(min(x1, x2), x3);
}

vec3 quantize_vector_angle(vec3 v, float q) {
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
    vec3 z = normalize(cam.target - cam.pos);
    vec3 x = normalize(cross(vec3(0.0, 1.0, 0.0), z));
    vec3 y = cross(z, x);
    mat3 to_camera = mat3(-x, y, z);

    // Transform NDC to camera view:
    vec3 rd = to_camera * cam.ndc;

    // Normalize the ray direction:
    rd = normalize(rd);

    return rd;
}

// -----------------------------------------------------------------------
// SDFs
float get_sd_shape(vec3 p) {
    p.y -= 2.0;

    float r = 2.0;
    float sd = length(p) - r;

    return sd;
}

float get_sd_ground(vec3 p) {
    return p.y;
}

// -----------------------------------------------------------------------
// Ray marching
struct RayMarchResult {
    // NOTE: These fields are the last ones which were recorded during ray marching,
    // so they may change. For example, the final rd may differ from the starting one,
    // for example - near a black hole!

    int i;
    vec3 p; // position
    vec3 n; // normal
    vec3 ro; // ray origin (camera position)
    vec3 rd; // ray direction

    float dist;

    float sd_last;
    float sd_min;

    float sd_min_shape;
    float sd_min_ground;
};

RayMarchResult march(vec3 ro, vec3 rd) {
    // -------------------------------------------------------------------
    // Signed distances
    RayMarchResult rm = RayMarchResult(
            0, // i - current ray march iteration
            ro, // p - last position
            vec3(1.0), // n - normal
            ro, // ro - ray origin (camera position)
            rd, // rd - ray direction at p
            0.0, // dist - ray total traveled distance
            0.0, // sd_last - last signed distance
            RM_MAX_DIST, // sd_min - min signed distance to any object
            RM_MAX_DIST, // sd_min_shape - min signed distance to shape
            RM_MAX_DIST // sd_min_ground - min signed distance to ground
        );

    for (; rm.i < RM_MAX_N_STEPS; ++rm.i) {
        rm.p = rm.ro + rm.rd * rm.dist;

        float sd_step_shape = get_sd_shape(rm.p);
        float sd_step_ground = get_sd_ground(rm.p);

        rm.sd_min_shape = min(rm.sd_min_shape, sd_step_shape);
        rm.sd_min_ground = min(rm.sd_min_ground, sd_step_ground);

        rm.sd_last = RM_MAX_DIST;
        rm.sd_last = min(rm.sd_last, sd_step_shape);
        rm.sd_last = min(rm.sd_last, sd_step_ground);

        rm.sd_min = min(rm.sd_min, rm.sd_last);

        rm.dist += rm.sd_last;

        if (rm.sd_last < RM_EPS || rm.dist > RM_MAX_DIST) {
            break;
        }
    }

    // -------------------------------------------------------------------
    // Normals
    if (rm.sd_last < RM_EPS) {
        if (rm.sd_min == rm.sd_min_ground) {
            // For the ground plane, we know the normal is always (0,1,0)
            rm.n = vec3(0.0, 1.0, 0.0);
        } else {
            // For other shapes, use the numerical approximation
            float h = RM_EPS;
            vec3 eps = vec3(h, 0.0, 0.0);
            rm.n = normalize(vec3(
                        get_sd_shape(rm.p + eps.xyy) - get_sd_shape(rm.p - eps.xyy),
                        get_sd_shape(rm.p + eps.yxy) - get_sd_shape(rm.p - eps.yxy),
                        get_sd_shape(rm.p + eps.yyx) - get_sd_shape(rm.p - eps.yyx)
                    ));
        }
    }

    return rm;
}

// -----------------------------------------------------------------------
// Shadow, Lights & Materials :-|)~~--??
struct Light {
    vec3 direction;
    vec3 color;

    float ambient;
    float softness;
};

float get_shadow(RayMarchResult rm, Light light, float ao_strength) {
    // Direction towards the light source
    vec3 rd = normalize(-light.direction);

    // Start slightly above the surface to avoid self-shadowing
    vec3 ro = rm.p + rm.n * 0.001;

    // Initial distance along the shadow ray
    float dist = 0.0;

    // Start fully lit (1.0) and decrease as we find occlusions
    float shadow = 1.0;

    // Previous height, initialized to a large value
    float ph = 1e10;

    // Iterate to refine shadow (more iterations = more accurate but slower)
    for (int i = 0; i < 32; i++) {
        // Current point along the shadow ray
        vec3 p = ro + rd * dist;

        // Distance to the nearest object from the current point
        float h = get_sd_shape(p);

        // If we're very close to an object, it's fully shadowed
        if (h < RM_EPS) {
            shadow = 0.0;
            break;
        }

        // Estimate the "thickness" of the penumbra
        float y = h * h / (2.0 * ph);

        // Calculate the perpendicular distance to the shadow-casting object
        float d = sqrt(h * h - y * y);

        // Update the shadow value based on the perpendicular distance
        // This creates a smooth transition from full shadow to full light
        shadow = min(shadow, d / (light.softness * max(0.0, dist - y)));

        // Store the current height for the next iteration
        ph = h;

        // Advance along the shadow ray
        // We move faster when far from objects and slower when close
        dist += clamp(h, 0.01, 0.2);

        // Stop if we've gone too far without hitting anything
        if (dist > 20.0) break;
    }

    // Ensure shadow value is between 0 and 1
    shadow = clamp(shadow, 0.0, 1.0);

    // Calculate ambient occlusion
    float ao = 0.0;
    float step = 0.1;
    for (int i = 1; i <= 5; i++) {
        float dist = step * float(i);
        vec3 p = rm.p + rm.n * dist;
        float sd = min(get_sd_shape(p), get_sd_ground(p));
        ao += max(0.0, dist - sd) / dist;
    }
    ao = 1.0 - ao * ao_strength;

    // Combine shadow and ambient occlusion
    shadow = min(shadow, ao);

    return 1.0 - shadow;
}

vec3 get_color_sky(RayMarchResult rm, Light light) {
    return vec3(0.25, 0.4, 0.7);
}

vec3 get_color_ground(RayMarchResult rm, Light light, float shadow) {
    vec3 ambient = light.ambient * light.color * GROUND_COLOR;
    vec3 direct = light.color * GROUND_COLOR * (1.0 - shadow);

    return ambient + direct;
}

struct Material {
    vec3 base_color;

    float diffuse;
    float specular;
    float shininess;
};

vec3 get_color_shape(
    RayMarchResult rm,
    Light light,
    Material material,
    float shadow
) {
    vec3 normal = rm.n;
    vec3 view_dir = normalize(rm.ro - rm.p);

    // Ambient
    vec3 ambient = light.ambient * light.color * material.base_color;

    // Diffuse
    vec3 diffuse = material.diffuse * light.color * material.base_color * max(dot(normal, -light.direction), 0.0);

    // Specular
    vec3 reflect_dir = reflect(light.direction, normal);
    vec3 specular = material.specular * light.color * pow(max(dot(view_dir, reflect_dir), 0.0), max(material.shininess, 1.0));

    // Apply shadow to direct lighting (diffuse and specular)
    vec3 direct = (diffuse + specular) * (1.0 - shadow);

    // Add ambient to the final color
    return ambient + direct;
}

vec3 get_corrected_color(vec3 color) {
    // Brightness
    color *= 1.1;

    // Contrast
    color = pow(color, vec3(1.2));

    // Saturation
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luminance), color, 1.2);

    // Gamma correction
    float gamma = 2.2;
    color = pow(color, vec3(1.0 / gamma));

    // Ensure color values are in the valid range [0, 1]
    return clamp(color, 0.0, 1.0);
}

vec3 get_color_scene(Camera camera, Light light, Material material) {
    vec3 ro = camera.pos;
    vec3 rd = get_rd(camera);

    // Primary color
    RayMarchResult rm = march(ro, rd);
    vec3 color = vec3(0.0);

    float shadow = get_shadow(rm, light, AO_STRENGTH);

    if (rm.sd_min_shape <= RM_EPS) {
        // Animating normals... why not?
        rm.n = quantize_vector_angle(rm.n, radians(20.0));
        color = get_color_shape(rm, light, material, shadow);
    } else if (rm.sd_min_ground <= RM_EPS) {
        color = get_color_ground(rm, light, shadow);
    } else {
        color = get_color_sky(rm, light);
        return color;
    }

    // Color correction
    color = get_corrected_color(color);

    return color;
}

// -----------------------------------------------------------------------
// Let's go
void main() {
    Camera camera = Camera(
            get_ndc(), // ndc
            vec3(
                0.0,
                1.75,
                7.0
            ), // pos
            vec3(sin(u_time), 1.0, 0.0) // target
        );

    Light light = Light(
            normalize(vec3(-10.0, -10.0, -3.0)), // direction
            vec3(1.0), // color
            0.01, // ambient
            0.02 // softness
        );
    ;

    Material material = Material(
            vec3(1.0, 0.35, 0.15), // base_color
            1.0, // diffuse
            0.3, // specular
            2.0 // shininess
        );

    vec3 color = get_color_scene(camera, light, material);

    fs_color = vec4(color, 1.0);
}

