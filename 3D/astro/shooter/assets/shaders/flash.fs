#version 330

in vec2 fragTexCoord;
in vec4 fragColor; 

uniform sampler2D texture0;
uniform vec2 flash = vec2(0.0,0.0);

out vec4 finalColor;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    finalColor = mix(texelColor, vec4(1.0, 1.0, 1.0, texelColor.a), flash.x);
}