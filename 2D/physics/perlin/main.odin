package main

import "core:fmt"
import "core:math"
import "core:time"
import "core:c"
import rl "vendor:raylib"
import "../../../rlutil/noise"

Mode :: enum {
    TERRAIN_2D,
    ANIMATED_WAVES,
    PARTICLE_FIELD,
    CLOUD_SIMULATION,
    MARBLE_TEXTURE,
}

State :: struct {
    noise: noise.Perlin,
    mode: Mode,
    time_offset: f64,
    octaves: int,
    scale: f32,
    animation_speed: f32,
    seed: u64,
    show_wireframe: bool,
    color_scheme: int,
    particles: []Particle,
}

Particle :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    life: f32,
    max_life: f32,
}

SCREEN_WIDTH :: 1200
SCREEN_HEIGHT :: 800
GRID_SIZE :: 128
PARTICLE_COUNT :: 1000

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Perlin Noise Showcase")
    rl.SetTargetFPS(60)
    
    state := State{
        noise = noise.perlin_noise_init_with_seed(42),
        mode = .TERRAIN_2D,
        octaves = 6,
        scale = 0.01,
        animation_speed = 1.0,
        seed = 42,
        show_wireframe = false,
        color_scheme = 0,
    }
    
    state.particles = make([]Particle, PARTICLE_COUNT)
    init_particles(&state)
    
    for !rl.WindowShouldClose() {
        update_demo(&state)
        draw_demo(&state)
    }
    
    delete(state.particles)
    rl.CloseWindow()
}

update_demo :: proc(state: ^State) {
    state.time_offset += f64(rl.GetFrameTime()) * f64(state.animation_speed)
    
    // Handle input
    if rl.IsKeyPressed(.ONE) do state.mode = .TERRAIN_2D
    if rl.IsKeyPressed(.TWO) do state.mode = .ANIMATED_WAVES
    if rl.IsKeyPressed(.THREE) do state.mode = .PARTICLE_FIELD
    if rl.IsKeyPressed(.FOUR) do state.mode = .CLOUD_SIMULATION
    if rl.IsKeyPressed(.FIVE) do state.mode = .MARBLE_TEXTURE
    
    if rl.IsKeyPressed(.W) do state.show_wireframe = !state.show_wireframe
    if rl.IsKeyPressed(.C) do state.color_scheme = (state.color_scheme + 1) % 4
    
    if rl.IsKeyPressed(.R) {
        state.seed += 1
        state.noise = noise.perlin_noise_init_with_seed(state.seed)
        if state.mode == .PARTICLE_FIELD do init_particles(state)
    }
    // Adjust parameters
    if rl.IsKeyDown(.UP) && state.octaves < 8 do state.octaves += 1
    if rl.IsKeyDown(.DOWN) && state.octaves > 1 do state.octaves -= 1
    
    scroll := rl.GetMouseWheelMove()
    if scroll != 0 {
        state.scale *= 1.0 + scroll * 0.1
        state.scale = math.clamp(state.scale, 0.001, 0.1)
    }
    
    if rl.IsKeyDown(.LEFT_SHIFT) {
        state.animation_speed = math.clamp(state.animation_speed + rl.GetMouseWheelMove() * 0.5, 0.1, 5.0)
    }
    
    // Update particles for particle field
    if state.mode == .PARTICLE_FIELD {
        update_particles(state)
    }
}

draw_demo :: proc(state: ^State) {
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    
    switch state.mode {
    case .TERRAIN_2D:
        draw_terrain_2d(state)
    case .ANIMATED_WAVES:
        draw_animated_waves(state)
    case .PARTICLE_FIELD:
        draw_particle_field(state)
    case .CLOUD_SIMULATION:
        draw_cloud_simulation(state)
    case .MARBLE_TEXTURE:
        draw_marble_texture(state)
    }
    draw_ui(state)
    rl.EndDrawing()
}

