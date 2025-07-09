// Seascape by Alexander Alekseev aka TDM - 2014
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

out vec4 fs_color;

const int NUM_STEPS = 8;
const float PI = 3.1415926;
const float EPSILON = 1e-3;

// sea
const int ITER_GEOMETRY = 3;
const int ITER_FRAGMENT = 5;
const float SEA_HEIGHT = 0.6;
const float SEA_CHOPPY = 4.0;
const float SEA_SPEED = 0.8;
const float SEA_FREQ = 0.16;
const vec3 SEA_BASE = vec3(0.1, 0.19, 0.22);
const vec3 SEA_WATER_COLOR = vec3(0.8, 0.9, 0.6);

mat2 octave_m = mat2(1.6, 1.2, -1.2, 1.6);

// Turn a vector of Euler angles into a rotation matrix
mat3 fromEuler(vec3 ang) {
    vec2 a1 = vec2(sin(ang.x), cos(ang.x));
    vec2 a2 = vec2(sin(ang.y), cos(ang.y));
    vec2 a3 = vec2(sin(ang.z), cos(ang.z));
    mat3 m;
    m[0] = vec3(a1.y*a3.y+a1.x*a2.x*a3.x, a1.y*a2.x*a3.x+a3.y*a1.x, -a2.y*a3.x);
    m[1] = vec3(-a2.y*a1.x, a1.y*a2.y, a2.x);
    m[2] = vec3(a3.y*a1.x*a2.x+a1.y*a3.x, a1.x*a3.x-a1.y*a3.y*a2.x, a2.y*a3.y);
    return m;
}

// A 2D hash function for use in noise generation that returns range [0 .. 1].  You could
// use any hash function of choice, just needs to deterministic and return
// between 0 and 1, and also behave randomly.
// Performance is a real consideration of hash functions since ray-marching is already so heavy.
float hash(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));	
    return fract(sin(h) * 43758.5453123);
}

// A 2D psuedo-random wave / terrain function.  This is actually a poor name in my opinion,
// since its the "hash" function that is really the noise, and this function is smoothly interpolating
// between noisy points to create a continuous surface.
float noise(in vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);	
    vec2 u = f * f * (3.0 - 2.0 * f);
    return -1.0 + 2.0 * mix(
        mix(hash(i + vec2(0.0, 0.0)), 
            hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), 
            hash(i + vec2(1.0, 1.0)), u.x), 
        u.y);
}

// lighting
float diffuse(vec3 n, vec3 l, float p) {
    return pow(dot(n, l) * 0.4 + 0.6, p);
}

float specular(vec3 n, vec3 l, vec3 e, float s) {    
    float nrm = (s + 8.0) / (PI * 8.0);
    return pow(max(dot(reflect(e, n), l), 0.0), s) * nrm;
}

// Generate a smooth sky gradient color based on ray direction's Y value
vec3 getSkyColor(vec3 e) {
    e.y = max(e.y, 0.0);
    vec3 ret;
    ret.x = pow(1.0 - e.y, 2.0);
    ret.y = 1.0 - e.y;
    ret.z = 0.6 + (1.0 - e.y) * 0.4;
    return ret;
}

// Passes a low frequency random terrain through a 2D symmetric wave function that looks like this:
// The <choppy> parameter affects the wave shape.
float sea_octave(vec2 uv, float choppy) {
    // Add the smoothed 2D terrain / wave function to the input coordinates
    // which are going to be our X and Z world coordinates.  It may be unclear why we are doing this.
    // This value is about to be passed through a wave function.  So we have a smoothed psuedo random height
    // field being added to our (X, Z) coordinates, and then fed through yet another wave function below.
    uv += noise(uv);
    // Note that you could simply return noise(uv) here and it would take on the characteristics of our 
    // noise interpolation function u and would be a reasonable heightmap for terrain.  
    // However, that isn't the shape we want in the end for an ocean with waves, so it will be fed through
    // a more wave like function.
    vec2 wv = 1.0-abs(sin(uv)); 

    // Wave function with curved peaks and pointy troughs:
    vec2 swv = abs(cos(uv));  
  
    // Blending both wave functions gets us a new, cooler wave function (output between 0 and 1):
    wv = mix(wv,swv,wv);

    // Finally, compose both of the wave functions for X and Y channels into a final 
    // 1D height value, shaping it a bit along the way.  First, there is the composition (multiplication) of
    // the wave functions: wv.x * wv.y
    return pow(1.0-pow(wv.x * wv.y,0.65),choppy);
}

