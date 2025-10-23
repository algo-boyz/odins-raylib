#version 330 core
in vec3 fragmentPos;
in vec3 fragmentVertexNormal;
in vec2 fragmentTexCoord;

out vec4 color;

uniform vec3 lightPos;
uniform vec3 lightColor;
uniform vec3 viewPos;
uniform float ambientStrength;

void main()
{
    // Pink/salmon color for the spheres
    vec3 objectColor = vec3(1.0, 0.7, 0.8);

    // ambient
    vec3 ambient = ambientStrength * lightColor;

    // diffuse
    vec3 norm = normalize(fragmentVertexNormal);
    vec3 lightDir = normalize(lightPos - fragmentPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;

    // specular
    vec3 viewDir = normalize(viewPos - fragmentPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    vec3 specular = 0.5 * spec * lightColor;

    vec3 result = (ambient + diffuse + specular) * objectColor;
    color = vec4(result, 1.0);
}
