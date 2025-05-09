#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

// Output attributes to fragment shader
out vec2 fragTexCoord;
out vec4 fragColor;

// Uniforms provided by Raylib
uniform mat4 mvp; // Model-View-Projection matrix

void main()
{
    // Pass texture coordinate and color to fragment shader
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    // Calculate final vertex position
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}