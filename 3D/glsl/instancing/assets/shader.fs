#version 330

// Input
in vec3 fragNormal;
uniform vec4 colDiffuse;

// Output
out vec4 finalColor;

void main()
{
    // Simple lighting based on normal
    vec3 lightDir = normalize(vec3(0.5, 0.5, 1.0));
    float lightIntensity = max(0, dot(fragNormal, lightDir));
    vec4 color = colDiffuse * lightIntensity;
    color.a = 1.0;
    finalColor = color;
}