/* Created by Nikita Miropolskiy, nikat/2013
 * This work is licensed under
 * Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
 * http://creativecommons.org/licenses/by-nc-sa/3.0/
 * - You must attribute the work in the source code
 * (link to https://www.shadertoy.com/view/XsX3zB).
 * - You may not use this work for commercial purposes.
 * - You may distribute a derivative work only under the same license.
 *
 * Modified to allow interactive line splitting.
 */
#version 330
// simplex.fs
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;

out vec4 fs_color;

/* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
vec3 random3(vec3 c) {
    float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
    vec3 r;
    r.z = fract(512.0*j);
    j *= .125;
    r.x = fract(512.0*j);
    j *= .125;
    r.y = fract(512.0*j);
    return r-0.5;
}

/* skew constants for 3d simplex functions */
const float F3 =  0.3333333;
const float G3 =  0.1666667;

/* 3d simplex noise */
float simplex3d(vec3 p) {
     /* 1. find current tetrahedron T and it's four vertices */
     /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
     /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/

     /* calculate s and x */
     vec3 s = floor(p + dot(p, vec3(F3)));
     vec3 x = p - s + dot(s, vec3(G3));

     /* calculate i1 and i2 */
     vec3 e = step(vec3(0.0), x - x.yzx);
     vec3 i1 = e*(1.0 - e.zxy);
     vec3 i2 = 1.0 - e.zxy*(1.0 - e);

     /* x1, x2, x3 */
     vec3 x1 = x - i1 + G3;
     vec3 x2 = x - i2 + 2.0*G3;
     vec3 x3 = x - 1.0 + 3.0*G3;

     /* 2. find four surflets and store them in d */
     vec4 w, d;

     /* calculate surflet weights */
     w.x = dot(x, x);
     w.y = dot(x1, x1);
     w.z = dot(x2, x2);
     w.w = dot(x3, x3);

     /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
     w = max(0.6 - w, 0.0);

     /* calculate surflet components */
     d.x = dot(random3(s), x);
     d.y = dot(random3(s + i1), x1);
     d.z = dot(random3(s + i2), x2);
     d.w = dot(random3(s + 1.0), x3);

     /* multiply d by w^4 */
     w *= w;
     w *= w;
     d *= w;

     /* 3. return the sum of the four surflets */
     return dot(d, vec4(52.0));
}

float simplex3d_fractal(vec3 m) {
    return   0.5333333*simplex3d(m)
            +0.2666667*simplex3d(2.0*m)
            +0.1333333*simplex3d(4.0*m)
            +0.0666667*simplex3d(8.0*m);
}

void main()
{
    vec2 p = vs_uv;
    p -= 0.5;
    p.x *= u_aspect;

    vec3 p3 = vec3(p, u_time*0.05);

    float value;

    // The original shader shows two different noise patterns.
    // We use the mouse position to interactively set the split point.
    // u_mouse_pos.x is in [0, 1] UV space. We convert it to the same coordinate space as p.x.
    float split_point = (u_mouse_pos.x - 0.5) * u_aspect; // <-- Change this line

    if (p.x <= split_point) {
        value = simplex3d(p3*32.0);
    } else {
        value = simplex3d_fractal(p3*8.0+8.0);
    }

    value = 0.5 + 0.5*value;
    
    // Draw a faint line at the split point
    value *= smoothstep(0.0, 0.005, abs(split_point-p.x));

    fs_color = vec4(vec3(value), 1.0);
}