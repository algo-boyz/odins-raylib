#version 330

in vec2 vUV;
out vec4 FragColor;

uniform sampler2D tex;
uniform sampler2D bloomTex;
uniform sampler2D stripeTex;
uniform float ditherMagnitude;
uniform float time;
uniform vec3 backgroundColor, cursorColor, glintColor;
uniform float cursorIntensity, glintIntensity;

#define PI 3.14159265359

float rand(const in vec2 uv, const in float t) {
    const float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot(uv.xy, vec2(a, b)), sn = mod(dt, PI);
    return fract(sin(sn) * c + t);
}

vec4 getBrightness(vec2 uv) {
    vec4 primary = texture(tex, uv);
    vec4 bloom = texture(bloomTex, uv);
    return primary + bloom;
}

void main() {
    vec3 color = texture(stripeTex, vUV).rgb;

    vec4 brightness = getBrightness(vUV);

    // Dither: subtract a random value from the brightness
    brightness -= rand(gl_FragCoord.xy, time) * ditherMagnitude / 3.0;
    
    FragColor = vec4(
        color * brightness.r
            + min(cursorColor * cursorIntensity * brightness.g, vec3(1.0))
            + min(glintColor * glintIntensity * brightness.b, vec3(1.0))
            + backgroundColor,
        1.0
    );
}