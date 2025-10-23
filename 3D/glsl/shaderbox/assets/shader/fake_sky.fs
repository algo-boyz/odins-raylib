#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

out vec4 fs_color;

vec3 skyColor( in vec3 rd )
{
    vec3 sundir = normalize( vec3(.0, .1, 1.) );
    
    float yd = min(rd.y, 0.);
    rd.y = max(rd.y, 0.);
    
    vec3 col = vec3(0.);
    
    col += vec3(.4, .4 - exp( -rd.y*20. )*.15, .0) * exp(-rd.y*9.); // Red / Green 
    col += vec3(.3, .5, .6) * (1. - exp(-rd.y*8.) ) * exp(-rd.y*.9) ; // Blue
    
    col = mix(col*1.2, vec3(.3),  1.-exp(yd*100.)); // Fog
    
    col += vec3(1.0, .8, .55) * pow( max(dot(rd,sundir),0.), 15. ) * .6; // Sun
    col += pow(max(dot(rd, sundir),0.), 150.0) *.15;
    
    return col;
}

float checker( vec2 p )
{
    p = mod(floor(p),2.0);
    return mod(p.x + p.y, 2.0) < 1.0 ? .25 : 0.1;
}

void main()
{
    // Screen coords - convert from vs_uv to Shadertoy-style coordinates
    vec2 q = vs_uv;
    vec2 v = -1.0 + 2.0 * q;
    v.x *= u_aspect;
    
    // Camera ray
    vec3 dir = normalize( vec3(v.x, v.y + .5, 1.5) );
    
    // Scene
    vec3 col = vec3( checker(dir.xz/dir.y*.5 + vec2(0., -u_time*2.)) ) + skyColor(reflect(dir, vec3(0., 1., 0.))) * .3;
    col = mix(col, skyColor(dir), exp(-max(-v.y*9.-4.8, 0.)) );
    
    // Vignetting
    col *= .7 + .3*pow(q.x*q.y*(1.-q.x)*(1.-q.y)*16., .1);
    
    fs_color = vec4( col, 1.);
}