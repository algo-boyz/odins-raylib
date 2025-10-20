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
// #version 330 core

// // Input vertex attributes
// in vec3 vertexPosition;
// in vec2 vertexTexCoord;

// // Output to fragment shader
// out vec2 v_tex_coord;

// void main() {
//     // Pass through texture coordinates to fragment shader
//     v_tex_coord = vertexTexCoord;
    
//     // Set vertex position (assuming fullscreen quad from -1 to 1)
//     gl_Position = vec4(vertexPosition, 1.0);
// }