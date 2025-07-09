#version 330

// Combined fragment shader:
// - Renders a 3D shape's outline using ray marching (from sd_outline).
// - Colors the outline using a screen-space animated spectrum ring (from Spectrum Beam).

in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define PI 3.1415926535

// --- Ray Marching Setup (from sd_outline) ---

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

// The Signed Distance Function for the scene.
// Currently a sphere of radius 2.0 centered at the origin.
float get_sd_shape(vec3 p) {
    // To make it a sphere of radius 2, we subtract 2.
    return length(p) - 2.0;
}

#define RM_MAX_DIST 10000.0
#define RM_MAX_N_STEPS 64
#define RM_EPS 0.0001

RayMarchResult march(vec3 ro, vec3 rd) {
    RayMarchResult rm = RayMarchResult(
        0, ro, vec3(0.0), ro, rd, 0.0, 0.0, RM_MAX_DIST, RM_MAX_DIST
    );

    for (; rm.i < RM_MAX_N_STEPS; ++rm.i) {
        rm.p = ro + rd * rm.dist; // More stable distance calculation

        float sd_step_shape = get_sd_shape(rm.p);
        rm.sd_min_shape = min(rm.sd_min_shape, sd_step_shape);

        rm.sd_last = sd_step_shape;
        rm.sd_min = min(rm.sd_min, rm.sd_last);

        if (rm.sd_last < RM_EPS || rm.dist > RM_MAX_DIST) {
            break;
        }
        
        rm.dist += rm.sd_last;
    }

    // Note: Normal calculation was empty in the original and has been omitted.
    return rm;
}

// -----------------------------------------------------------------------
void main() {
    // --- Part 1: Ray Marching (from sd_outline) ---
    // This section calculates the camera, ray direction, and marches into the 3D scene.

    vec2 screen_pos = vs_uv * 2.0 - 1.0;
    screen_pos.x *= u_aspect;

    // Camera setup
    float fov = radians(100.0);
    float screen_dist = 1.0 / tan(0.5 * fov);
    vec3 cam_pos = vec3(0.0, 2.0, 5.0);
    vec3 look_at = vec3(0.0, 2.0, 0.0);

    vec3 forward = normalize(look_at - cam_pos);
    vec3 world_up = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(forward, world_up));
    vec3 up = normalize(cross(right, forward));

    vec3 screen_center = cam_pos + forward * screen_dist;
    vec3 screen_point = screen_center + right * screen_pos.x + up * screen_pos.y;

    vec3 ro = cam_pos;
    vec3 rd = normalize(screen_point - cam_pos);

    RayMarchResult rm = march(ro, rd);

    // --- Part 2: Outline Intensity Calculation (from sd_outline) ---
    // This calculates a brightness value based on how close the ray came to the object's surface.
    // 'd' will be high (close to 1.0) at the outline and low (close to 0.0) everywhere else.
    // NOTE: The original shader had 'abs(d - 2.0)'. The SDF already returns distance, so we
    // use 'rm.sd_min_shape' directly for a more traditional outline.
    float d = rm.sd_min_shape;
    d = 1.0 - pow(d, 0.15); // Create a glow that falls off from the surface
    d = pow(3.0 * d, 16.0); // Sharpen the glow into a thin line

    // --- Part 3: Spectrum Color Calculation (from Spectrum Beam) ---
    // This generates the rainbow color pattern based on the fragment's screen position (vs_uv).
    
    // Convert screen coordinates to polar coordinates (angle and radius)
    vec2 p = (vs_uv * 2.0 - 1.0); // Map UVs from [0,1] to [-1,1]
    p.x *= u_aspect; // Correct aspect ratio to ensure the color pattern is a circle
	
    // Note: The original shader used atan(x,y). The standard is atan(y,x).
    // We use the original's atan(p.x, p.y) to preserve its specific visual style.
    float a = atan(p.x, p.y);
    float r = length(p); // Radius is not used for color, but calculated for completeness
    vec2 spectrum_uv = vec2(a / (2.0 * PI), r);

	// Get the animated rainbow colour based on the angle
	float xCol = (spectrum_uv.x - (u_time / 8.0)) * 3.0;
	xCol = mod(xCol, 3.0);
	vec3 spectrum_color = vec3(0.25, 0.25, 0.25); // Base color
	
	if (xCol < 1.0) {
		spectrum_color.r += 1.0 - xCol;
		spectrum_color.g += xCol;
	}
	else if (xCol < 2.0) {
		xCol -= 1.0;
		spectrum_color.g += 1.0 - xCol;
		spectrum_color.b += xCol;
	}
	else {
		xCol -= 2.0;
		spectrum_color.b += 1.0 - xCol;
		spectrum_color.r += xCol;
	}

    // --- Part 4: Combine and Finalize ---
    // Modulate the spectrum color with the outline intensity.
    // The color will only appear where the outline is bright.
    vec3 final_color = spectrum_color * d;

    fs_color = vec4(final_color, 1.0);
}