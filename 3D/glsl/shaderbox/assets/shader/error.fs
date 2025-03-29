#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;

out vec4 fs_color;

#define E 0
#define O 1
#define R 2

float get_sd_line(vec2 p, vec2 a, vec2 b, float r) {
    vec2 ab = b - a;
    vec2 ap = p - a;
    float t = clamp(dot(ap, ab) / dot(ab, ab), 0.0, 1.0);
    return length(a + t * ab - p) - r;
}

float smin(float a, float b, float k) {
    k *= 4.0;
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * (1.0 / 4.0);
}

float smin(float a, float b) {
    float sd = smin(a, b, 0.01);
    return sd;
}

float get_sd_E(vec2 p, float r) {
    vec2 a = vec2(-0.3, -0.5); // Bottom-left
    vec2 b = vec2(-0.3, 0.5); // Top-left
    vec2 c = vec2(0.3, 0.5); // Top-right
    vec2 d = vec2(0.3, 0.3); // Top horizontal end
    vec2 e = vec2(-0.3, 0.0); // Middle horizontal start
    vec2 f = vec2(0.2, 0.0); // Middle horizontal end
    vec2 g = vec2(0.3, -0.5); // Bottom-right

    float sd = get_sd_line(p, a, b, r); // Vertical line
    sd = smin(sd, get_sd_line(p, b, c, r)); // Top horizontal
    sd = smin(sd, get_sd_line(p, e, f, r)); // Middle horizontal
    sd = smin(sd, get_sd_line(p, a, g, r)); // Bottom horizontal

    return sd;
}

float get_sd_R(vec2 p, float r) {
    // Define the vertices of a simplified R
    vec2 a = vec2(-0.3, -0.5); // Bottom-left
    vec2 b = vec2(-0.3, 0.5); // Top-left
    vec2 c = vec2(0.3, 0.5); // Top-right
    vec2 d = vec2(0.3, 0.0); // Middle-right
    vec2 e = vec2(-0.1, 0.0); // Middle-center
    vec2 f = vec2(0.3, -0.5); // Bottom-right

    // Calculate distances to each line segment
    float sd = get_sd_line(p, a, b, r); // Vertical line
    sd = smin(sd, get_sd_line(p, b, c, r)); // Top horizontal
    sd = smin(sd, get_sd_line(p, c, d, r)); // Right vertical
    sd = smin(sd, get_sd_line(p, d, e, r)); // Middle horizontal
    sd = smin(sd, get_sd_line(p, e, f, r)); // Diagonal leg

    return sd;
}

float get_sd_O(vec2 p, float r) {
    // Define the vertices of a simplified O
    vec2 a = vec2(-0.3, -0.5); // Bottom-left
    vec2 b = vec2(-0.3, 0.5); // Top-left
    vec2 c = vec2(0.3, 0.5); // Top-right
    vec2 d = vec2(0.3, -0.5); // Bottom-right

    // Calculate distances to each line segment
    float sd = get_sd_line(p, a, b, r); // Left vertical
    sd = smin(sd, get_sd_line(p, b, c, r)); // Top horizontal
    sd = smin(sd, get_sd_line(p, c, d, r)); // Right vertical
    sd = smin(sd, get_sd_line(p, d, a, r)); // Bottom horizontal

    return sd;
}

float get_sd_letter(vec2 p, int letter_idx, float r) {
    switch (letter_idx) {
        case E:
        return get_sd_E(p, r);
        case R:
        return get_sd_R(p, r);
        case O:
        return get_sd_O(p, r);
        default:
        return 10e6;
    }
}

void type_letter(inout vec2 cursor, inout float sd, int letter_idx, float r) {
    cursor.x -= 1.0;
    sd = smin(sd, get_sd_letter(cursor, letter_idx, r));
}

float attenuate(float x, float a, float b, float c) {
    return 1.0 / (a + b * x + c * x * x);
}

float get_brightness(vec2 p) {
    float x = p.x + 5.0 * sin(u_time);
    float b = attenuate(x, 0.1, 1.0, 20.0);
    return b;
}

void main() {
    vec2 p = 5.0 * ((vs_uv * 2.0) - 1.0);
    p.x *= u_aspect;

    vec2 cursor = p;
    cursor.x += 3.0;

    float r = 0.15;
    float brightness = 0.1 * get_brightness(p);

    float sd = 10e9;
    type_letter(cursor, sd, E, r);
    type_letter(cursor, sd, R, r);
    type_letter(cursor, sd, R, r);
    type_letter(cursor, sd, O, r);
    type_letter(cursor, sd, R, r);

    float t = 1.0 / pow(sin(abs(sd)), 2.5);
    vec3 color = vec3(1.0, 0.1, 0.0);
    color = t * brightness * color;

    fs_color = vec4(color, 1.0);
}

