package main

import "core:fmt"
import "core:math"
import "core:math/rand"

import rl "vendor:raylib"
import gl "vendor:OpenGL"

PARTICLE_VERTEX_SHADER :: "assets/vertex.glsl"
PARTICLE_FRAGMENT_SHADER :: "assets/fragment.glsl"
PARTICLE_COMPUTE_SHADER :: "assets/ompute.glsl"

Particle :: struct {
    position: [4]f32,
    velocity: [4]f32,
}

get_random_float :: proc(from, to: f32) -> f32 {
    return from + (to - from) * rand.float32()
}

main :: proc() {
    rl.InitWindow(800, 800, "GPU Particles")
    defer rl.CloseWindow()

    // Compute shader setup
    compute_shader := rl.LoadComputeShader(PARTICLE_COMPUTE_SHADER)
    particle_shader := rl.LoadShader(
        PARTICLE_VERTEX_SHADER, 
        PARTICLE_FRAGMENT_SHADER
    )

    NUM_PARTICLES :: 1024 * 100
    particles := make([]Particle, NUM_PARTICLES)
    defer delete(particles)

    // Initialize particles
    for &p in particles {
        p.position = {
            get_random_float(-0.5, 0.5),
            get_random_float(-0.5, 0.5),
            get_random_float(-0.5, 0.5),
            0,
        }
        p.velocity = {0, 0, 0, 0}
    }

    // Buffer setup (simplified OpenGL buffer creation)
    particle_buffer: u32
    gl.GenBuffers(1, &particle_buffer)
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, particle_buffer)
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(Particle) * NUM_PARTICLES, raw_data(particles), gl.DYNAMIC_DRAW)

    // Triangle vertices for particle rendering
    vertices := [][3]f32{
        {-0.86, -0.5, 0.0},
        { 0.86, -0.5, 0.0},
        { 0.0,   1.0, 0.0},
    }

    // Camera and simulation parameters
    camera := rl.Camera{
        position   = {2, 2, 2},
        target     = {0, 0, 0},
        up         = {0, 1, 0},
        fovy       = 35.0,
        projection = .PERSPECTIVE,
    }

    time: f32
    time_scale: f32 = 0.2
    sigma: f32 = 10
    rho: f32 = 28
    beta: f32 = 8.0/3.0
    particle_scale: f32 = 1.0
    instances_x1000: f32 = 100.0

    for !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        num_instances := i32(instances_x1000 / 1000 * NUM_PARTICLES)

        rl.UpdateCamera(&camera, .ORBITAL)

        // Compute pass (simplified)
        rl.SetShaderValue(compute_shader, 0, &time, .FLOAT)
        rl.SetShaderValue(compute_shader, 1, &time_scale, .FLOAT)
        rl.SetShaderValue(compute_shader, 2, &delta_time, .FLOAT)
        rl.SetShaderValue(compute_shader, 3, &sigma, .FLOAT)
        rl.SetShaderValue(compute_shader, 4, &rho, .FLOAT)
        rl.SetShaderValue(compute_shader, 5, &beta, .FLOAT)

        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.BeginMode3D(camera)
        
        // Draw particles
        rl.BeginShaderMode(particle_shader)
        
        projection := rl.GetMatrixProjection()
        view := rl.GetCameraMatrix(camera)

        rl.SetShaderValueMatrix(particle_shader, 0, projection)
        rl.SetShaderValueMatrix(particle_shader, 1, view)
        rl.SetShaderValue(particle_shader, 2, &particle_scale, .FLOAT)

        // GUI controls
        rl.GuiSlider(
            {550, 10, 200, 10}, 
            "Particles x1000", 
            fmt.ctprintf("%.2f", instances_x1000), 
            &instances_x1000, 0, 1000
        )
        rl.GuiSlider(
            {550, 25, 200, 10}, 
            "Particle Scale", 
            fmt.ctprintf("%.2f", particle_scale), 
            &particle_scale, 0, 5
        )

        time += delta_time

        rl.DrawFPS(10, 10)
        rl.EndMode3D()
        rl.EndDrawing()
    }
}