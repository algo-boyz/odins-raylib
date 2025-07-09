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

particle_draw_pixel :: proc(p: ^Particle) {
    rl.DrawPixelV(p.pos, p.color)
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
    rl.InitWindow(WIDTH, HEIGHT, "Parallel Particle System")
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        mouse_pos := rl.GetMousePosition()
        
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
        
        for i in 0..<NUM_PARTICLES {
            particle_draw_pixel(&particles[i])
        }
        rl.DrawFPS(10, 10)
        rl.DrawText("Parallel Particle System", 10, 30, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }
    // Signal workers to exit
    for i in 0..<NUM_THREADS {
        worker_data[i].mouse_pos = {-1, -1}  // Negative coordinates as exit sig wildcard
    }
    // Final barrier to let workers see exit signal
    sync.barrier_wait(&barrier)
    
    // Wait for all threads to finish
    for i in 0..<NUM_THREADS {
        fibr.join(&threads[i])
    }
    rl.CloseWindow()
}