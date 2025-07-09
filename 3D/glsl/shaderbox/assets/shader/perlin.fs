#version 330
in vec2 vs_uv;

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;

out vec4 fs_color;

/**
 * Linearly Re-maps a value from one range to another
 */
float map(float value, float old_lo, float old_hi, float new_lo, float new_hi)
{
	float old_range = old_hi - old_lo;
    if (old_range == 0.0) {
        return new_lo;
	} else {
        float new_range = new_hi - new_lo;
        return (((value - old_lo) * new_range) / old_range) + new_lo;
	}
}

/**
 * The canonical GLSL hash function
 */
float hash(float x)
{
	return fract(sin(x) * 43758.5453123);
}

/** 
 * Nothing is mathematically sound about anything below: 
 * I just chose values based on experimentation and some 
 * intuitions I have about what makes a good hash function
 */
vec3 gradient(vec3 cell)
{
	float h_i = hash(cell.x);
	float h_j = hash(cell.y + pow(h_i, 3.0));
	float h_k = hash(cell.z + pow(h_j, 5.0));
    float ii = map(fract(h_i + h_j + h_k), 0.0, 1.0, -1.0, 1.0);
    float jj = map(fract(h_j + h_k), 0.0, 1.0, -1.0, 1.0);
	float kk = map(h_k, 0.0, 1.0, -1.0, 1.0);
    return normalize(vec3(ii, jj, kk));
}

/**
 * Perlin's "ease-curve" fade function
 */
float fade(float t)
{
    float t3 = t * t * t;
    float t4 = t3 * t;
    float t5 = t4 * t;
    return (6.0 * t5) - (15.0 * t4) + (10.0 * t3);
}

/**
 * The meat of it:
 *
 * It helps to visualize the unit cube:
 *
 *      (0,1,1)----------------(1,1,1)
 *        /|                     /|
 *       / |                    / |
 *      /  |                   /  |
 *     /   |                  /   |
 * (0,1,0)-+--------------(1,1,0) |
 *    |    |                 |    |
 *    |    |                 |    |
 *    |    |                 |    |
 *    | (0,0,1)--------------+-(1,0,1)
 *    |   /                  |   /
 *    |  /                   |  /
 *    | /                    | /
 *    |/                     |/ 
 * (0,0,0)----------------(1,0,0)
 */
float noise(in vec3 coord)
{
    vec3 cell = floor(coord);
    vec3 unit = fract(coord);

    vec3 unit_000 = unit;
    vec3 unit_100 = unit - vec3(1.0, 0.0, 0.0);
    vec3 unit_001 = unit - vec3(0.0, 0.0, 1.0);
    vec3 unit_101 = unit - vec3(1.0, 0.0, 1.0);
    vec3 unit_010 = unit - vec3(0.0, 1.0, 0.0);
    vec3 unit_110 = unit - vec3(1.0, 1.0, 0.0);
    vec3 unit_011 = unit - vec3(0.0, 1.0, 1.0);
    vec3 unit_111 = unit - 1.0;

    vec3 c_000 = cell;
    vec3 c_100 = cell + vec3(1.0, 0.0, 0.0);
    vec3 c_001 = cell + vec3(0.0, 0.0, 1.0);
    vec3 c_101 = cell + vec3(1.0, 0.0, 1.0);
    vec3 c_010 = cell + vec3(0.0, 1.0, 0.0);
    vec3 c_110 = cell + vec3(1.0, 1.0, 0.0);
    vec3 c_011 = cell + vec3(0.0, 1.0, 1.0);
    vec3 c_111 = cell + 1.0;

    float wx = fade(unit.x);
    float wy = fade(unit.y);
    float wz = fade(unit.z);

    float x000 = dot(gradient(c_000), unit_000);
	float x100 = dot(gradient(c_100), unit_100);
	float x001 = dot(gradient(c_001), unit_001);
	float x101 = dot(gradient(c_101), unit_101);
	float x010 = dot(gradient(c_010), unit_010);
	float x110 = dot(gradient(c_110), unit_110);
	float x011 = dot(gradient(c_011), unit_011);
	float x111 = dot(gradient(c_111), unit_111);

    // (0,0,0) - (1,0,0)
    // (0,0,1) - (1,0,1)
    // (0,1,0) - (1,1,0)
    // (0,1,1) - (1,1,1)
    float y0 = mix(x000, x100, wx);
    float y1 = mix(x001, x101, wx);
    float y2 = mix(x010, x110, wx);
    float y3 = mix(x011, x111, wx);

	float z0 = mix(y0, y2, wy);
    float z1 = mix(y1, y3, wy);

    return mix(z0, z1, wz);
}	

void main()
{
    vec2 p = vs_uv - 0.5;
    p.x *= u_aspect;

    // A small epsilon to prevent division by zero
    float freq = 1.0 / 64.0;
    if (u_mouse_pos.y > 0.001) { 
        freq = 1.0 / (u_mouse_pos.y * 200.0);
    }
    float blendAmount = u_mouse_pos.x;

    vec3 coord = vec3(p.xy * 25.0, u_time * 0.75);
    float v = noise(coord * freq);

    float v_0 = map(v, -1.0, 1.0, 0.0, 1.0);
    float v_1 = 1.0 - abs(v);
    float v_p = mix(v_0, v_1, blendAmount);

    fs_color = vec4(v_p, v_p, v_p, 1.0);
}