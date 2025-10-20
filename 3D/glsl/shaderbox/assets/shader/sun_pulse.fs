#version 330
// sun.fs
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

// Space background with subtle stars
vec3 getBackground(vec3 direction) {
    vec3 baseColor = vec3(0.01, 0.01, 0.02);
    
    // Add some distant stars
    float starNoise = noise(direction.xy * 200.0);
    if (starNoise > 0.98) {
        float brightness = (starNoise - 0.98) / 0.02;
        baseColor += vec3(brightness * 0.5);
    }
    
    return baseColor;
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

    // Distance-based glow effect (similar to Dragon Ball)
    vec2 centerUV = (vs_uv - 0.5) * 2.0;
    float glowDistance = length(centerUV);
    float glowIntensity = max(0.0, 1.0 - glowDistance);
    
    // Enhanced glow with pulsing animation
    float glowPulse = sin(u_time * 1.5) * 0.3 + 0.7;
    vec4 distanceGlow = vec4(1.0, 0.4, 0.1, 1.0) * glowIntensity * glowIntensity * 2.5 * glowPulse;

    if (dist < 0.0) {
        // Background space with glow
        vec3 bgColor = getBackground(direction);
        
        // Apply glow to background
        fs_color = vec4(bgColor, 1.0) + distanceGlow;
    } else {
        // Hit the sun surface
        vec3 fragPosition = origin + direction * dist;
        vec3 N = getNormal(fragPosition, 0.01);
        
        // Convert to UV coordinates on sphere
        vec2 sphereUV = vec2(
            atan(N.z, N.x) / (2.0 * PI) + 0.5,
            acos(clamp(N.y, -1.0, 1.0)) / PI
        );
        
        // Multiple animation layers with different speeds and directions
        vec2 animatedUV1 = sphereUV + vec2(u_time * 0.03, u_time * 0.015);    // Main flow
        vec2 animatedUV2 = sphereUV + vec2(-u_time * 0.02, u_time * 0.025);   // Counter-rotation
        vec2 animatedUV3 = sphereUV + vec2(u_time * 0.01, -u_time * 0.01);    // Slow drift
        
        // Layered surface textures with different scales
        float surface1 = fbm(animatedUV1 * 6.0);
        float surface2 = fbm(animatedUV2 * 4.0);
        float surface3 = fbm(animatedUV3 * 8.0);
        
        // Combine surfaces for more complex patterns
        float combinedSurface = surface1 * 0.5 + surface2 * 0.3 + surface3 * 0.2;
        
        // More detailed granulation with animation
        float granulation = fbm(animatedUV1 * 15.0 + sin(u_time * 0.5) * 0.1) * 0.3;
        
        // Enhanced solar flares with time-based intensity variation
        float flareIntensity = sin(u_time * 0.8) * 0.5 + 0.5; // Pulsing intensity
        float flare = 0.0;
        float flareNoise = fbm(animatedUV2 * 3.0 + u_time * 0.15);
        if (flareNoise > 0.65) {
            flare = pow((flareNoise - 0.65) / 0.35, 2.0) * 0.6 * flareIntensity;
        }
        
        // Add magnetic field lines (darker streaks)
        float magneticLines = sin(sphereUV.y * PI * 12.0 + u_time) * 0.1;
        magneticLines *= smoothstep(0.3, 0.7, abs(sin(sphereUV.x * PI * 8.0)));
        
        // Sunspots (cooler, darker regions)
        float sunspots = fbm(sphereUV * 3.0 + u_time * 0.005);
        sunspots = smoothstep(0.6, 0.8, sunspots) * 0.4;
        
        // Base sun colors with more variation
        vec3 sunCore = vec3(1.0, 0.85, 0.65);     // Warm core
        vec3 sunHot = vec3(1.1, 0.95, 0.75);      // Hot regions
        vec3 sunCool = vec3(0.9, 0.7, 0.45);      // Cooler regions
        vec3 sunFlare = vec3(1.3, 1.1, 0.85);     // Solar flares
        vec3 sunSpot = vec3(0.4, 0.3, 0.2);       // Dark sunspots
        
        // Mix surface colors with more complexity
        vec3 surfaceColor = mix(sunCool, sunHot, combinedSurface);
        surfaceColor = mix(surfaceColor, sunCore, granulation);
        surfaceColor = mix(surfaceColor, sunSpot, sunspots);
        surfaceColor += sunFlare * flare;
        
        // Apply magnetic field darkening
        surfaceColor *= (1.0 - magneticLines * 0.3);
        
        // Enhanced limb darkening with slight color shift
        float viewAngle = dot(N, -direction);
        float limbDarkening = mix(0.25, 1.0, pow(viewAngle, 0.6));
        vec3 limbColor = mix(vec3(1.0, 0.6, 0.3), vec3(1.0), viewAngle);
        
        // Apply limb darkening with color variation
        surfaceColor *= limbDarkening * limbColor;
        
        // Enhanced edge glow with pulsing (existing corona glow)
        float edgeGlow = pow(1.0 - viewAngle, 2.5);
        float coronaGlowPulse = sin(u_time * 2.0) * 0.1 + 0.9;
        vec3 coronaGlow = vec3(1.0, 0.6, 0.3) * edgeGlow * 0.7 * coronaGlowPulse;
        
        // Add some chromatic aberration at the edges for realism
        float chromaticShift = edgeGlow * 0.1;
        coronaGlow.r += chromaticShift;
        coronaGlow.b -= chromaticShift * 0.5;
        
        // Combine surface and corona
        vec3 finalColor = surfaceColor + coronaGlow;
        
        // Subtle brightness pulsing to simulate solar activity
        float solarActivity = sin(u_time * 0.3) * 0.05 + 0.95;
        finalColor *= solarActivity;
        
        // Tone down the intensity to prevent washout
        finalColor *= 0.85;
        
        // Apply the distance-based glow effect
        fs_color = vec4(finalColor, 1.0) + distanceGlow;
    }
}