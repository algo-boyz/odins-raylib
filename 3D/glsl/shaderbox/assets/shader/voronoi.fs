#version 330

in vec2 vs_uv;
out vec4 finalColor;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

vec2 hash2(vec2 p) {
    // Procedural white noise
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

vec3 voronoi(in vec2 x) {
    vec2 ip = floor(x);
    vec2 fp = fract(x);
    
    // First pass: regular voronoi
    vec2 mg, mr;
    float md = 8.0;
    
    for(int j = -1; j <= 1; j++) {
        for(int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash2(ip + g);
            
            // Animate the cell centers
            o = 0.5 + 0.5 * sin(u_time + 6.2831 * o);
            
            vec2 r = g + o - fp;
            float d = dot(r, r);
            
            if(d < md) {
                md = d;
                mr = r;
                mg = g;
            }
        }
    }
    
    // Second pass: distance to borders  
    md = 8.0;
    for(int j = -2; j <= 2; j++) {
        for(int i = -2; i <= 2; i++) {
            vec2 g = mg + vec2(float(i), float(j));
            vec2 o = hash2(ip + g);
            
            // Animate the cell centers
            o = 0.5 + 0.5 * sin(u_time + 6.2831 * o);
            
            vec2 r = g + o - fp;
            
            if(dot(mr - r, mr - r) > 0.00001) {
                md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
            }
        }
    }
    
    return vec3(md, mr);
}

void main() {
    vec2 p = vs_uv;
    
    // Adjust for aspect ratio
    p.x *= u_aspect;
    
    vec3 c = voronoi(8.0 * p);
    
    // Isolines
    vec3 col = c.x * (0.5 + 0.5 * sin(64.0 * c.x)) * vec3(1.0);
    
    // Borders	
    col = mix(vec3(1.0, 0.6, 0.0), col, smoothstep(0.04, 0.07, c.x));
    
    // Feature points
    float dd = length(c.yz);
    col = mix(vec3(1.0, 0.6, 0.1), col, smoothstep(0.0, 0.12, dd));
    col += vec3(1.0, 0.6, 0.1) * (1.0 - smoothstep(0.0, 0.04, dd));
    
    finalColor = vec4(col, 1.0);
}