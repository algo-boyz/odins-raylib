package main

import "base:runtime"
import "core:math"
import "core:math/rand"
import "core:sync"
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

// Rendering data structures
RenderBatch :: struct {
    positions: []rl.Vector2,
    colors:    []rl.Color,
    count:     int,
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
        color = {0, 0, 0, 100},
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

// Method 1: Batch pixel drawing
draw_particles_batched_pixels :: proc(particles: []Particle) {
    // Group particles by color for better batching
    color_groups := make(map[u32][dynamic]rl.Vector2)
    defer {
        for _, positions in color_groups {
            delete(positions)
        }
        delete(color_groups)
    }
    for particle in particles {
        color_key := u32(particle.color.r) << 24 | u32(particle.color.g) << 16 | u32(particle.color.b) << 8 | u32(particle.color.a)
        if color_key not_in color_groups {
            color_groups[color_key] = make([dynamic]rl.Vector2, 0, 1000)
        }
        append(&color_groups[color_key], particle.pos)
    }
    // Draw each color group in one batch
    for color_key, positions in color_groups {
        color := rl.Color{
            u8((color_key >> 24) & 0xFF),
            u8((color_key >> 16) & 0xFF),
            u8((color_key >> 8) & 0xFF),
            u8(color_key & 0xFF),
        }
        // Use DrawPixelV for each position (still individual calls but grouped by color)
        for pos in positions {
            rl.DrawPixelV(pos, color)
        }
    }
}

// Method 2: Use rectangles for slightly larger particles
draw_particles_as_rects :: proc(particles: []Particle) {
    particle_size: f32 = 2.0
    for particle in particles {
        rl.DrawRectangleV(
            {particle.pos.x - particle_size/2, particle.pos.y - particle_size/2},
            {particle_size, particle_size},
            particle.color
        )
    }
}

// Method 3: Use a texture and instanced drawing
draw_particles_instanced :: proc(particles: []Particle, particle_texture: rl.Texture2D) {
    // This would require custom shader support in Raylib
    // For now, we'll simulate with optimized texture drawing
    scale: f32 = 0.1 // Scale down the texture
    for particle in particles {
        dest_rect := rl.Rectangle{
            x = particle.pos.x - f32(particle_texture.width) * scale / 2,
            y = particle.pos.y - f32(particle_texture.height) * scale / 2,
            width = f32(particle_texture.width) * scale,
            height = f32(particle_texture.height) * scale,
        }
        source_rect := rl.Rectangle{
            x = 0, y = 0,
            width = f32(particle_texture.width),
            height = f32(particle_texture.height),
        }
        rl.DrawTexturePro(
            particle_texture,
            source_rect,
            dest_rect,
            {0, 0}, // origin
            0,      // rotation
            particle.color
        )
    }
}

// Method 4: Use render texture for even better performance
draw_particles_to_render_texture :: proc(particles: []Particle, render_target: rl.RenderTexture2D) {
    rl.BeginTextureMode(render_target)
    rl.ClearBackground(rl.BLANK)
    // Draw all particles to the render texture
    for particle in particles {
        rl.DrawPixelV(particle.pos, particle.color)
    }
    rl.EndTextureMode()
    // Draw the render texture to screen
    rl.DrawTexture(render_target.texture, 0, 0, rl.WHITE)
}

// Worker thread fn
particle_worker :: proc(arg: rawptr) {
    data := cast(^WorkerData)arg
    for {
        // Wait for main thread to signal work is ready
        sync.barrier_wait(data.barrier)
        // Check if we should exit (mouse_pos will be negative)
        if data.mouse_pos.x < 0 do break
        
        // Process our chunk of particles
        for i in data.start_idx..<data.end_idx {
            particle_attract(&data.particles[i], data.mouse_pos, 1.0)
            particle_do_friction(&data.particles[i], 0.99)
            particle_move(&data.particles[i], data.screen_width, data.screen_height)
        }
        // Signal that work is done
        sync.barrier_wait(data.barrier)
    }
}

main :: proc() {
    particles := make([]Particle, NUM_PARTICLES)
    defer delete(particles)
    
    // Initialize particles
    for i in 0..<NUM_PARTICLES {
        particles[i] = particle_new(WIDTH, HEIGHT)
    }
    // Set up threading
    threads := make([]fibr.Thread, NUM_THREADS)
    defer delete(threads)
    
    worker_data := make([]WorkerData, NUM_THREADS)
    defer delete(worker_data)
    
    // Create barrier for synchronization (NUM_THREADS + 1 for main thread)
    barrier: sync.Barrier
	sync.barrier_init(&barrier, NUM_THREADS + 1)
    
    // Calculate work distribution
    particles_per_thread := NUM_PARTICLES / NUM_THREADS
    remainder := NUM_PARTICLES % NUM_THREADS
    
    // Initialize worker data and spawn threads
    for i in 0..<NUM_THREADS {
        start_idx := i * particles_per_thread
        end_idx := start_idx + particles_per_thread
        
        // Distribute remainder particles to first few threads
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
    rl.InitWindow(WIDTH, HEIGHT, "Parallel Particle System - Enhanced Rendering")
    rl.SetTargetFPS(60)
    
    // Create a small particle texture for instanced rendering
    particle_image := rl.GenImageColor(4, 4, rl.WHITE)
    particle_texture := rl.LoadTextureFromImage(particle_image)
    rl.UnloadImage(particle_image)
    defer rl.UnloadTexture(particle_texture)
    
    // Create render texture for Method 4
    render_target := rl.LoadRenderTexture(WIDTH, HEIGHT)
    defer rl.UnloadRenderTexture(render_target)
    
    render_method := 0 // 0: original, 1: batched pixels, 2: rects, 3: instanced, 4: render texture
    
    for !rl.WindowShouldClose() {
        mouse_pos := rl.GetMousePosition()
        
        // Switch rendering methods with number keys
        if rl.IsKeyPressed(.ONE) do render_method = 0
        if rl.IsKeyPressed(.TWO) do render_method = 1
        if rl.IsKeyPressed(.THREE) do render_method = 2
        if rl.IsKeyPressed(.FOUR) do render_method = 3
        if rl.IsKeyPressed(.FIVE) do render_method = 4
        
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
        
        // Render on main thread
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        switch render_method {
        case 0:
            // Original method
            for i in 0..<NUM_PARTICLES {
                rl.DrawPixelV(particles[i].pos, particles[i].color)
            }
        case 1:
            draw_particles_batched_pixels(particles)
        case 2:
            draw_particles_as_rects(particles)
        case 3:
            draw_particles_instanced(particles, particle_texture)
        case 4:
            draw_particles_to_render_texture(particles, render_target)
        }
        rl.DrawFPS(10, 10)
        rl.DrawText("Parallel Particle System - Enhanced Rendering", 10, 30, 20, rl.DARKGRAY)
        
        method_names := []string{
            "1: DrawPixelV",
            "2: Batched Pixels",
            "3: Rectangle Particles", 
            "4: Instanced Textures",
            "5: Render Texture"
        }
        for name, i in method_names {
            color := rl.DARKGRAY
            if i == render_method do color = rl.RED
            rl.DrawText(cstring(raw_data(name)), 10, 60 + i32(i) * 20, 16, color)
        }
        rl.EndDrawing()
    }
    // Signal workers to exit
    for i in 0..<NUM_THREADS {
        worker_data[i].mouse_pos = {-1, -1}  // Negative coordinates as exit signal
    }
    // Final barrier to let workers see exit signal
    sync.barrier_wait(&barrier)
    
    // Wait for all threads to finish
    for i in 0..<NUM_THREADS {
        fibr.join(&threads[i])
    }
    rl.CloseWindow()
}