#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float exposure;

out vec4 finalColor;


void main()
{
    float gamma = 2.2;
    vec3 hdrColor = texture(texture0, fragTexCoord).rgb;
    vec3 mapped = vec3(1.0) - exp(-hdrColor * exposure);
    mapped = pow(mapped, vec3(1.0/gamma));

    finalColor = vec4(mapped, 1.0);
}