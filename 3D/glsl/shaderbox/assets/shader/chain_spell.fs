#version 330
in vec2 vs_uv;
// based on: https://www.shadertoy.com/view/Ms2BRz

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;

out vec4 fs_color;

#define PI 3.14159
#define TAU (PI * 2)
// number of ray steps
#define t u_time
#define STEPS 30.
#define BIAS 0.001
#define DIST_MIN 0.01

// rotation matrix
mat2 rot(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

// distance field functions
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdCylinder(vec2 p, float r) {
    return length(p) - r;
}

float sdTorus(vec3 p, vec2 s) {
    vec2 q = vec2(length(p.xz) - s.x, p.y);
    return length(q) - s.y;
}

float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

// smooth minimum
float smin(float a, float b, float r) {
    float h = clamp(0.5 + 0.5 * (b - a) / r, 0.0, 1.0);
    return mix(b, a, h) - r * h * (1.0 - h);
}

// one-liner random
float rand(vec2 co) {
    return fract(sin(dot(co * 0.123, vec2(12.9898, 78.233))) * 43758.5453);
}

// polar domain repetition
vec3 moda(vec2 p, float count) {
    float an = TAU / count;
    float a = atan(p.y, p.x) + an / 2.0;
    float c = floor(a / an);
    a = mod(a, an) - an / 2.0;
    return vec3(vec2(cos(a), sin(a)) * length(p), c);
}

// the rhythm of animation
float getLocalWave(float x) {
    return sin(-t + x * 3.0);
}

// displacement in world space of the animation
float getWorldWave(float x) {
    return 1.0 - 0.1 * getLocalWave(x);
}

// camera control
vec3 camera(vec3 p) {
    // Use the normalized mouse position from shaderbox
    vec2 mouse = u_mouse_pos;
    p.yz *= rot(PI * (mouse.y - 0.5));
    p.xz *= rot(PI * (mouse.x - 0.5));
    return p;
}

// position of chain
vec3 posChain(vec3 p, float count) {
    float za = atan(p.z, p.x);
    vec3 dir = normalize(p);

    // domain repetition
    vec3 m = moda(p.xz, count);
    p.xz = m.xy;
    float lw = getLocalWave(m.z / PI);
    p.x -= 1.0 - 0.1 * lw;

    // the chain shape
    p.z *= 1.0 - clamp(0.03 / abs(p.z), 0.0, 1.0);

    // animation of breaking chain
    float r1 = lw * smoothstep(0.1, 0.5, lw);
    float r2 = lw * smoothstep(0.4, 0.6, lw);
    p += dir * mix(0.0, 0.3 * sin(floor(za * 3.0)), r1);
    p += dir * mix(0.0, 0.8 * sin(floor(za * 60.0)), r2);

    // rotate chain for animation smoothness
    float a = lw * 0.3;
    p.xy *= rot(a);
    p.xz *= rot(a);
    return p;
}

// distance function for spell
float mapSpell(vec3 p) {
    float scene = 1.0;
    float a = atan(p.z, p.x);
    float l = length(p);
    float lw = getLocalWave(a);

    // warping space into cylinder
    p.z = l - 1.0 + 0.1 * lw;

    // torsade effect
    p.yz *= rot(t + a * 2.0);

    // long cube shape
    scene = min(scene, sdBox(p, vec3(10.0, vec2(0.25 - 0.1 * lw))));

    // long cylinder cutting the box (intersection difference)
    scene = max(scene, -sdCylinder(p.zy, 0.3 - 0.2 * lw));
    return scene;
}

// distance function for the chain
float mapChain(vec3 p) {
    float scene = 1.0;

    // number of chain
    float count = 21.0;

    // size of chain
    vec2 size = vec2(0.1, 0.02);

    // first set of chains
    float torus = sdTorus(posChain(p, count).yxz, size);
    scene = smin(scene, torus, 0.1);

    // second set of chains
    p.xz *= rot(PI / count);
    scene = min(scene, sdTorus(posChain(p, count).xyz, size));
    return scene;
}

// position of core stuff
vec3 posCore(vec3 p, float count) {
    // polar domain repetition
    vec3 m = moda(p.xz, count);
    p.xz = m.xy;

    // linear domain repetition
    float c = 0.2;
    p.x = mod(p.x, c) - c / 2.0;
    return p;
}

// distance field for the core thing in the center
float mapCore(vec3 p) {
    float scene = 1.0;

    // number of torus repeated
    float count = 10.0;

    // displace space
    p.xz *= rot(p.y * 6.0);
    p.xz *= rot(t);
    p.xy *= rot(t * 0.5);
    p.yz *= rot(t * 1.5);
    vec3 p1 = posCore(p, count);
    vec2 size = vec2(0.1, 0.2);

    // tentacles torus shape
    scene = min(scene, sdTorus(p1.xzy * 1.5, size));

    // sphere used for intersection difference with the toruses
    scene = max(-scene, sdSphere(p, 0.6));
    return scene;
}

void main() {
    // Use normalized UV coordinates from vertex shader
    vec2 uv = (vs_uv - 0.5) * 2.0;  // Convert [0,1] to [-1,1]
    uv.x *= u_aspect;  // Apply aspect ratio correction
    
    // raymarch camera
    vec3 eye = camera(vec3(uv, -1.5));
    vec3 ray = camera(normalize(vec3(uv, 1.0)));
    vec3 pos = eye;
    
    // dithering - use vs_uv for seed
    vec2 seed = vs_uv + fract(u_time);

    float shade = 0.0;
    for (float i = 0.0; i < STEPS; ++i) {
        
        // distance from the different shapes
        float distSpell = min(mapSpell(pos), mapCore(pos));
        float distChain = mapChain(pos);
        float dist = min(distSpell, distChain);
        
        // hit volume
        if (dist < BIAS) {
            shade += 1.0;
            // hit non transparent volume
            if (distChain < distSpell) {
                
                // set shade and stop iteration
                shade = STEPS - i - 1.0;
                break;
            }
        }
        // dithering
        dist = max(DIST_MIN, abs(dist) * (0.8 + 0.2 * rand(seed + u_time)));
        
        // raymarch
        pos += ray * dist;
    }
    // color from the normalized steps
    fs_color = vec4(vec3(shade / (STEPS - 1.0)), 1.0);
}