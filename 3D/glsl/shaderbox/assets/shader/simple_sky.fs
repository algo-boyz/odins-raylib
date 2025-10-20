// based on: https://www.shadertoy.com/view/MsVSWt
// todo combine with: https://www.shadertoy.com/view/MdtXD2
#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

out vec4 fs_color;

vec3 getSky(vec2 uv)
{
    float atmosphere = sqrt(1.0 - uv.y);
    vec3 skyColor = vec3(0.2, 0.4, 0.8);
    
    float scatter = pow(u_mouse_pos.y, 1.0 / 15.0);
    scatter = 1.0 - clamp(scatter, 0.8, 1.0);
    
    vec3 scatterColor = mix(vec3(1.0), vec3(1.0, 0.3, 0.0) * 1.5, scatter);
    return mix(skyColor, vec3(scatterColor), atmosphere / 1.3);
}

vec3 getSun(vec2 uv)
{
    // Adjust mouse position to work with our coordinate system
    vec2 mousePos = vec2(u_mouse_pos.x * u_aspect, u_mouse_pos.y);
    
    float sun = 1.0 - distance(uv, mousePos);
    sun = clamp(sun, 0.0, 1.0);
    
    float glow = sun;
    glow = clamp(glow, 0.0, 1.0);
    
    sun = pow(sun, 100.0);
    sun *= 100.0;
    sun = clamp(sun, 0.0, 1.0);
    
    glow = pow(glow, 6.0) * 1.0;
    glow = pow(glow, (uv.y));
    glow = clamp(glow, 0.0, 1.0);
    
    sun *= pow(dot(uv.y, uv.y), 1.0 / 1.65);
    
    glow *= pow(dot(uv.y, uv.y), 1.0 / 2.0);
    
    sun += glow;
    
    vec3 sunColor = vec3(1.0, 0.6, 0.05) * sun;
    
    return vec3(sunColor);
}

void main()
{
    // Convert UV coordinates to match Shadertoy's coordinate system
    vec2 uv = vs_uv;
    
    // Scale UV to maintain aspect ratio like Shadertoy does with iResolution.y
    uv.x *= u_aspect;
    
    vec3 sky = getSky(uv);
    vec3 sun = getSun(uv);
    
    fs_color = vec4(sky + sun, 1.0);
}