// Compute the distance along Y axis of a point to the surface of the ocean
// using a low(er) resolution ocean height composition function = less iterations
float map(vec3 p) {
    float SEA_TIME = u_time * SEA_SPEED;
    float freq = SEA_FREQ;
    float amp = SEA_HEIGHT;
    float choppy = SEA_CHOPPY;
    vec2 uv = p.xz; 
    uv.x *= 0.75;
    // Compose our wave noise generation ("sea_octave") with different frequencies
    // and offsets to achieve a final height map that looks like an ocean.  
    float d, h = 0.0;    
    for(int i = 0; i < ITER_GEOMETRY; i++) {
    	d = sea_octave((uv+SEA_TIME)*freq,choppy);
        // stack wave ontop of itself at an offset that varies over time for more variance
    	d += sea_octave((uv-SEA_TIME)*freq,choppy);

        h += d * amp; // Bump height by current wave func
        
        // "Twist" our domain input into a different space based on a permutation matrix
        // The scales of the matrix values affect the frequency of the wave at this iteration, but more importantly
        // it is responsible for the realistic assymetry since the domain is shiftly differently.
        // This is likely the most important parameter for wave topology.
    	uv *= octave_m;
        
        freq *= 1.9; // Exponentially increase frequency every iteration (on top of our permutation)
        amp *= 0.22; // Lower the amplitude every frequency, since we are adding finer and finer detail
        // finally, adjust the choppy parameter which will effect our base 2D sea_octave shape a bit.  This makes
        // the "waves within waves" have different looking shapes, not just frequency and offset
        choppy = mix(choppy,1.0,0.2);
    }
    return p.y - h;
}

// Compute the distance along Y axis of a point to the surface of the ocean
// using a high(er) resolution ocean height composition function = more iterations
float map_detailed(vec3 p) {
    float SEA_TIME = u_time * SEA_SPEED;
    float freq = SEA_FREQ;
    float amp = SEA_HEIGHT;
    float choppy = SEA_CHOPPY;
    vec2 uv = p.xz; 
    uv.x *= 0.75;
    
    float d, h = 0.0;    
    for(int i = 0; i < ITER_FRAGMENT; i++) {
        d = sea_octave((uv + SEA_TIME) * freq, choppy);
        d += sea_octave((uv - SEA_TIME) * freq, choppy);
        h += d * amp;
        uv *= octave_m;
        freq *= 1.9;
        amp *= 0.22;
        choppy = mix(choppy, 1.0, 0.2);
    }
    return p.y - h;
}

// p: point on ocean surface to get color for
// n: normal on ocean surface at <p>
// l: light (sun) direction
// eye: ray direction from camera position for this pixel
// dist: distance from camera to point <p> on ocean surface
vec3 getSeaColor(vec3 p, vec3 n, vec3 l, vec3 eye, vec3 dist) {  
    // Fresnel is an exponential that gets bigger when the angle between ocean
    // surface normal and eye ray is smaller
    float fresnel = 1.0 - max(dot(n,-eye),0.0);
    fresnel = pow(fresnel,3.0) * 0.65;
        
    // Bounce eye ray off ocean towards sky, and get the color of the sky
    vec3 reflected = getSkyColor(reflect(eye,n));    
    
    // refraction effect based on angle between light surface normal
    vec3 refracted = SEA_BASE + diffuse(n,l,80.0) * SEA_WATER_COLOR * 0.12; 
    
    // blend the refracted color with the reflected color based on our fresnel term
    vec3 color = mix(refracted,reflected,fresnel);
    
    // Apply a distance based attenuation factor which is stronger
    // at peaks
    float atten = max(1.0 - dot(dist,dist) * 0.001, 0.0);
    color += SEA_WATER_COLOR * (p.y - SEA_HEIGHT) * 0.18 * atten;
    
    // Apply specular highlight
    color += vec3(specular(n,l,eye,60.0));
    
    return color;
}

