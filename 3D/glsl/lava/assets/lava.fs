#version 330

in vec2 fragTexCoord;
in vec3 fragNormal;

out vec4 finalColor;

uniform float time;
uniform vec4 colDiffuse;


float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}


float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.y * u.x;
}


float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 0.0;

    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void main()
{
    vec2 st = fragTexCoord * 3.0;

    vec2 q = vec2(fbm(st + vec2(0.0, 0.0)), fbm(st + vec2(5.2, 1.3)));
    vec2 r = vec2(fbm(st + q + vec2(1.7, 9.2) + 0.15 * time), fbm(st + q + vec2(8.3, 2.8) + 0.126 * time));

    float f = fbm(st + r);

    
    vec3 color1 = vec3(0.9, 0.5, 0.0);   
    vec3 color2 = vec3(0.8, 0.1, 0.0);   
    vec3 color3 = vec3(0.2, 0.0, 0.0);   

    
    vec3 color = mix(color3, color2, smoothstep(0.3, 0.6, f));
    color = mix(color, color1, smoothstep(0.6, 0.8, f));

    finalColor = vec4(color, 1.0);
}