draw_terrain_2d :: proc(state: ^State) {
    cell_width := f32(SCREEN_WIDTH) / f32(GRID_SIZE)
    cell_height := f32(SCREEN_HEIGHT) / f32(GRID_SIZE)
    
    for x in 0..<GRID_SIZE {
        for y in 0..<GRID_SIZE {
            noise_val := noise.get_noise_2d_with_octaves(
                &state.noise,
                f64(x) * f64(state.scale),
                f64(y) * f64(state.scale),
                state.octaves
            )
            color := get_terrain_color(noise_val, state.color_scheme)
            
            rect := rl.Rectangle{
                x = f32(x) * cell_width,
                y = f32(y) * cell_height,
                width = cell_width + 1,
                height = cell_height + 1,
            }
            if state.show_wireframe {
                rl.DrawRectangleLinesEx(rect, 1, color)
            } else {
                rl.DrawRectangleRec(rect, color)
            }
        }
    }
}

draw_animated_waves :: proc(state: ^State) {
    step := 4
    for x := 0; x < SCREEN_WIDTH; x += step {
        for y := 0; y < SCREEN_HEIGHT; y += step {
            noise_val := noise.get_noise_3d_with_octaves(
                &state.noise,
                f64(x) * f64(state.scale),
                f64(y) * f64(state.scale),
                state.time_offset * 0.5,
                state.octaves
            )
            // Wave effect
            wave_height := noise_val * 100
            color := get_wave_color(noise_val, state.color_scheme)
            
            if state.show_wireframe {
                rl.DrawPixel(i32(x), i32(f64(y) + wave_height), color)
            } else {
                size := 2 + i32(noise_val * 6)
                rl.DrawRectangle(i32(x), i32(f64(y) + wave_height), size, size, color)
            }
        }
    }
}

draw_particle_field :: proc(state: ^State) {
    for &particle in state.particles {
        alpha := u8(255 * (particle.life / particle.max_life))
        color := rl.Color{255, 200, 100, alpha}
        
        size := 2 + particle.life / particle.max_life * 4
        rl.DrawCircleV(particle.pos, size, color)
        
        // Draw particle trail
        if particle.life > 0.5 {
            trail_pos := rl.Vector2{
                particle.pos.x - particle.vel.x * 5,
                particle.pos.y - particle.vel.y * 5,
            }
            trail_color := rl.Color{255, 100, 50, alpha / 2}
            rl.DrawLineEx(particle.pos, trail_pos, 1, trail_color)
        }
    }
}

draw_cloud_simulation :: proc(state: ^State) {
    cell_size := 6
    for x := 0; x < SCREEN_WIDTH; x += cell_size {
        for y := 0; y < SCREEN_HEIGHT; y += cell_size {
            // Multi-layer cloud effect
            cloud1 := noise.get_noise_3d_with_octaves(
                &state.noise,
                f64(x) * f64(state.scale) * 0.5,
                f64(y) * f64(state.scale) * 0.5,
                state.time_offset * 0.2,
                4
            )
            cloud2 := noise.get_noise_3d_with_octaves(
                &state.noise,
                f64(x) * f64(state.scale) * 2.0,
                f64(y) * f64(state.scale) * 2.0,
                state.time_offset * 0.8,
                3
            )
            density := (cloud1 * 0.7 + cloud2 * 0.3)
            if density > 0.3 {
                alpha := u8(math.clamp((density - 0.3) * 255 * 1.5, 0, 255))
                color := get_cloud_color(density, state.color_scheme, alpha)
                
                rl.DrawRectangle(i32(x), i32(y), i32(cell_size), i32(cell_size), color)
            }
        }
    }
}

