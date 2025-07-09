#version 330

// Input from vertex shader
in vec2 fragTexCoord;
in vec4 fragColor; // Input color (usually white)

// Output color for the fragment
out vec4 finalColor;

// Uniforms from the application
uniform sampler2D simDataTexture; // Texture with Bed(R), Water(G), Sediment(B)
uniform vec2 textureSize;         // Dimensions (N, N)
uniform vec3 lightDirection;      // Normalized light direction vector
uniform float maxBedHeightColor;   // Max value for bed color ramp
uniform float maxWaterHeightColor; // Max value for water color ramp
uniform float maxSedimentColor;    // Max value for sediment color ramp

// Helper function for smoothstep
float smoothstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

void main()
{
    // --- Constants ---
    vec3 bedColorBase      = vec3(0.78, 0.70, 0.55); // Sandy base color
    //vec3 bedColorBase      = vec3(0.39, 0.55, 0.31); // Greenish base color
    vec3 waterColorBase    = vec3(0.20, 0.39, 0.78); // Blue base color
    float waterAlphaBase   = 0.8;                    // Max water opacity
    vec3 sedimentColorBase = vec3(0.70, 0.55, 0.31); // Muddy base color
    float sedimentAlphaBase= 0.7;                    // Max sediment opacity
    float ambientLight     = 0.4;                    // Minimum ambient light factor
    float diffuseLight     = 0.6;                    // Diffuse light contribution factor

    // --- Sample Simulation Data ---
    vec3 simData = texture(simDataTexture, fragTexCoord).rgb;
    float bedHeight = simData.r;
    float waterHeight = simData.g;
    float sedimentAmount = simData.b;

    // Prevent processing fragments outside the actual simulation area if texture coords are weird
    if (fragTexCoord.x < 0.0 || fragTexCoord.x > 1.0 || fragTexCoord.y < 0.0 || fragTexCoord.y > 1.0) {
         discard; // Don't draw pixels outside the 0-1 texture coord range
    }
    // Calculate step size for neighbor sampling
    vec2 texelSize = 1.0 / textureSize;

    // --- Calculate Bed Gradient and Shading ---
    // Sample neighbors (clamp coords to avoid wrapping issues at edges for gradient)
    vec2 coord_xp = vec2(min(fragTexCoord.x + texelSize.x, 1.0), fragTexCoord.y);
    vec2 coord_xm = vec2(max(fragTexCoord.x - texelSize.x, 0.0), fragTexCoord.y);
    vec2 coord_yp = vec2(fragTexCoord.x, min(fragTexCoord.y + texelSize.y, 1.0));
    vec2 coord_ym = vec2(fragTexCoord.x, max(fragTexCoord.y - texelSize.y, 0.0));

    float bed_xp = texture(simDataTexture, coord_xp).r;
    float bed_xm = texture(simDataTexture, coord_xm).r;
    float bed_yp = texture(simDataTexture, coord_yp).r;
    float bed_ym = texture(simDataTexture, coord_ym).r;

    // Approximate gradient (height change per texture coordinate unit)
    // Scaling factor can be added if grad needs to be physically scaled, but often not needed for shading effect
    vec2 gradient = vec2(bed_xp - bed_xm, bed_yp - bed_ym) * 0.5;

    // Calculate approximate surface normal (Z assumed up)
    // The Z component influences how steep slopes appear lit
    float slopeFactor = 5.0; // Adjust to control how much Z contributes based on slope magnitude
    vec3 normal = normalize(vec3(-gradient.x * slopeFactor, -gradient.y * slopeFactor, 1.0));

    // Calculate diffuse shading factor
    float shade = clamp(dot(normal, lightDirection), 0.0, 1.0);
    float lightingFactor = ambientLight + diffuseLight * shade;

    // --- Calculate Color Intensities ---
    float bedIntensity = smoothstep(0.0, maxBedHeightColor, bedHeight);
    float waterIntensity = smoothstep(0.0, maxWaterHeightColor, waterHeight);
    float sedimentIntensity = smoothstep(0.0, maxSedimentColor, sedimentAmount);

    // --- Determine Final Colors ---
    // Shaded Bed Color
    vec3 finalBedColor = bedColorBase * bedIntensity * lightingFactor;

    // Base result is the bed
    vec4 resultColor = vec4(finalBedColor, 1.0);

    // Blend Water if present
    if (waterHeight > 1e-4) { // Use a small threshold
        float waterAlpha = waterAlphaBase * waterIntensity; // Fade in water alpha
        // Optional: Shade water surface (similar to bed, using total height gradient)
        // float totalHeight = bedHeight + waterHeight; ... calculate totalHeight gradient ... shade water ...
        vec4 waterColor = vec4(waterColorBase * waterIntensity, waterAlpha); // Use intensity for color too
        // Alpha blending: result = mix(background, foreground, foreground.alpha)
        resultColor = mix(resultColor, waterColor, waterColor.a);

        // Blend Sediment if present (only over water)
        if (sedimentAmount > 1e-4) {
             float sedimentAlpha = sedimentAlphaBase * sedimentIntensity * waterIntensity; // Sediment needs water to be visible
             vec4 sedimentColor = vec4(sedimentColorBase * sedimentIntensity, sedimentAlpha);
             resultColor = mix(resultColor, sedimentColor, sedimentColor.a);
        }
    }

    // Apply input vertex color (usually white tint)
    finalColor = resultColor * fragColor;
}