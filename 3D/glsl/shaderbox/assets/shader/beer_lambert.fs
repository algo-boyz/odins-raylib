// File: assets/shader/beer_lambert.fs
#version 330

// Adapted from: https://www.shadertoy.com/view/Mlc3Ds

// Input varyings from the vertex shader
in vec2 vs_uv; // Normalized coordinates [0, 1] across the plane

// Uniforms from the Go application
uniform vec2 u_mouse_pos; // Mouse position normalized to [0, 1]

// Output color for the fragment
out vec4 fs_color;

/**
 * @brief Calculates light transmittance through a medium.
 * @param sigma_t The extinction coefficient of the medium (how much it absorbs/scatters light).
 * @param d The distance the light travels through the medium.
 * @return The transmittance factor (T), from 1.0 (no extinction) to 0.0 (full extinction).
 */
float BeerLambert(float sigma_t, float d)
{
    // The core of the Beer-Lambert law: T = e^(-sigma_t * d)
    return exp(-sigma_t * d);
}

void main()
{
    // --- Control Parameters ---
    // Compute the total length 'd' of the medium using the mouse's X position.
    float d = u_mouse_pos.x * 5.0;

    // Compute the extinction coefficient 'sigma_t' using the mouse's Y position.
    // A higher value means the medium is more opaque.
    float sigma_t = u_mouse_pos.y * 20.0;

    // Use default values if the mouse hasn't been moved yet (or is at 0,0).
    // This replicates the Shadertoy preview's initial state.
    if (u_mouse_pos.x == 0.0 && u_mouse_pos.y == 0.0) {
        d = 2.0;
        sigma_t = 5.0;
    }

    // --- Calculation for the current pixel ---
    // Calculate how far this specific pixel is into the medium.
    // vs_uv.x is [0,1], so 'x' will be a value from 0 to 'd'.
    float x = vs_uv.x * d;

    // Compute the transmittance (T) for this pixel's distance 'x' into the medium.
    float T = BeerLambert(sigma_t, x);

    // --- Color Output ---
    // Convert the transmittance value (a scalar) to a grayscale color.
    vec4 color = vec4(vec3(T), 1.0);

    // Apply gamma correction to make the gradient appear more visually linear to the human eye.
    color.rgb = pow(color.rgb, vec3(1.0/2.2));

    // Set the final pixel color.
    fs_color = color;
}