draw_marble_texture :: proc(state: ^State) {
    cell_size := 2
    for x := 0; x < SCREEN_WIDTH; x += cell_size {
        for y := 0; y < SCREEN_HEIGHT; y += cell_size {
            // Create marble pattern using multiple noise octaves
            base_noise := noise.get_noise_2d_with_octaves(
                &state.noise,
                f64(x) * f64(state.scale) * 0.5,
                f64(y) * f64(state.scale) * 0.5,
                6
            )
            // Add turbulence
            turb_x := noise.get_noise_2d_with_octaves(
                &state.noise,
                f64(x) * f64(state.scale) * 2.0,
                f64(y) * f64(state.scale) * 2.0,
                4
            ) * 50
            turb_y := noise.get_noise_2d_with_octaves(
                &state.noise,
                f64(x) * f64(state.scale) * 2.0 + 100,
                f64(y) * f64(state.scale) * 2.0 + 100,
                4
            ) * 50
            // Marble veining
            vein_val := math.sin((f64(x) + turb_x) * f64(state.scale) * 10) * 0.5 + 0.5
            marble_val := base_noise * 0.7 + vein_val * 0.3
            
            color := get_marble_color(marble_val, state.color_scheme)
            rl.DrawRectangle(i32(x), i32(y), i32(cell_size), i32(cell_size), color)
        }
    }
}

init_particles :: proc(state: ^State) {
    for &particle in state.particles {
        particle.pos = rl.Vector2{
            f32(rl.GetRandomValue(0, SCREEN_WIDTH)),
            f32(rl.GetRandomValue(0, SCREEN_HEIGHT)),
        }
        particle.vel = rl.Vector2{0, 0}
        particle.life = f32(rl.GetRandomValue(50, 300)) / 100.0
        particle.max_life = particle.life
    }
}

update_particles :: proc(state: ^State) {
    for &particle in state.particles {
        // Get noise-based flow field
        flow_x := noise.get_noise_3d_with_octaves(
            &state.noise,
            f64(particle.pos.x) * f64(state.scale) * 0.5,
            f64(particle.pos.y) * f64(state.scale) * 0.5,
            state.time_offset,
            4
        ) * 2 - 1
        
        flow_y := noise.get_noise_3d_with_octaves(
            &state.noise,
            f64(particle.pos.x) * f64(state.scale) * 0.5 + 1000,
            f64(particle.pos.y) * f64(state.scale) * 0.5 + 1000,
            state.time_offset,
            4
        ) * 2 - 1
        // Apply flow field
        particle.vel.x += f32(flow_x) * 0.5
        particle.vel.y += f32(flow_y) * 0.5
        // Apply damping
        particle.vel.x *= 0.98
        particle.vel.y *= 0.98
        // Update position
        particle.pos.x += particle.vel.x
        particle.pos.y += particle.vel.y
        // Update life
        particle.life -= rl.GetFrameTime()
        // Wrap around screen and reset if dead
        if particle.life <= 0 || 
           particle.pos.x < 0 || particle.pos.x > SCREEN_WIDTH ||
           particle.pos.y < 0 || particle.pos.y > SCREEN_HEIGHT {
            particle.pos.x = f32(rl.GetRandomValue(0, SCREEN_WIDTH))
            particle.pos.y = f32(rl.GetRandomValue(0, SCREEN_HEIGHT))
            particle.vel = rl.Vector2{0, 0}
            particle.life = f32(rl.GetRandomValue(50, 300)) / 100.0
            particle.max_life = particle.life
        }
    }
}

get_terrain_color :: proc(noise_val: f64, scheme: int) -> rl.Color {
    switch scheme {
    case 0: // Ocean/Land
        if noise_val < 0.3 do return rl.Color{0, 50, 150, 255}      // Deep water
        if noise_val < 0.4 do return rl.Color{0, 100, 200, 255}    // Shallow water
        if noise_val < 0.5 do return rl.Color{194, 178, 128, 255}  // Beach
        if noise_val < 0.7 do return rl.Color{34, 139, 34, 255}    // Grass
        if noise_val < 0.8 do return rl.Color{139, 90, 43, 255}    // Hills
        return rl.Color{139, 137, 137, 255}                        // Mountains
    
    case 1: // Heat map
        r := u8(noise_val * 255)
        return rl.Color{r, u8(255 - r), 0, 255}
    
    case 2: // Grayscale
        val := u8(noise_val * 255)
        return rl.Color{val, val, val, 255}
    
    case 3: // Psychedelic
        r := u8(math.sin(noise_val * math.PI * 4) * 127 + 128)
        g := u8(math.sin(noise_val * math.PI * 6 + 2) * 127 + 128)
        b := u8(math.sin(noise_val * math.PI * 8 + 4) * 127 + 128)
        return rl.Color{r, g, b, 255}
    }
    return rl.WHITE
}

