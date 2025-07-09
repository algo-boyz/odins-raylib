// base.vs
#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;

uniform mat4 mvp;

out vec2 vs_uv;

void main() {
    vs_uv = vertexTexCoord;
    vs_uv.y = 1.0 - vs_uv.y;

    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