// Estimate the normal at a point <p> on the ocean surface using a slight more detailed
// ocean mapping function (using more noise octaves).
// Takes an argument <eps> (stands for epsilon) which is the resolution to use
// for the gradient.
vec3 getNormal(vec3 p, float eps) {
    // For simplicity and / or optimization reasons we approximate the gradient by the change in ocean
    // height for all axis.
    vec3 n;
    n.y = map_detailed(p); // Detailed height relative to surface
    n.x = map_detailed(vec3(p.x+eps,p.y,p.z)) - n.y; // approximate X gradient as change in height along X axis delta
    n.z = map_detailed(vec3(p.x,p.y,p.z+eps)) - n.y; // approximate Z gradient as change in height along Z axis delta
    // Taking advantage of the fact that we know we won't have really steep waves, we expect
    // the Y normal component to be fairly large always.
    n.y = eps; 
    return normalize(n);
}

// Find out where a ray intersects the current ocean
float heightMapTracing(vec3 ori, vec3 dir, out vec3 p) {  
    float tm = 0.0;
    float tx = 1000.0; // a really far distance
    float hx = map(ori + dir * tx);
    
    // A positive height relative to the ocean surface (in Y direction) at a really far distance means
    // this pixel is pure sky.  Quit early and return the far distance constant.
    if(hx > 0.0) return tx;   

    // hm starts out as the height of the camera position relative to ocean.
    float hm = map(ori + dir * tm); 
   
    // This is the main ray marching logic.
    float tmid = 0.0;
    for(int i = 0; i < NUM_STEPS; i++) { // Constant number of ray marches per ray that hits the water
        // Move forward along ray in such a way that has the following properties:
        // 1. If our current height relative to ocean is higher, move forward more
        // 2. If the height relative to ocean floor very far along the ray is much lower
        //    below the ocean surface, move forward less
        tmid = mix(tm,tx, hm/(hm-hx));
        p = ori + dir * tmid; 
                  
    	float hmid = map(p); // Re-evaluate height relative to ocean surface in Y axis

        if(hmid < 0.0) { // We went through the ocean surface if we are negative relative to surface now
            // So instead of actually marching forward to cross the surface, we instead
            // assign our really far distance and height to be where we just evaluated that crossed the surface.
            // Next iteration will attempt to go forward more and is less likely to cross the boundary.
            // A naive implementation might have returned <tmid> immediately here, which
            // results in a much poorer / somewhat indeterministic quality rendering.
            tx = tmid;
            hx = hmid;
        } else {
            // Haven't hit surface yet, easy case, just march on
            tm = tmid;
            hm = hmid;
        }
    }
    // Return the distance
    return tmid;
}

void main() {
    vec2 uv = vs_uv * 2.0 - 1.0;
    uv.x *= u_aspect;
    
    // Use mouse for interactive time control
    float time = u_time * 0.3 + u_mouse_pos.x * 2.0;
        
    // Camera animation
    vec3 ang = vec3(sin(time * 3.0) * 0.1, sin(time) * 0.2 + 0.3, time);
    vec3 ori = vec3(0.0, 3.5, time * 5.0);
    vec3 dir = normalize(vec3(uv.xy, -2.0)); 
    
    // Optional fish eye effect - uncomment to enable
    dir.z += length(uv) * 0.15;
    
    dir = normalize(dir) * fromEuler(ang);

    // Ray-march to ocean surface
    vec3 p;
    heightMapTracing(ori, dir, p);
    vec3 dist = p - ori;
    
    // Calculate epsilon for normal based on distance
    float EPSILON_NRM = 0.1 / u_resolution.x;
    vec3 n = getNormal(p, dot(dist, dist) * EPSILON_NRM);
    
    // Light direction
    vec3 light = normalize(vec3(0.0, 1.0, 0.8)); 
             
    // Mix sky and sea colors with fog
    vec3 color = mix(
        getSkyColor(dir),
        getSeaColor(p, n, light, dir, dist),
        pow(smoothstep(0.0, -0.05, dir.y), 0.3)
    );
        
    // Apply gamma correction
    fs_color = vec4(pow(color, vec3(0.75)), 1.0);
}