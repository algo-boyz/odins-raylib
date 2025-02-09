#version 330

// Input vertex attributes (from vertex shader)
in vec3 vertexPos;
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform sampler2D texture1;
uniform vec4 colDiffuse;

uniform float divider = 0.5;

out vec4 finalColor;

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor0 = texture(texture0, fragTexCoord);
    vec4 texelColor1 = texture(texture1, fragTexCoord);

    float x = fract(fragTexCoord.s);
    float final = smoothstep(divider - 0.1, divider + 0.1, x);

    finalColor = mix(texelColor0, texelColor1, final);
}
// #version 330

// in vec2 fragTexCoord;
// in vec4 fragColor;

// uniform sampler2D texture0;  // Blue texture
// uniform sampler2D texture1;  // Invasion progress texture
// uniform float divider = 0.5;

// out vec4 finalColor;

// void main()
// {
//     vec4 baseColor = texture(texture0, fragTexCoord);    // Blue color
//     vec4 maskColor = texture(texture1, fragTexCoord);    // Invasion mask
    
//     // Use the accumulated brightness from the invasion mask
//     float mixFactor = clamp(maskColor.r + maskColor.g + maskColor.b, 0.0, 1.0);
//     float x = fract(fragTexCoord.s);
//     float final = smoothstep(divider - 0.1, divider + 0.1, x);

//     // Mix between black and blue based on the invasion progress
//     finalColor = mix(baseColor, maskColor, final);
// }