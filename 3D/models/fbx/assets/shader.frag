#version 330

layout(location = 0) in vec3 v_pos;
layout(location = 1) in vec3 v_norm;
layout(location = 2) in vec3 v_uv;

layout(location = 0) out vec4 color;

void main() {
        color = vec4(0.5 * v_norm + 0.5, 1.0);
}
