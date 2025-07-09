package main

import "base:runtime"
import "core:math"
import "core:math/rand"
import "core:sync"
import "core:slice"
import rl "vendor:raylib"
import "../../../../../rlutil/fibr"

WIDTH  :: 800
HEIGHT :: 800
NUM_PARTICLES :: 100000
NUM_THREADS :: 6

Particle :: struct {
    pos, vel:   rl.Vector2,
    color: 		rl.Color,
}

// Shared data structure for worker threads
WorkerData :: struct {
    screen_width, screen_height:  f32,
    mouse_pos:     				  rl.Vector2,
    barrier:       				  ^sync.Barrier,
	particles:     				  []Particle,
    start_idx, end_idx:     	  int
}

particle_new :: proc(screen_width, screen_height: i32) -> Particle {
    return Particle{
        pos = {
            f32(rand.int31_max(screen_width)),
            f32(rand.int31_max(screen_height)),
        },
        vel = {
            f32(rand.int31_max(201) - 100) / 100.0,
            f32(rand.int31_max(201) - 100) / 100.0,
        },
        color = {
            u8(rand.int31_max(255)),
            u8(rand.int31_max(255)),
            u8(rand.int31_max(255)),
            150
        },
    }
}

particle_get_dist :: proc(p: ^Particle, other_pos: rl.Vector2) -> f32 {
    dx := p.pos.x - other_pos.x
    dy := p.pos.y - other_pos.y
    return math.sqrt(dx*dx + dy*dy)
}

particle_get_normal :: proc(p: ^Particle, other_pos: rl.Vector2) -> rl.Vector2 {
    dist := particle_get_dist(p, other_pos)
    if dist == 0.0 do dist = 1.0
    
    dx := p.pos.x - other_pos.x
    dy := p.pos.y - other_pos.y
    
    return {dx * (1.0/dist), dy * (1.0/dist)}
}

particle_attract :: proc(p: ^Particle, pos_to_attract: rl.Vector2, multiplier: f32) {
    dist := max(particle_get_dist(p, pos_to_attract), 0.5)
    normal := particle_get_normal(p, pos_to_attract)
    
    p.vel.x -= normal.x / dist
    p.vel.y -= normal.y / dist
}

particle_do_friction :: proc(p: ^Particle, amount: f32) {
    p.vel.x *= amount
    p.vel.y *= amount
}

particle_move :: proc(p: ^Particle, width, height: f32) {
    p.pos.x += p.vel.x
    p.pos.y += p.vel.y
    
    if p.pos.x < 0 {
        p.pos.x += width
    }
    if p.pos.x >= width {
        p.pos.x -= width
    }
    if p.pos.y < 0 {
        p.pos.y += height
    }
    if p.pos.y >= height {
        p.pos.y -= height
    }
}

// Worker thread function
particle_worker :: proc(arg: rawptr) {
    data := cast(^WorkerData)arg
    for {
        sync.barrier_wait(data.barrier)
        if data.mouse_pos.x < 0 do break
        
        for i in data.start_idx..<data.end_idx {
            particle_attract(&data.particles[i], data.mouse_pos, 1.0)
            particle_do_friction(&data.particles[i], 0.99)
            particle_move(&data.particles[i], data.screen_width, data.screen_height)
        }
        sync.barrier_wait(data.barrier)
    }
}

// Simple batch rendering using Raylib's drawing functions
render_particles_batch :: proc(particles: []Particle, batch_size: int = 10000) {
    // Enable blending for transparent particles
    rl.BeginBlendMode(.ALPHA)
    
    // Render particles in batches to avoid overwhelming the GPU
    for i := 0; i < len(particles); i += batch_size {
        end_idx := min(i + batch_size, len(particles))
        
        for j in i..<end_idx {
            p := &particles[j]
            // Draw as small circles with soft edges
            rl.DrawCircleV(p.pos, 2.0, p.color)
        }
    }
    
    rl.EndBlendMode()
}

// Alternative: Use a texture and draw textured rectangles for better performance
TexturedParticleSystem :: struct {
    texture: rl.Texture2D,
    shader:  rl.Shader,
}

init_textured_particles :: proc(system: ^TexturedParticleSystem) {
    // Create a simple circular particle texture
    image := rl.GenImageColor(16, 16, rl.BLANK)
    defer rl.UnloadImage(image)
    
    // Draw a circle on the image
    for y in 0..<16 {
        for x in 0..<16 {
            dx := f32(x - 8)
            dy := f32(y - 8)
            dist := math.sqrt(dx*dx + dy*dy)
            
            if dist <= 6.0 {
                alpha := u8(255 * (1.0 - dist / 6.0))
                color := rl.Color{255, 255, 255, alpha}
                rl.ImageDrawPixel(&image, i32(x), i32(y), color)
            }
        }
    }
    
    system.texture = rl.LoadTextureFromImage(image)
    
    // Simple shader for particle rendering
    vertex_shader :: `
    #version 330
    in vec3 vertexPosition;
    in vec2 vertexTexCoord;
    in vec4 vertexColor;
    uniform mat4 mvp;
    out vec2 fragTexCoord;
    out vec4 fragColor;
    void main() {
        fragTexCoord = vertexTexCoord;
        fragColor = vertexColor;
        gl_Position = mvp*vec4(vertexPosition, 1.0);
    }
    `
    
    fragment_shader :: `
    #version 330
    in vec2 fragTexCoord;
    in vec4 fragColor;
    uniform sampler2D texture0;
    out vec4 finalColor;
    void main() {
        vec4 texelColor = texture(texture0, fragTexCoord);
        finalColor = fragColor * texelColor;
    }
    `
    
    system.shader = rl.LoadShaderFromMemory(vertex_shader, fragment_shader)
}

