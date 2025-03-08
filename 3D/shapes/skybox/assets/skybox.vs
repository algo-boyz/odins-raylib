#version 330

// Input vertex attributes
in vec3 vertexPosition;

// Input uniform values
uniform mat4 matProjection;
uniform mat4 matView;

// Output vertex attributes (to fragment shader)
out vec3 fragPosition;

void main()
{
    // Send original vertex position to fragment shader
    fragPosition = vertexPosition;
    
    // Use the vertex position as the texture coordinate
    // Remove translation from the view matrix (only keep rotation)
    mat4 rotView = mat4(mat3(matView));
    
    // Use infinitely far projection for skybox
    gl_Position = matProjection * rotView * vec4(vertexPosition, 1.0);
    
    // Force skybox to be rendered at maximum depth
    gl_Position = gl_Position.xyww;
}