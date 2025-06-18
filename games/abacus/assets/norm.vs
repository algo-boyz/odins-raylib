#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec3 vertexNormal;

// Input uniform values
uniform mat4 mvp;
uniform mat4 matModel;

// Output vertex attributes (to fragment shader)
out vec3 modNorm;

void main()
{
    modNorm = vec3(vec4(vertexNormal,1)*matModel);
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}