get_wave_color :: proc(noise_val: f64, scheme: int) -> rl.Color {
    switch scheme {
    case 0: // Ocean waves
        intensity := u8(noise_val * 255)
        return rl.Color{0, intensity / 2, intensity, 255}
    case 1: // Fire waves
        intensity := u8(noise_val * 255)
        return rl.Color{intensity, intensity / 2, 0, 255}
    case 2: // Electric
        intensity := u8(noise_val * 255)
        return rl.Color{intensity, intensity, 255, 255}
    case 3: // Rainbow
        r := u8(math.sin(noise_val * math.PI * 2) * 127 + 128)
        g := u8(math.sin(noise_val * math.PI * 2 + 2.09) * 127 + 128)
        b := u8(math.sin(noise_val * math.PI * 2 + 4.18) * 127 + 128)
        return rl.Color{r, g, b, 255}
    }
    return rl.WHITE
}

get_cloud_color :: proc(density: f64, scheme: int, alpha: u8) -> rl.Color {
    switch scheme {
    case 0: // Storm clouds
        val := u8(density * 128 + 64)
        return rl.Color{val, val, val + 32, alpha}
    case 1: // Sunset clouds
        return rl.Color{255, u8(density * 128 + 64), u8(density * 64), alpha}
    case 2: // Green mist
        return rl.Color{u8(density * 64), u8(density * 255), u8(density * 128), alpha}
    case 3: // Purple nebula
        return rl.Color{u8(density * 128 + 127), u8(density * 64), u8(density * 255), alpha}
    }
    return rl.WHITE
}

get_marble_color :: proc(marble_val: f64, scheme: int) -> rl.Color {
    switch scheme {
    case 0: // Classic marble
        base := u8(marble_val * 200 + 55)
        return rl.Color{base, base, base, 255}
    case 1: // Red marble
        base := u8(marble_val * 200 + 55)
        return rl.Color{base + 50, base / 2, base / 4, 255}
    case 2: // Green marble
        base := u8(marble_val * 200 + 55)
        return rl.Color{base / 4, base + 50, base / 2, 255}
    case 3: // Blue marble
        base := u8(marble_val * 200 + 55)
        return rl.Color{base / 4, base / 2, base + 50, 255}
    }
    return rl.WHITE
}

draw_ui :: proc(state: ^State) {
    ui_y:i32 = 10
    line_height :: 20
    mode_names := []string{
        "2D Terrain", "Animated Waves", "Particle Field", "Cloud Simulation", "Marble Texture"
    }
    rl.DrawText(fmt.ctprintf("Mode: %s (1-5)", mode_names[state.mode]), 10, ui_y, 16, rl.WHITE)
    ui_y += line_height
    rl.DrawText(fmt.ctprintf("Octaves: %d (UP/DOWN)", state.octaves), 10, ui_y, 16, rl.WHITE)
    ui_y += line_height
    rl.DrawText(fmt.ctprintf("Scale: %.4f (Mouse Wheel)", state.scale), 10, ui_y, 16, rl.WHITE)
    ui_y += line_height
    rl.DrawText(fmt.ctprintf("Speed: %.1f (Shift+Wheel)", state.animation_speed), 10, ui_y, 16, rl.WHITE)
    ui_y += line_height
    rl.DrawText(fmt.ctprintf("Seed: %d (R to randomize)", state.seed), 10, ui_y, 16, rl.WHITE)
    ui_y += line_height
    rl.DrawText("Wireframe: W | Colors: C", 10, ui_y, 16, rl.WHITE)
    ui_y += line_height
    fps_text := fmt.ctprintf("FPS: %d", rl.GetFPS())
    rl.DrawText(fps_text, SCREEN_WIDTH - 100, 10, 16, rl.LIME)
}