#version 330
// dragon_ball.fs
uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

// Input from vertex shader (your base.vs uses vs_uv)
in vec2 vs_uv;

// Output color
out vec4 fs_color;

const float PI = 3.14159265359;

// Scene function: defines a sphere with radius (height)
float scene(vec3 position) {
    float height = 0.3;
    return length(position) - height;
}

// Calculate normal at a point on the surface
vec3 getNormal(vec3 pos, float smoothness) {	
    vec3 n;
    vec2 dn = vec2(smoothness, 0.0);
    n.x = scene(pos + dn.xyy) - scene(pos - dn.xyy);
    n.y = scene(pos + dn.yxy) - scene(pos - dn.yxy);
    n.z = scene(pos + dn.yyx) - scene(pos - dn.yyx);
    return normalize(n);
}

// Raymarching function
float raymarch(vec3 position, vec3 direction) {
    float total_distance = 0.0;
    for (int i = 0; i < 32; ++i) {
        float result = scene(position + direction * total_distance);
        if (result < 0.005) {
            return total_distance;
        }
        total_distance += result;
        if (total_distance > 10.0) break; // Add max distance check
    }
    return -1.0;
}

// Look-at matrix for camera orientation
mat3 calcLookAtMatrix(vec3 ro, vec3 ta, float roll) {
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(sin(roll), cos(roll), 0.0)));
    vec3 vv = normalize(cross(uu, ww));
    return mat3(uu, vv, ww);
}

// Simple procedural background
vec3 getBackground(vec3 direction) {
    // Create a simple starfield background
    float stars = 0.0;
    vec2 st = vec2(atan(direction.z, direction.x) / (2.0 * PI) + 0.5, 
                   acos(direction.y) / PI);
    
    // Add some stars
    vec2 grid = fract(st * 50.0);
    if (length(grid - 0.5) < 0.05) {
        stars = 1.0;
    }
    
    // Space gradient
    vec3 spaceColor = mix(vec3(0.01, 0.01, 0.05), vec3(0.05, 0.02, 0.1), 
                         abs(direction.y));
    return spaceColor + stars * vec3(1.0, 0.8, 0.6);
}

void main() {
    // Convert from texture coordinates to screen coordinates
    vec2 uv = vs_uv * 2.0 - 1.0;
    uv.x *= u_aspect;
    uv.y *= -1.0; // Flip Y to match expected orientation

    // Camera position orbiting around origin
    vec3 origin = vec3(sin(u_time * 0.1) * 2.5, 0.0, cos(u_time * 0.1) * 2.5);

    // Camera look-at matrix
    mat3 camMat = calcLookAtMatrix(origin, vec3(0.0), 0.0);
    vec3 direction = normalize(camMat * vec3(uv, 2.5));

    // Raymarch to find intersection
    float dist = raymarch(origin, direction);

    if (dist < 0.0) {
        // Background
        vec3 bgColor = getBackground(direction);
        fs_color = vec4(bgColor, 1.0);
    } else {
        // Hit the sphere
        vec3 fragPosition = origin + direction * dist;
        vec3 N = getNormal(fragPosition, 0.01);
        vec4 ballColor = vec4(1.0, 0.8, 0.0, 1.0) * 0.75;
        vec3 ref = reflect(direction, N);

        // Star effect on the ball surface
        vec2 sphereUV = vec2(atan(N.z, N.x) / (2.0 * PI) + 0.5, 
                            acos(N.y) / PI);
        float P = PI / 5.0;
        float angle = atan(sphereUV.y - 0.5, sphereUV.x - 0.5);
        float starVal = (1.0 / P) * (P - abs(mod(angle + PI, (2.0 * P)) - P));
        float starRadius = length(sphereUV - 0.5);
        vec4 starColor = (starRadius < 0.15 - (starVal * 0.08)) ? 
                        vec4(2.8, 1.0, 0.0, 1.0) : vec4(0.0);

        // Rim lighting
        float rim = max(0.0, (0.7 + dot(N, direction)));

        // Refraction effect
        vec3 refr = refract(direction, N, 0.7);
        
        // Simple reflection and refraction colors
        vec3 reflectColor = getBackground(ref);
        vec3 refractColor = getBackground(refr);
        
        // Glow effect based on distance from center
        vec2 centerUV = (vs_uv - 0.5) * 2.0;
        float glowIntensity = max(0.0, 1.0 - length(centerUV));
        vec4 glowColor = vec4(0.6, 0.2, 0.0, 1.0) * glowIntensity * 4.0 * 
                        (0.2 + abs(sin(u_time)) * 0.8);

        // Combine all effects
        fs_color = vec4(refractColor, 1.0) * ballColor +
                   starColor +
                   vec4(reflectColor, 1.0) * 0.3 +
                   glowColor +
                   vec4(rim, rim * 0.5, 0.0, 1.0);
    }
}