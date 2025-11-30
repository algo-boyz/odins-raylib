Shader-Based Generation: This is the most advanced suggestion. Refactor the core generation logic to use GLSL shaders.
Performance: Massively faster, allowing complex real-time manipulation of parameters with zero lag.
Flexibility: Shaders open the door to far more complex patterns, fractals, and effects than are feasible to compute on the CPU per frame.
How: You would draw a Rectangle that covers the screen and apply a custom shader to it. The gradient parameters (colors, angle, etc.) would be passed to the shader as uniforms.