#version 330 core
in vec3 fragmentPos;
in vec3 fragmentVertexNormal;
in vec2 fragmentTexCoord;

out vec4 color;

uniform vec3 lightPos;
uniform vec3 lightColor;
uniform vec3 viewPos;
uniform vec3 objectColor;
uniform float ambientStrength;
uniform float alpha;

void main()
{
    // ambient
    vec3 ambient = ambientStrength * lightColor;

    // diffuse
    vec3 norm = normalize(fragmentVertexNormal);
    vec3 lightDir = normalize(lightPos - fragmentPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;

    vec3 result = (ambient + diffuse) * objectColor;
    color = vec4(result, alpha);
}