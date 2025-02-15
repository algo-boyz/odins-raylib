#version 330

layout(location = 0) uniform mat4 view_proj;

layout(location = 0) in vec3 v_pos;
layout(location = 1) in vec3 v_norm;
layout(location = 2) in vec3 v_uv;

layout(location = 0) out vec3 o_pos;
layout(location = 1) out vec3 o_norm;
layout(location = 2) out vec3 o_uv;

void main() {
        o_pos = v_pos;
        o_norm = v_norm;
        o_uv = v_uv;
        gl_Position = view_proj * vec4(v_pos, 1.0);
}
