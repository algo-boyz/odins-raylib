#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

out vec4 fs_color;

#define OCTAVES  8.0
#define LIVE_SMOKE 0  // Disabled since we don't have audio input

float rand(vec2 co){
   return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float rand2(vec2 co){
   return fract(cos(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// Rough Value noise implementation
float valueNoiseSimple(vec2 vl) {
   float minStep = 1.0 ;
   vec2 grid = floor(vl);
   vec2 gridPnt1 = grid;
   vec2 gridPnt2 = vec2(grid.x, grid.y + minStep);
   vec2 gridPnt3 = vec2(grid.x + minStep, grid.y);
   vec2 gridPnt4 = vec2(gridPnt3.x, gridPnt2.y);
    float s = rand2(grid);
    float t = rand2(gridPnt3);
    float u = rand2(gridPnt2);
    float v = rand2(gridPnt4);
    
    float x1 = smoothstep(0., 1., fract(vl.x));
    float interpX1 = mix(s, t, x1);
    float interpX2 = mix(u, v, x1);
    
    float y = smoothstep(0., 1., fract(vl.y));
    float interpY = mix(interpX1, interpX2, y);
    
    return interpY;
}

float getLowFreqs()
{
    // Since we don't have audio input, simulate with mouse position and time
    float mouseInfluence = length(u_mouse_pos - vec2(0.5)) * 2.0;
    float timeInfluence = sin(u_time * 0.5) * 0.5 + 0.5;
    
    // Create a pseudo-audio reactive value
    float result = mix(timeInfluence, mouseInfluence, 0.7);
    result += 0.3 * sin(u_time * 1.2) * sin(u_time * 0.8);
    
    return smoothstep(0.0, 1.0, result);
}

float fractalNoise(vec2 vl) {
    float persistance = 2.0;
    float amplitude = 0.5;
    float rez = 0.0;
    vec2 p = vl;
    
    for (float i = 0.0; i < OCTAVES; i++) {
        rez += amplitude * valueNoiseSimple(p);
        amplitude /= persistance;
        p *= persistance;
    }
    return rez;
}

float complexFBM(vec2 p) {
    float sound = getLowFreqs();
    float slow = u_time / 2.5;
    float fast = u_time / 0.5;
    vec2 offset1 = vec2(slow, 0.); // Main front
    vec2 offset2 = vec2(sin(fast) * 0.1, 0.); // sub fronts
    return 
#if LIVE_SMOKE
        (1. + sound) * 
#else
        (1. + sound * 0.5) *  // Reduced influence since it's simulated
#endif
        fractalNoise( p + offset1 + fractalNoise(
            	p + fractalNoise(
                	p + 2. * fractalNoise(p - offset2)
            	)
        	)
        );
}

void main()
{
    vec2 uv = vs_uv;
    
    // Scale the coordinates to create more interesting patterns
    vec2 scaledUV = uv * 4.0;
   
    vec3 blueColor = vec3(0.529411765, 0.807843137, 0.980392157);
    vec3 orangeColor2 = vec3(0.509803922, 0.203921569, 0.015686275);
    
    vec3 rez = mix(orangeColor2, blueColor, complexFBM(scaledUV));
    
    fs_color = vec4(rez, 1.0);
}