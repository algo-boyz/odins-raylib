#version 330

in vec2 vs_uv;
uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

out vec4 fs_color;

// Rotation matrices
mat3 rot_x(float a) {
    float sa = sin(a);
    float ca = cos(a);
    return mat3(1., 0., 0.,
                0., ca, sa,
                0., -sa, ca);
}

mat3 rot_y(float a) {
    float sa = sin(a);
    float ca = cos(a);
    return mat3(ca, 0., sa,
                0., 1., 0.,
                -sa, 0., ca);
}

mat3 rot_z(float a) {
    float sa = sin(a);
    float ca = cos(a);
    return mat3(ca, sa, 0.,
                -sa, ca, 0.,
                0., 0., 1.);
}

mat2 mm2(in float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

const mat4 m4 = mat4(-0.164, -0.223, -0.455, 0.846, 
                     -0.714, 0.576, 0.344, 0.198, 
                     -0.526, -0.782, 0.301, -0.146,
                     -0.431, 0.084, -0.764, -0.473) * 1.93;

float map(vec3 p) {
    float d = 0.;
    p.xz *= mm2(p.y * 0.05 - u_time * 0.015);
    p.y *= 0.58;
    vec4 q = vec4(p, u_time * 0.4 - p.y * 0.55);
    q.y -= u_time * 0.16;
    float cl = dot(p.xz, p.xz);
    q *= 0.85;
    float z = 1.15;
    float trk = 1.;
    
    // Reduced from 6 to 4 iterations
    for(int i = 0; i < 4; i++) {
        d += 0.75 - abs(dot(cos(q * 0.85), sin(q.yzwx)) - 0.9) * z;   
        z *= 0.65;
        q *= m4;
        q += (sin(q.zxwy * trk) + (cos(q * 1.5 - 2.5) * 0.3)) * 0.3;
        trk *= 1.4;
    }
    return d * 1.2 - cl * 0.2;
}

vec4 render(in vec3 ro, in vec3 rd) {
    vec4 rez = vec4(0);
    float t = 6.5;
    float step_size = 0.15; // Larger steps for better performance
    
    // Reduced from 70 to 50 iterations
    for(int i = 0; i < 50; i++) {
        if(rez.a > 0.95 || t > 16.) break; // Exit earlier
        
        vec3 pos = ro + t * rd;
        float dn = map(pos);
        float den = clamp(dn, 0.0, 1.0);
        
        if (dn < 0.0) {
            t += step_size;
            continue;
        }
        
        vec4 col = vec4(1.3 * vec3(0.105, 0.105, 0.11) * smoothstep(-12., 5., pos.y), 0.08) * den;
        
        // Simplified lighting - only one diffuse calculation
        float dif = clamp((dn - map(pos + vec3(0.3))) / 8., 0.01, 1.);
        col.xyz *= vec3(0.01, 0.01, 0.01) + vec3(0.14, 0.12, 0.1) * dif;
        
        rez = rez + col * (1. - rez.a);
        t += clamp(0.12 - den * 0.1, 0.08, step_size);
    }
    return clamp(rez, 0.0, 1.0);
}

void main() {
    vec2 q = vs_uv;
    vec2 p = q - 0.5;
    p.x *= u_aspect;
    
    // Convert mouse position from [0,1] to centered coordinates
    vec2 mo = u_mouse_pos - 0.5;
    mo = (mo == vec2(-0.5)) ? vec2(0.12, 0.15) : mo;
    mo.x *= u_aspect;
    mo *= 4.14;
    mo.y = clamp(mo.y * 0.6 - 0.5, -4., 0.15);
    
    vec3 ro = vec3(0., -0.0, 12.);
    vec3 rd = normalize(vec3(p, -1.5));
    
    mat3 cam = rot_x(-mo.y) * rot_y(-mo.x);
    rd *= cam;
    ro *= cam;
    
    vec4 scn = render(ro, rd);
    vec3 col = vec3(0.1, 0.1, 0.11) * smoothstep(-1., 1., rd.y) * 7.;
    
    col = col * (1.0 - scn.w) + scn.xyz;
    col = pow(col, vec3(0.45));
    col *= pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.1) * 0.9 + 0.1; // Vignette
    
    fs_color = vec4(col, 1.0);
}