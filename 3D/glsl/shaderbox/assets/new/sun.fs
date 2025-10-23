#version 330

// Uniforms expected by your shaderbox
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
        if (total_distance > 10.0) break;
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

// Simple noise function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(hash(i + vec2(0.0, 0.0)), 
                   hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), 
                   hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Fractal noise
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Space background
vec3 getBackground(vec3 direction) {
    return vec3(0.01, 0.01, 0.02);
}

void main() {
    // Convert from texture coordinates to screen coordinates
    vec2 uv = vs_uv * 2.0 - 1.0;
    uv.x *= u_aspect;
    uv.y *= -1.0;

    // Camera position orbiting around the sun
    vec3 origin = vec3(sin(u_time * 0.1) * 1.5, 0.0, cos(u_time * 0.1) * 1.5);

    // Camera look-at matrix
    mat3 camMat = calcLookAtMatrix(origin, vec3(0.0), 0.0);
    vec3 direction = normalize(camMat * vec3(uv, 2.0));

    // Raymarch to find intersection
    float dist = raymarch(origin, direction);

    if (dist < 0.0) {
        // Background space
        vec3 bgColor = getBackground(direction);
        fs_color = vec4(bgColor, 1.0);
    } else {
        // Hit the sun surface
        vec3 fragPosition = origin + direction * dist;
        vec3 N = getNormal(fragPosition, 0.01);
        
        // Convert to UV coordinates on sphere
        vec2 sphereUV = vec2(
            atan(N.z, N.x) / (2.0 * PI) + 0.5,
            acos(clamp(N.y, -1.0, 1.0)) / PI
        );
        
        // Animate the surface with time
        vec2 animatedUV = sphereUV + vec2(u_time * 0.02, u_time * 0.01);
        
        // Create solar surface texture
        float surface = fbm(animatedUV * 6.0);
        float granulation = fbm(animatedUV * 15.0) * 0.3;
        
        // Solar flares (occasional bright spots)
        float flare = 0.0;
        float flareNoise = fbm(animatedUV * 3.0 + u_time * 0.1);
        if (flareNoise > 0.7) {
            flare = pow((flareNoise - 0.7) / 0.3, 2.0) * 0.5;
        }
        
        // Base sun colors - realistic yellow-orange
        vec3 sunCore = vec3(1.0, 0.8, 0.6);      // Warm white-yellow
        vec3 sunHot = vec3(1.0, 0.9, 0.7);       // Hot regions
        vec3 sunCool = vec3(1.0, 0.7, 0.4);      // Cooler regions
        vec3 sunFlare = vec3(1.2, 1.0, 0.8);     // Solar flares
        
        // Mix surface colors based on noise
        vec3 surfaceColor = mix(sunCool, sunHot, surface);
        surfaceColor = mix(surfaceColor, sunCore, granulation);
        surfaceColor += sunFlare * flare;
        
        // Limb darkening - sun appears darker at edges
        float viewAngle = dot(N, -direction);
        float limbDarkening = mix(0.3, 1.0, pow(viewAngle, 0.5));
        
        // Apply limb darkening
        surfaceColor *= limbDarkening;
        
        // Edge glow effect
        float edgeGlow = pow(1.0 - viewAngle, 3.0);
        vec3 coronaGlow = vec3(1.0, 0.6, 0.3) * edgeGlow * 0.8;
        
        // Combine everything
        vec3 finalColor = surfaceColor + coronaGlow;
        
        // Tone down the intensity to prevent washout
        finalColor *= 0.9;
        
        fs_color = vec4(finalColor, 1.0);
    }
}