#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec2 srcResolution;

out vec4 downsample4;


void main()
{
    vec2 srcTexelSize = 1.0 / srcResolution;
    float x = srcTexelSize.x;
    float y = srcTexelSize.y;

    // Take 13 samples around current texel:
    // a - b - c
    // - j - k -
    // d - e - f
    // - l - m -
    // g - h - i
    // === ('e' is the current texel) ===
    vec3 a = texture(texture0, vec2(fragTexCoord.x - 2*x, fragTexCoord.y + 2*y)).rgb;
    vec3 b = texture(texture0, vec2(fragTexCoord.x,       fragTexCoord.y + 2*y)).rgb;
    vec3 c = texture(texture0, vec2(fragTexCoord.x + 2*x, fragTexCoord.y + 2*y)).rgb;

    vec3 d = texture(texture0, vec2(fragTexCoord.x - 2*x, fragTexCoord.y)).rgb;
    vec3 e = texture(texture0, vec2(fragTexCoord.x,       fragTexCoord.y)).rgb;
    vec3 f = texture(texture0, vec2(fragTexCoord.x + 2*x, fragTexCoord.y)).rgb;

    vec3 g = texture(texture0, vec2(fragTexCoord.x - 2*x, fragTexCoord.y - 2*y)).rgb;
    vec3 h = texture(texture0, vec2(fragTexCoord.x,       fragTexCoord.y - 2*y)).rgb;
    vec3 i = texture(texture0, vec2(fragTexCoord.x + 2*x, fragTexCoord.y - 2*y)).rgb;

    vec3 j = texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y + y)).rgb;
    vec3 k = texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y + y)).rgb;
    vec3 l = texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y - y)).rgb;
    vec3 m = texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y - y)).rgb;

    // Apply weighted distribution:
    // 0.5 + 0.125 + 0.125 + 0.125 + 0.125 = 1
    // a,b,d,e * 0.125
    // b,c,e,f * 0.125
    // d,e,g,h * 0.125
    // e,f,h,i * 0.125
    // j,k,l,m * 0.5
    // This shows 5 square areas that are being sampled. But some of them overlap,
    // so to have an energy preserving downsample we need to make some adjustments.
    // The weights are the distributed, so that the sum of j,k,l,m (e.g.)
    // contribute 0.5 to the final color output. The code below is written
    // to effectively yield this sum. We get:
    // 0.125*5 + 0.03125*4 + 0.0625*4 = 1
    vec3 downsample;
    downsample = e*0.125;
    downsample += (a+c+g+i)*0.03125;
    downsample += (b+d+f+h)*0.0625;
    downsample += (j+k+l+m)*0.125;
    downsample4 = vec4(downsample, 1.0);
}