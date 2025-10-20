#version 330

in vec3 vertexPosition;
uniform mat4 mvp;
out vec2 posScreen;

void main() {
    // vertexPosition         |   Object space   |   e.g. (-10 -> 10) for some random object
    // model * vertexPosition |   World space    |   e.g. (0 -> res) for a screen rect
    // mvp * vertexPosition   |   Clip space     |   (-1 -> 1) over the screen iff w = 1 
    // clip.xy / clip.w       |   NDC space      |   (-1 -> 1) over the screen
    // NDC.xy * 0.5 + 0.5     |   UV space       |   (0 -> 1) over the screen

    vec4 posClip = mvp * vec4(vertexPosition, 1.0);
    posScreen = (posClip.xy / posClip.w) * 0.5 + 0.5;
    gl_Position = posClip;
}
