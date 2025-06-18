#version 330

in vec3 modNorm;

out vec4 finalColor;

void main()
{
    finalColor = vec4(modNorm,1);
}