render_textured_particles :: proc(system: ^TexturedParticleSystem, particles: []Particle) {
    rl.BeginShaderMode(system.shader)
    rl.BeginBlendMode(.ALPHA)
    
    // Draw each particle as a textured rectangle
    for p in particles {
        dest := rl.Rectangle{p.pos.x - 2, p.pos.y - 2, 4, 4}
        source := rl.Rectangle{0, 0, f32(system.texture.width), f32(system.texture.height)}
        rl.DrawTexturePro(system.texture, source, dest, {0, 0}, 0, p.color)
    }
    
    rl.EndBlendMode()
    rl.EndShaderMode()
}

cleanup_textured_particles :: proc(system: ^TexturedParticleSystem) {
    rl.UnloadTexture(system.texture)
    rl.UnloadShader(system.shader)
}

main :: proc() {
    particles := make([]Particle, NUM_PARTICLES)
    defer delete(particles)
    
    // Initialize particles with more colorful palette
    for i in 0..<NUM_PARTICLES {
        particles[i] = particle_new(WIDTH, HEIGHT)
    }
    
    // Set up threading
    threads := make([]fibr.Thread, NUM_THREADS)
    defer delete(threads)
    
    worker_data := make([]WorkerData, NUM_THREADS)
    defer delete(worker_data)
    
    // Create barrier for synchronization
    barrier: sync.Barrier
	sync.barrier_init(&barrier, NUM_THREADS + 1)
    
    // Calculate work distribution
    particles_per_thread := NUM_PARTICLES / NUM_THREADS
    remainder := NUM_PARTICLES % NUM_THREADS
    
    // Initialize worker data and spawn threads
    for i in 0..<NUM_THREADS {
        start_idx := i * particles_per_thread
        end_idx := start_idx + particles_per_thread
        
        if i < remainder {
            start_idx += i
            end_idx += i + 1
        } else {
            start_idx += remainder
            end_idx += remainder
        }
        
        worker_data[i] = WorkerData{
            particles = particles,
            start_idx = start_idx,
            end_idx = end_idx,
            barrier = &barrier,
        }
        fibr.spawn(&threads[i], particle_worker, &worker_data[i])
    }
    
    rl.InitWindow(WIDTH, HEIGHT, "Raylib Particle System")
    rl.SetTargetFPS(60)
    
    // Initialize textured particle system for better performance
    textured_system: TexturedParticleSystem
    init_textured_particles(&textured_system)
    defer cleanup_textured_particles(&textured_system)
    
    use_textured_rendering := true
    
    for !rl.WindowShouldClose() {
        mouse_pos := rl.GetMousePosition()
        
        // Toggle rendering method with SPACE key
        if rl.IsKeyPressed(.SPACE) {
            use_textured_rendering = !use_textured_rendering
        }
        
        // Update shared data for all workers
        for i in 0..<NUM_THREADS {
            worker_data[i].mouse_pos = mouse_pos
            worker_data[i].screen_width = WIDTH
            worker_data[i].screen_height = HEIGHT
        }
        
        // Signal workers to start processing
        sync.barrier_wait(&barrier)
        
        // Wait for all workers to finish
        sync.barrier_wait(&barrier)
        
        // Render
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        if use_textured_rendering {
            render_textured_particles(&textured_system, particles)
        } else {
            render_particles_batch(particles, 5000)
        }
        
        rl.DrawFPS(10, 10)
        rl.DrawText("Raylib Particle System", 10, 30, 20, rl.WHITE)
        fps_text := rl.TextFormat("100K particles - FPS: %d", rl.GetFPS())
        rl.DrawText(fps_text, 10, 50, 16, rl.LIME)
        
        render_method := use_textured_rendering ? "Textured" : "Batch Circles"
        method_text := rl.TextFormat("Method: %s (Press SPACE to toggle)", render_method)
        rl.DrawText(method_text, 10, 70, 16, rl.YELLOW)
        
        rl.EndDrawing()
    }
    
    // Signal workers to exit
    for i in 0..<NUM_THREADS {
        worker_data[i].mouse_pos = {-1, -1}
    }
    sync.barrier_wait(&barrier)
    
    // Wait for all threads to finish
    for i in 0..<NUM_THREADS {
        fibr.join(&threads[i])
    }
    
    rl.CloseWindow()
}