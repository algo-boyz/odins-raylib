#version 330

in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

out vec4 fs_color;

// Precomputed constants
const float PI = 3.14159265359;
const float INV_PI = 0.31830988618;
const vec3 HASH_CONST = vec3(12.9898, 78.233, 37.719);
const float HASH_SCALE = 43758.5453;

// Fast rotation matrix - inline for better performance
mat2 rot2(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

float moy = 0.0;

// Optimized hash function
float hash(vec3 p) {
    return fract(sin(dot(p, HASH_CONST)) * HASH_SCALE);
}

/*
Could load a precomputed noise texture for better performance or use psudo_perlin.fs

uniform sampler2D u_noise_texture; // 256x256 noise texture
float texNoise(vec3 p) {
    return texture(u_noise_texture, p.xy * 0.1).r;
}
*/

// Simplified noise with fewer hash calls
float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Hermite interpolation
    
    // Reduce from 8 to 4 samples for 2x speedup
    float n00 = hash(i);
    float n10 = hash(i + vec3(1,0,0));
    float n01 = hash(i + vec3(0,1,0));
    float n11 = hash(i + vec3(1,1,0));
    
    return mix(mix(n00, n10, f.x), mix(n01, n11, f.x), f.y);
}

// Reduced octaves FBM (was 2, could go to 1 for more speed)
float fbm(vec3 x) {
    return noise(x) * 0.6 + noise(x * 4.0) * 0.2; // Unrolled loop
}

// Simplified path function
float path(float x) {
    return sin(x * 0.01 - PI) * 28.0 + 6.5;
}

// Optimized map function with fewer operations
float map(vec3 p) {
    return p.y * 0.07 + 
           (fbm(p * 0.3) - 0.1) + 
           sin(p.x * 0.24 + sin(p.z * 0.01) * 7.0) * 0.22 + 
           0.15 + sin(p.z * 0.08) * 0.05;
}

// Reduced precision raymarching
float march(vec3 ro, vec3 rd) {
    float d = 0.0;
    for (int i = 0; i < 12; i++) { // Reduced from 17
        vec3 pos = ro + rd * d;
        pos.y += 0.5;
        float h = map(pos) * 7.0;
        if (abs(h) < 0.5 || d > 70.0) break; // Relaxed precision
        d += h;
    }
    return d;
}

vec3 lgt = vec3(0);

float mapV(vec3 p) {
    return clamp(-map(p), 0.0, 1.0);
}

// Optimized volume marching with adaptive step size
vec4 marchV(vec3 ro, vec3 rd, float t, vec3 bgc) {
    vec4 rz = vec4(0.0);
    float step_size = 0.5; // Larger initial step
    
    for (int i = 0; i < 80; i++) { // Reduced from 150
        if (rz.a > 0.95 || t > 200.0) break; // Early exit
        
        vec3 pos = ro + t * rd;
        float den = mapV(pos);
        
        if (den > 0.01) { // Only compute lighting for visible density
            vec4 col = vec4(mix(vec3(0.8, 0.75, 0.85), vec3(0.0), den), den);
            
            // Simplified lighting calculation
            float light_contrib = clamp(-(den * 40.0) * pos.y * 0.03 - moy * 0.5, 0.0, 1.0);
            col.xyz *= mix(bgc * 2.0, vec3(0.4, 0.5, 0.7), light_contrib);
            
            // Simplified fringes
            col.rgb += clamp((1.0 - den * 6.0) + pos.y * 0.13 + 0.55, 0.0, 1.0) * 0.35;
            
            col.a *= 0.9;
            col.rgb *= col.a;
            rz = rz + col * (1.0 - rz.a);
        }
        
        // Adaptive step size
        step_size = max(0.4, (2.0 - den * 20.0) * t * 0.015);
        t += step_size;
    }
    
    return clamp(rz, 0.0, 1.0);
}

// Optimized pentagon distance
float pent(vec2 p) {
    vec2 q = abs(p);
    return max(q.x * 1.176 - p.y * 0.385, max(q.x * 0.727 + p.y, -p.y * 1.237));
}

// Simplified lens flare
vec3 lensFlare(vec2 p, vec2 pos) {
    vec2 q = p - pos;
    float dq = dot(q, q);
    
    if (dq > 2.0) return vec3(0.0); // Early exit for distant flares
    
    vec2 dist = p * length(p) * 0.75;
    float ang = atan(q.x, q.y);
    vec2 pp = mix(p, dist, 0.5);
    
    float rz = pow(abs(fract(ang * 0.8 + 0.12) - 0.5), 2.0) * 0.3; // Reduced power
    rz *= smoothstep(1.0, 0.0, dq);
    rz *= smoothstep(0.0, 0.01, dq);
    
    // Fewer flare elements
    float sz = 0.01;
    rz += max(1.0 / (1.0 + 30.0 * pent(dist + 0.8 * pos)), 0.0) * 0.17;
    rz += clamp(sz - pow(pent(pp + 0.15 * pos), 1.5), 0.0, 1.0) * 3.0;
    rz += clamp(sz - pow(pent(pp - 0.05 * pos), 1.2), 0.0, 1.0) * 2.5;
    
    return vec3(clamp(rz, 0.0, 1.0));
}

