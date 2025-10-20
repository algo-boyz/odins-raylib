#version 330
// based on: https://www.shadertoy.com/view/7s2GR3

// Uniforms expected by your shaderbox
uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

// Input from vertex shader (your base.vs uses vs_uv)
in vec2 vs_uv;

// Output color
out vec4 fs_color;

const float PI = 3.14159265359;

// Helper functions from the original shader
vec3 vec_tovec3(float a) {
    return vec3(a, a, a);
}

vec3 noise_vec3_yzx(vec3 self) {
    return vec3(self.y, self.z, self.x);
}

vec3 noise_vec2_xyx(vec2 self) {
    return vec3(self.x, self.y, self.x);
}

vec2 sincos(float x) {
    return vec2(sin(x), cos(x));
}

float noise_hash1_2(vec2 v) {
    vec3 v3 = noise_vec2_xyx(v);
    v3 = fract(v3 * 0.1031);
    v3 = v3 + dot(v3, noise_vec3_yzx(v3) + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

float noise_hash1_3(vec3 v) {
    vec3 v3 = v;
    v3 = fract(v3 * 0.1031);
    v3 = v3 + dot(v3, noise_vec3_yzx(v3) + 33.33);
    return fract((v3.x + v3.y) * v3.z);
}

float noise_noisemix3(float a1, float b1, float c1, float d1, float a2, float b2, float c2, float d2, vec3 f) {
    vec3 u = f * f * (3.0 - 2.0 * f);
    vec3 u1 = 1.0 - u;
    return ((((a1 * u1.x + b1 * u.x) * u1.y + (c1 * u1.x + d1 * u.x) * u.y) * u1.z) +
            (((a2 * u1.x + b2 * u.x) * u1.y + (c2 * u1.x + d2 * u.x) * u.y) * u.z));
}

float noise_noise_white_1(vec2 p) {
    return noise_hash1_2(p);
}

float noise_noise_value_1(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 j = i + 1.0;
    float a1 = noise_hash1_3(i);
    float b1 = noise_hash1_3(vec3(j.x, i.y, i.z));
    float c1 = noise_hash1_3(vec3(i.x, j.y, i.z));
    float d1 = noise_hash1_3(vec3(j.x, j.y, i.z));
    float a2 = noise_hash1_3(vec3(i.x, i.y, j.z));
    float b2 = noise_hash1_3(vec3(j.x, i.y, j.z));
    float c2 = noise_hash1_3(vec3(i.x, j.y, j.z));
    float d2 = noise_hash1_3(j);
    return noise_noisemix3(a1, b1, c1, d1, a2, b2, c2, d2, f);
}

float sphere_intersect(vec3 ro, vec3 rd, vec3 p, float r) {
    vec3 oc = ro - p;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - r * r;
    float h = b * b - c;
    if (h < 0.0) {
        return -1.0;
    } else {
        return -b - sqrt(h);
    }
}

float fbm3(vec3 p) {
    float a = 1.0;
    float t = 0.0;
    t = t + a * noise_noise_value_1(p); a = a * 0.5; p = 2.0 * p + 100.0;
    t = t + a * noise_noise_value_1(p); a = a * 0.5; p = 2.0 * p + 100.0;
    t = t + a * noise_noise_value_1(p); a = a * 0.5; p = 2.0 * p + 100.0;
    t = t + a * noise_noise_value_1(p); a = a * 0.5; p = 2.0 * p + 100.0;
    t = t + a * noise_noise_value_1(p); a = a * 0.5; p = 2.0 * p + 100.0;
    t = t + a * noise_noise_value_1(p);
    return t;
}

vec3 planet_palette(float x) {
    vec3 col = vec3(0.1, 0.6, 0.9);
    col = col + 0.2 * sin(6.28318531 * x + vec3(0.3, 0.2, 0.1));
    col = col + 0.1 * sin(14.4513262 * x + vec3(0.1, 0.2, 0.3));
    return col;
}

vec3 planet_color(vec3 p) {
    p = p * 2.0;
    float t = u_time;
    vec3 q = vec3(fbm3(p + t * 0.03) * 0.5, fbm3(p) * 0.5, fbm3(p + 33.33) * 0.5);
    vec3 r = vec3(fbm3(p + q + t * 0.01) * 0.5, fbm3(p + q) * 0.5, fbm3(p + q + 33.33) * 0.6);
    float f = fbm3(p + 5.0 * r + t * 0.02) * 0.5;
    vec3 col = planet_palette(r.y);
    col = col * (clamp(f * f, 0.0, 1.0) * 0.9 + 0.1);
    col = clamp(col, 0.0, 1.0);
    return col;
}

vec3 shade(vec3 rd, vec3 p) {
    vec3 normal = normalize(p);
    float ambient_dif = 0.03;
    vec3 dif = vec_tovec3(ambient_dif);
    vec3 sun_dir = vec3(0.0, 0.0, 1.0);
    vec3 sun_col = vec3(1.0, 0.9, 0.9) * 4.0;
    float sun_dif = clamp(dot(normal, sun_dir) * 0.9 + 0.1, 0.0, 1.0);
    dif = dif + sun_col * sun_dif;
    vec3 mate = planet_color(p) * 0.4;
    vec3 col = mate * dif;
    float fres = clamp(1.0 + dot(normal, rd), 0.0, 1.0);
    float sun_fres = fres * clamp(dot(rd, sun_dir), 0.0, 1.0);
    col = col * (1.0 - fres);
    col = col + pow(sun_fres, 8.0) * vec3(0.4, 0.3, 0.1) * 5.0;
    return col;
}

vec3 perspective_camera(vec3 lookfrom, vec3 lookat, float tilt, float vfov, vec2 uv) {
    vec2 sc = sincos(tilt);
    vec3 vup = normalize(vec3(sc.x, sc.y, 0.0));
    vec3 w = normalize(lookat - lookfrom);
    vec3 u = cross(w, vup);
    vec3 v = cross(u, w);
    float wf = 1.0 / tan(vfov * PI / 360.0);
    return normalize(uv.x * u + uv.y * v + wf * w);
}

float expstep(float x, float k) {
    return exp(k * x - k);
}

vec3 get_background(vec3 rd) {
    vec3 sun_dir = vec3(0.0, 0.0, 1.0);
    float sun_dif = dot(rd, sun_dir);
    vec3 col = vec3(1.0, 0.9, 0.9) * expstep(sun_dif, 600.0);
    col = col + vec3(1.0, 1.0, 0.1) * expstep(sun_dif, 100.0);
    col = col + vec3(1.0, 0.7, 0.7) * expstep(sun_dif, 50.0);
    col = col + vec3(1.0, 0.6, 0.05) * expstep(sun_dif, 10.0);
    return col;
}

vec3 color_tonemap_aces(vec3 col) {
    return clamp((col * (2.51 * col + 0.03)) / (col * (2.43 * col + 0.59) + 0.14), 0.0, 1.0);
}

vec3 color_saturate(vec3 col, float sat) {
    float grey = dot(col, vec3(0.2125, 0.7154, 0.0721));
    return grey + sat * (col - grey);
}

vec3 color_tone_1(vec3 col, float gain, float lift, float invgamma) {
    col = pow(col, vec_tovec3(invgamma));
    return (gain - lift) * col + lift;
}

vec3 color_gamma_correction(vec3 col) {
    return pow(col, vec_tovec3(0.454545455));
}

vec3 vignette(vec3 col, vec2 coord, float strength, float amount) {
    return col * ((1.0 - amount) + amount * pow(16.0 * coord.x * coord.y * (1.0 - coord.x) * (1.0 - coord.y), strength));
}

vec3 dither(vec3 col, vec2 coord, float amount) {
    return clamp(col + noise_noise_white_1(coord) * amount, 0.0, 1.0);
}

vec3 sun_glare(vec3 rd) {
    vec3 sun_dir = vec3(0.0, 0.0, 1.0);
    vec3 glare_col = vec3(1.0, 0.6, 0.2);
    return glare_col * pow(max(dot(sun_dir, rd), 0.0), 2.0);
}

void main() {
    vec2 mouse = u_mouse_pos / u_resolution;
    
    // Convert vs_uv (0 to 1) to normalized device coordinates (-1 to 1)
    // Account for aspect ratio to maintain circular shapes
    vec2 coord = (vs_uv - 0.5) * 2.0;
    coord.x *= u_aspect;
    
    float theta = 1.88495559 + u_time * 0.2 + 6.28318531 * mouse.x;
    vec3 lookat = vec3(0.0, 0.0, 0.0);
    vec2 sc = sincos(theta) * 2.0;
    vec3 ro = vec3(sc.x, 0.5, sc.y);
    vec3 rd = perspective_camera(ro, lookat, 0.0, 50.0, coord);
    
    float t = sphere_intersect(ro, rd, vec3(0.0, 0.0, 0.0), 0.6);
    vec3 p = ro + rd * t;
    vec3 col = get_background(rd);
    
    if (t >= 0.0) {
        col = shade(rd, p);
    }
    
    col = col + 0.2 * sun_glare(rd);
    col = color_tonemap_aces(col);
    col = color_tone_1(col, 1.7, 0.002, 1.2);
    col = color_saturate(col, 0.9);
    col = color_gamma_correction(col);
    col = vignette(col, vs_uv, 0.25, 0.7);
    col = dither(col, vs_uv * u_resolution, 0.01);
    
    fs_color = vec4(col, 1.0);
}