#version 330

uniform sampler2D texture0;
uniform sampler2D texture1;

in vec2 fragTexCoord;

out vec4 finalColor;

void main()
{
    vec4 screen = texture(texture0, fragTexCoord);
    vec4 mask = texture(texture1, fragTexCoord);

    finalColor = screen * mask.r;
}