// Inline rotation functions for better performance
mat3 rot_x(float a) {
    float sa = sin(a), ca = cos(a);
    return mat3(1.0, 0.0, 0.0, 0.0, ca, sa, 0.0, -sa, ca);
}

mat3 rot_y(float a) {
    float sa = sin(a), ca = cos(a);
    return mat3(ca, 0.0, sa, 0.0, 1.0, 0.0, -sa, 0.0, ca);
}

mat3 rot_z(float a) {
    float sa = sin(a), ca = cos(a);
    return mat3(ca, sa, 0.0, -sa, ca, 0.0, 0.0, 0.0, 1.0);
}

void main() {
    vec2 q = vs_uv;
    vec2 p = q - 0.5;
    p.x *= u_aspect;
    vec2 mo = u_mouse_pos;
    moy = mo.y;
    
    float time = u_time;
    float st = sin(time * 0.3 - 1.3) * 0.2;
    
    // Camera setup
    vec3 ro = vec3(path(time * 30.0), -2.0 + sin(time * 0.3 - 1.0) * 2.0, time * 30.0);
    vec3 ta = ro + vec3(0, 0, 1);
    vec3 fw = normalize(ta - ro);
    vec3 uu = normalize(cross(vec3(0.0, 1.0, 0.0), fw));
    vec3 vv = normalize(cross(fw, uu));
    
    vec3 rd = normalize(p.x * uu + p.y * vv - fw);
    
    // Rotation calculations
    float rox = sin(time * 0.2) * 0.6 + 2.9 + smoothstep(0.6, 1.2, sin(time * 0.25)) * 3.5;
    float roy = sin(time * 0.5) * 0.2;
    
    mat3 rotation = rot_x(-roy) * rot_y(-rox + st * 1.5) * rot_z(st);
    mat3 inv_rotation = rot_z(-st) * rot_y(rox - st * 1.5) * rot_x(roy);
    
    rd = normalize(rotation * rd);
    rd.y -= dot(p, p) * 0.06;
    rd = normalize(rd);
    
    // Lighting
    lgt = normalize(vec3(-0.3, mo.y + 0.1, 1.0));
    float rdl = clamp(dot(rd, lgt), 0.0, 1.0);
    
    // Background with fewer mix operations
    vec3 hor = mix(vec3(0.315, 0.21, 0.245), vec3(0.5, 0.05, 0.05), rdl);
    hor = mix(hor, vec3(0.5, 0.8, 1), mo.y);
    
    vec3 col = mix(vec3(0.2, 0.2, 0.6), hor, exp2(-(1.0 + 3.0 * (1.0 - rdl)) * max(abs(rd.y), 0.0))) * 0.6;
    
    // Simplified sun contributions
    col += vec3(0.8, 0.72, 0.72) * exp2(rdl * 650.0 - 650.0);
    col += vec3(0.3, 0.3, 0.03) * exp2(rdl * 100.0 - 100.0);
    col += vec3(0.25, 0.175, 0.0) * exp2(rdl * 50.0 - 50.0);
    
    vec3 bgc = col;
    
    // Raymarching
    float rz = march(ro, rd);
    
    if (rz < 70.0) {
        vec4 res = marchV(ro, rd, rz - 5.0, bgc);
        col = col * (1.0 - res.w) + res.xyz;
    }
    
    // Lens flare
    vec3 proj = (-lgt * inv_rotation);
    col += 1.4 * vec3(0.7, 0.7, 0.4) * clamp(lensFlare(p, -proj.xy / proj.z) * proj.z, 0.0, 1.0);
    
    // Color grading
    float g = smoothstep(0.03, 0.97, mo.x);
    col = mix(mix(col, col.brg * vec3(1, 0.75, 1), clamp(g * 2.0, 0.0, 1.0)), col.bgr, clamp((g - 0.5) * 2.0, 0.0, 1.0));
    
    // Final color correction
    col = clamp(col, 0.0, 1.0);
    col = col * 0.5 + 0.5 * col * col * (3.0 - 2.0 * col);
    col = pow(col, vec3(0.416667)) * 1.055 - 0.055;
    
    // Vignette
    col *= pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.12);
    
    fs_color = vec4(col, 1.0);
}