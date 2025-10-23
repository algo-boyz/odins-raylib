#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

out vec4 fs_color;

// Gardner textured ellipsoids - https://www.cs.drexel.edu/~david/Classes/Papers/p297-gardner.pdf + bib

vec3 R = vec3(2., 4., 2.);              // ellipsoid radius
vec3 L = normalize(vec3(-.4, 0., 1.));  // light source
#define AMBIENT .4                      // ambient luminosity

#define ANIM true
#define PI 3.1415927
vec4 FragColor;

// --- noise functions from https://www.shadertoy.com/view/XslGRr
// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

mat3 m = mat3( 0.00,  0.80,  0.60,
              -0.80,  0.36, -0.48,
              -0.60, -0.48,  0.64 );

float hash( float n )    // in [0,1]
{
    return fract(sin(n)*43758.5453);
}

float noise( in vec3 x ) // in [0,1]
{
    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f*f*(3.0-2.0*f);

    float n = p.x + p.y*57.0 + 113.0*p.z;

    float res = mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
                        mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
                    mix(mix( hash(n+113.0), hash(n+114.0),f.x),
                        mix( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
    return res;
}

float fbm( vec3 p )    // in [0,1]
{
    if (ANIM) p += u_time;
    float f;
    f  = 0.5000*noise( p ); p = m*p*2.02;
    f += 0.2500*noise( p ); p = m*p*2.03;
    f += 0.1250*noise( p ); p = m*p*2.01;
    f += 0.0625*noise( p );
    return f;
}
// --- End of Created by inigo quilez

float snoise( in vec3 x ) // in [-1,1]
{ return 2.*noise(x)-1.; }

float sfbm( vec3 p )      // in [-1,1]
{
    if (ANIM) p += u_time;
    float f;
    f  = 0.5000*snoise( p ); p = m*p*2.02;
    f += 0.2500*snoise( p ); p = m*p*2.03;
    f += 0.1250*snoise( p ); p = m*p*2.01;
    f += 0.0625*snoise( p );
    return f;
}

// --- view matrix when looking T from O with [-1,1]x[-1,1] screen at dist d

mat3 lookat(vec3 O, vec3 T, float d) {
    mat3 M;
    vec3 OT = normalize(T-O);
    M[0] = OT;
    M[2] = normalize(vec3(0.,0.,1.)-OT.z*OT)/d;
    M[1] = cross(M[2],OT);
    return M;
}

// --- ray -  ellipsoid intersection
// if true, return P,N and thickness l

bool intersect_ellipsoid(vec3 O, vec3 D, out vec3 P, out vec3 N, out float l) {
    vec3 OR = O/R, DR = D/R; // to space where ellipsoid is a sphere 
        // P=O+tD & |P|=1 -> solve t in O^2 +2(O.D)t + D^2.t^2 = 1
    float OD = dot(OR,DR), OO=dot(OR,OR), DD=dot(DR,DR);
    float d = OD*OD - (OO-1.)*DD;
    
    if (!((d >=0.)&&(OD<0.)&&(OO>1.))) return false;
    // ray intersects the ellipsoid (and not in our back)
    // note that t>0 <=> -OD>0 &  OD^2 > OD^ -(OO-1.)*DD -> |O|>1
        
    float t = (-OD-sqrt(d))/DD;
    // return intersection point, normal and thickness
    P = O+t*D;
    N=normalize(P/(R*R));
    l = 2.*sqrt(d)/DD;

    return true;
}

// --- Gardner textured ellipsoids (sort of)

// 's' index corresponds to Garner faked silhouette
// 'i' index corresponds to interior term faked by mid-surface

float ks,ps, ki,pi;  // smoothness/thickness parameters

float l;
void draw_obj(vec3 O, mat3 M, vec2 pos, int mode) {
    vec3 D = normalize(M*vec3(1.,pos));     // ray
    
    vec3 P,N; 
    if (! intersect_ellipsoid(O,D, P,N,l)) return;
    
    vec3 Pm = P+.5*l*D,                     // .5: deepest point inside cloud. 
         Nm = normalize(Pm/(R*R)),          // it's normal
         Nn = normalize(P/R);
    float nl = clamp( dot(N,L),0.,1.),      // ratio of light-facing (for lighting)
          nd = clamp(-dot(Nn,D),0.,1.);     // ratio of camera-facing (for silhouette)
            // try 1.

    float ns = fbm(P), ni = fbm(Pm+10.);
    float A, l0 = 3.;
    //l += l*(l/l0-1.)/(1.+l*l/(l0*l0));     // optical depth modified at silhouette
    l = clamp(l-6.*ni,0.,1e10);
    float As = pow(ks*nd, ps),               // silhouette
          Ai = 1.-pow(.7,pi*l);              // interior

    As = clamp(As-ns,0.,1.)*2.; // As = 2.*pow(As ,.6);
    if (mode==2) 
        A = 1.- (1.-As)*(1.-Ai);            // mul Ti and Ts
    else
        A = (mode==0) ? Ai : As; 
    A = clamp(A,0.,1.); 
    nl = .8*( nl + ((mode==0) ? fbm(Pm-10.) : fbm(P+10.) ));

    #if 0 // noise bump
    N = normalize(N -.1*(dFdx(A)*M[1]+dFdy(A)*M[2])*u_resolution.y); 
    nl = clamp( dot(N,L),0.,1.);
    #endif
    
    vec4 col = vec4(mix(nl,1.,AMBIENT));
    FragColor = mix(FragColor,col,A);
}

// === main =============================================

void main() {
    float t = u_time;
    vec2 uv = 2.*(vs_uv * vec2(u_aspect, 1.0) - vec2(u_aspect * 0.5, 0.5));
    vec2 mouse = 2.*(u_mouse_pos - vec2(0.5, 0.5));
    float z = .2;
    ks = 1.+mouse.x, ps = mouse.y*8., ki, pi;
    ks = 1.; ps = 3.;   ki = .9; pi = 3.;
    
    // Mouse interaction for camera control
    if (length(u_mouse_pos - vec2(0.5)) > 0.1) {
        t = -PI/2.*mouse.x;
        z = -PI/2.*mouse.y;
    }
    
    vec3 O = vec3(-15.*cos(t)*cos(z),15.*sin(t)*cos(z),15.*sin(z)); // camera
    float compas = t-.2*uv.x; 
    vec2 dir = vec2(cos(compas),sin(compas));
    
    // Sky background (simplified - no keyboard toggle)
    FragColor = clamp(vec4(.6,.7+.3*dir,1.)*(uv.y+1.6)/1.8,0.,1.);

    mat3 M = lookat(O,vec3(0.),5.); 
    vec2 dx = vec2(1.,0.);
    
    // Always draw combined mode (simplified - no keyboard toggle)
    draw_obj(O,M, uv, 2);
    
    fs_color = FragColor; 
}