// File: assets/shader/ward_anisotropy.fs
#version 330

// Adapted from: https://www.shadertoy.com/view/MdjSzt by nmz
// An implementation of the Ward Anisotropic BRDF.

// Input varyings from the vertex shader
in vec2 vs_uv;

// Uniforms from the Go application
uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution; // <-- NEW: Shader receives screen dimensions

// Output color for the fragment
out vec4 fs_color;

const float PI = 3.14159265359;
const float FOUR_PI = 12.56637061436;

/**
 * @brief Calculates the specular reflection using the Ward Anisotropic BRDF.
 * @param vNormal The surface normal.
 * @param vDirection The direction of the anisotropy (the "brush" direction).
 * @param vEye The vector from the surface point to the camera/eye.
 * @param vLight The vector from the surface point to the light source.
 * @param Roughness A vec2 containing the roughness parameters (alpha_x, alpha_y).
 * @return The specular contribution as a float.
 */
float WardAnisotropy (in vec3 vNormal, in vec3 vDirection, in vec3 vEye, in vec3 vLight, in vec2 Roughness) 
{
    // Half-vector between light and eye
    vec3 H = normalize(vEye + vLight);
    
    // Tangent and Bitangent vectors for the anisotropic projection
    vec3 T = normalize(vDirection);
    vec3 B = normalize(cross(vNormal, T));

    float dot_ht = dot(H, T) / Roughness.x;
    float dot_hb = dot(H, B) / Roughness.y;
    float dot_hn = dot(H, vNormal);

    // Ward's formula
    float exponent = -(dot_ht*dot_ht + dot_hb*dot_hb) / (dot_hn*dot_hn);
    float numerator = exp(exponent);
    float denominator = FOUR_PI * Roughness.x * Roughness.y * sqrt(dot(vLight, vNormal) * dot(vEye, vNormal));

    return numerator / max(denominator, 0.001); // Avoid division by zero
}


void main()
{
    // --- UV & Coordinate Setup ---
    // The original shader uses non-square aspect correction. We replicate it.
    vec2 uv = vec2(vs_uv.x * u_aspect, vs_uv.y);
    
    // Centered UVs for lighting calculations
    vec2 uvl = vs_uv - 0.5;
    uvl.x *= u_aspect;

    // --- Procedural Geometry (Heightmap) ---
    // Create three circular "bumps" by calculating distance from their centers.
    float s1 = 1.0 - clamp(length(uv*4.0 - vec2(1.5, 1.2)), 0.0, 1.0);
    float s2 = 1.0 - clamp(length(uv*4.0 - vec2(5.67, 1.2)), 0.0, 1.0);
    float s3 = 1.0 - clamp(length(uv*4.0 - vec2(3.67, 2.8)), 0.0, 1.0);
    // Combine them into a single height value
    float sph = s1 + s2 + s3;
    // Create a mask for where the bumps are
    float spm = clamp(sph * 96.0, 0.0, 1.0);

    // --- Normal Calculation ---
    // Use screen-space derivatives of the heightmap to calculate normals.
    float dx = dFdx(sph) * u_resolution.x / 15.0 * spm; // <-- Use u_resolution
    float dy = dFdy(sph) * u_resolution.y / 15.0 * spm; // <-- Use u_resolution
    vec3 vNormal = normalize(vec3(dx, dy, sqrt(clamp(1.0 - dx*dx - dy*dy, 0.0, 1.0))));

    // --- Shading & Lighting ---
    // Make roughness interactive with the mouse.
    // Remap mouse [0,1] to a useful roughness range [0.01, ~0.8]
    vec2 Roughness = u_mouse_pos.xy * vec2(0.5, 0.8) + 0.01;
    if (u_mouse_pos.x == 0.0 && u_mouse_pos.y == 0.0) {
        Roughness = vec2(0.2, 0.8); // Default state
    }

    // Define different "brush" directions for the surfaces
    vec3 Dir1 = normalize(vec3(fract(uv.x*4.0)-0.5, fract(uv.y*4.0)-0.5, 0.0));
    vec3 Dir2 = normalize(vec3(0.0, 1.0, 0.0));
    vec3 Dir3 = normalize(vec3(uv.x*4.0-5.67, uv.y*4.0-1.2, 0.0));

    // Light position is animated over time
    vec3 vLight = normalize(vec3(uvl.x + (0.5 * sin(u_time)), uvl.y + (0.5 * cos(u_time)), 0.5));
    // Eye position is fixed, looking straight at the surface
    vec3 vEye = vec3(0.0, 0.0, 1.0);
    
    // Basic diffuse lighting (Lambertian)
    float sh = clamp(dot(vNormal, vLight), 0.0, 1.0);
    
    // Mix the directions based on which bump we're on
    vec3 Dir = mix(mix(Dir1, Dir2, spm), Dir3, min(s1*48.0, 1.0));
    
    // Calculate the anisotropic specular highlight
    vec3 sp = WardAnisotropy(vNormal, Dir, vEye, vLight, Roughness) * vec3(2.0); // Scaled down brightness
    
    // Combine ambient, diffuse, and specular components
    vec3 Color = vec3(0.15) + vec3(0.45)*sh + sp;
    
    fs_color = vec4(Color, 1.0);
}