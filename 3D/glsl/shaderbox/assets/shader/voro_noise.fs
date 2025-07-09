#version 330

in vec2 vs_uv;
out vec4 FragColor;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

vec3 hash3(vec2 p)
{
    vec3 q = vec3(dot(p, vec2(127.1, 311.7)), 
                  dot(p, vec2(269.5, 183.3)), 
                  dot(p, vec2(419.2, 371.9)));
    return fract(sin(q) * 43758.5453);
}

float voronoise(in vec2 p, float u, float v)
{
    float k = 1.0 + 63.0 * pow(1.0 - v, 6.0);
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    vec2 a = vec2(0.0, 0.0);
    for(int y = -2; y <= 2; y++)
    for(int x = -2; x <= 2; x++)
    {
        vec2 g = vec2(x, y);
        vec3 o = hash3(i + g) * vec3(u, u, 1.0);
        vec2 d = g - f + o.xy;
        float w = pow(1.0 - smoothstep(0.0, 1.414, length(d)), k);
        a += vec2(o.z * w, w);
    }
    
    return a.x / a.y;
}

void main()
{
    vec2 uv = vs_uv;
    
    // Animate the parameters
    vec2 p = 0.5 - 0.5 * cos(u_time + vec2(0.0, 2.0));
    
    // Use mouse position if available
    if(u_mouse_pos.x > 0.001 || u_mouse_pos.y > 0.001) {
        p = u_mouse_pos;
    }
    
    // Smooth the parameters
    p = p * p * (3.0 - 2.0 * p);
    p = p * p * (3.0 - 2.0 * p);
    p = p * p * (3.0 - 2.0 * p);
    
    // Generate voronoise
    float f = voronoise(24.0 * uv, p.x, p.y);
    
    FragColor = vec4(f, f, f, 1.0);
}