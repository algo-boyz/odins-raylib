#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform float filterRadius;

out vec4 upsample4;

void main()
{
    // The filter kernel is applied with a radius, specified in texture
    // coordinates, so that the radius will vary across mip resolutions.
    float x = filterRadius;
    float y = filterRadius;

    // Take 9 samples around current texel:
    // a - b - c
    // d - e - f
    // g - h - i
    // === ('e' is the current texel) ===
    vec3 a = texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y + y)).rgb;
    vec3 b = texture(texture0, vec2(fragTexCoord.x,     fragTexCoord.y + y)).rgb;
    vec3 c = texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y + y)).rgb;

    vec3 d = texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y)).rgb;
    vec3 e = texture(texture0, vec2(fragTexCoord.x,     fragTexCoord.y)).rgb;
    vec3 f = texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y)).rgb;

    vec3 g = texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y - y)).rgb;
    vec3 h = texture(texture0, vec2(fragTexCoord.x,     fragTexCoord.y - y)).rgb;
    vec3 i = texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y - y)).rgb;

    // Apply weighted distribution, by using a 3x3 tent filter:
    //  1   | 1 2 1 |
    // -- * | 2 4 2 |
    // 16   | 1 2 1 |
    vec3 upsample;
    upsample = e*4.0;
    upsample += (b+d+f+h)*2.0;
    upsample += (a+c+g+i);
    upsample *= 1.0 / 16.0;
    upsample4 = vec4(upsample, 1.0);
}