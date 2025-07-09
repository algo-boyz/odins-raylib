#version 330

// Input
in vec3 vertexPosition;
in vec3 vertexNormal;
in mat4 instanceMatrix;
uniform mat4 projectionMatrix;

// Output
out vec3 fragNormal;

void main()
{
    // send data to fragment
    fragNormal = vertexNormal;

    // Calculate projected instance vertex position
    mat4 mvpi = projectionMatrix * instanceMatrix;
    vec4 pos = mvpi * vec4(vertexPosition, 1.0);
    gl_Position = pos;
}