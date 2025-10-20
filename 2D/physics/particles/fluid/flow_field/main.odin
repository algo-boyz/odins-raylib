package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 800
SCL :: 20
ROWS :: HEIGHT / SCL
COLS :: WIDTH / SCL
PARTICLE_RADIUS :: 2
MAX_SPEED :: 2
MIN_SPEED :: 1
NUM_PARTICLES :: 300
TRAIL_LENGTH :: 50
FLOW_SPEED :: 0.005

// Slot represents a grid cell in the flow field
Slot :: struct {
    start_point, vec: rl.Vector2,
}

Particle :: struct {
    pos, vel, acc: rl.Vector2,
    min_speed, max_speed: f32,
    trail: [TRAIL_LENGTH]rl.Vector2,
    trail_index: int,
    color: rl.Color,
}

board: [ROWS][COLS]Slot

// Map values from one range to another
map_to :: proc(minimum, maximum, new_min, new_max, value: f32) -> f32 {
    clamped := clamp(value, minimum, maximum)
    real_range := maximum - minimum
    norm := (clamped - minimum) / real_range
    new_range := new_max - new_min
    return norm * new_range + new_min
}

// Random gradient for Perlin noise
random_gradient :: proc(ix, iy: i32) -> rl.Vector2 {
    w :: 8 * size_of(u32)
    s :: w / 2
    a := u32(ix)
    b := u32(iy)
    
    a *= 3284157443
    b ~= a << s | a >> (w - s)
    b *= 1911520717
    a ~= b << s | b >> (w - s)
    a *= 2048419325
    
    random := f32(a) * (math.PI / f32(~(~u32(0) >> 1)))
    
    return rl.Vector2{ math.sin(random), math.cos(random) }
}

// Dot product of grid gradient
dot_grid_gradient :: proc(ix, iy: i32, x, y: f32) -> f32 {
    gradient := random_gradient(ix, iy)
    dx := x - f32(ix)
    dy := y - f32(iy)
    return dx * gradient.x + dy * gradient.y
}

// Smooth interpolation
interpolate :: proc(a0, a1, w: f32) -> f32 {
    return (a1 - a0) * (3.0 - w * 2.0) * w * w + a0
}

// Get Perlin noise at coordinates x, y
perlin :: proc(x, y: f32) -> f32 {
    x0 := i32(x)
    y0 := i32(y)
    x1 := x0 + 1
    y1 := y0 + 1
    
    sx := x - f32(x0)
    sy := y - f32(y0)
    
    n0 := dot_grid_gradient(x0, y0, x, y)
    n1 := dot_grid_gradient(x1, y0, x, y)
    ix0 := interpolate(n0, n1, sx)
    
    n0 = dot_grid_gradient(x0, y1, x, y)
    n1 = dot_grid_gradient(x1, y1, x, y)
    ix1 := interpolate(n0, n1, sx)
    
    return interpolate(ix0, ix1, sy)
}

// Flow field function using fractal noise
field_func :: proc(x, y: f32) -> f32 {
    val: f32 = 0
    freq: f32 = 1
    amp: f32 = 1
    
    for i in 0..<4 {
        val += perlin(x * freq, y * freq) * amp
        freq *= 2
        amp /= 2
    }
    val = clamp(val, -1.0, 1.0)
    return map_to(-1, 1, 0, 2 * math.PI, val)
}

particle_init :: proc(pos, vel: rl.Vector2, min_speed, max_speed: f32) -> Particle {
    // Generate a random color for each particle
    hue := f32(rand.int_max(360))
    color := rl.ColorFromHSV(hue, 0.8, 0.9)
    
    return Particle{
        pos = pos,
        vel = vel,
        acc = rl.Vector2{0, 0},
        min_speed = min_speed,
        max_speed = max_speed,
        trail = {},
        trail_index = 0,
        color = color,
    }
}

particle_apply_force :: proc(p: ^Particle, force: rl.Vector2) {
    p.acc.x += force.x
    p.acc.y += force.y
}

particle_update :: proc(p: ^Particle) {
    // Update velocity
    p.vel.x += p.acc.x
    p.vel.y += p.acc.y
    
    // Limit speed
    speed := math.sqrt(p.vel.x * p.vel.x + p.vel.y * p.vel.y)
    if speed > p.max_speed {
        p.vel.x = (p.vel.x / speed) * p.max_speed
        p.vel.y = (p.vel.y / speed) * p.max_speed
    }
    
    // Add current position to trail
    p.trail[p.trail_index] = p.pos
    p.trail_index = (p.trail_index + 1) % TRAIL_LENGTH
    
    // Update position
    p.pos.x += p.vel.x
    p.pos.y += p.vel.y
    
    // Reset acceleration
    p.acc.x = 0
    p.acc.y = 0
    
    // Wrap around screen edges (fixed)
    if p.pos.x < 0 do p.pos.x = WIDTH - 1
    if p.pos.x >= WIDTH do p.pos.x = 0
    if p.pos.y < 0 do p.pos.y = HEIGHT - 1
    if p.pos.y >= HEIGHT do p.pos.y = 0
}

particle_draw :: proc(p: ^Particle, show_trails: bool) {
    if show_trails {
        // Draw trail
        for i in 0..<TRAIL_LENGTH-1 {
            current_idx := (p.trail_index + i) % TRAIL_LENGTH
            next_idx := (p.trail_index + i + 1) % TRAIL_LENGTH
            
            alpha := f32(i) / f32(TRAIL_LENGTH - 1)
            trail_color := rl.Color{
                p.color.r,
                p.color.g,
                p.color.b,
                u8(alpha * 100),
            }
            
            if p.trail[current_idx].x != 0 || p.trail[current_idx].y != 0 {
                rl.DrawLineEx(p.trail[current_idx], p.trail[next_idx], 1, trail_color)
            }
        }
    }
    
    // Draw particle
    rl.DrawCircle(i32(p.pos.x), i32(p.pos.y), PARTICLE_RADIUS, p.color)
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Flow Field - Press SPACE to toggle trails, R to reset")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    MULT :: 0.5
    length: f32 = SCL * MULT
    show_trails := false
    show_vectors := true
    
    // Init flow field grid
    for y in 0..<ROWS {
        for x in 0..<COLS {
            board[y][x].start_point = {
                f32(SCL * x) + f32(SCL) / 2,
                f32(SCL * y) + f32(SCL) / 2,
            }
        }
    }
    
    particles := make([]Particle, NUM_PARTICLES)
    defer delete(particles)
    
    reset_particles :: proc(particles: []Particle) {
        for i in 0..<NUM_PARTICLES {
            pos := rl.Vector2{
                f32(rand.int_max(WIDTH)),
                f32(rand.int_max(HEIGHT)),
            }
            particles[i] = particle_init(pos, rl.Vector2{0, 0}, MIN_SPEED, MAX_SPEED)
        }
    }
    
    reset_particles(particles)
    z := f32(rand.int_max(10000))
    
    for !rl.WindowShouldClose() {
        // Handle input
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            show_trails = !show_trails
        }
        if rl.IsKeyPressed(rl.KeyboardKey.R) {
            reset_particles(particles)
        }
        if rl.IsKeyPressed(rl.KeyboardKey.V) {
            show_vectors = !show_vectors
        }
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{10, 10, 20, 255})
        
        // Update flow field
        for y in 0..<ROWS {
            for x in 0..<COLS {
                angle := field_func(f32(x) * 0.03 + z, f32(y) * 0.03 + z)
                board[y][x].vec = rl.Vector2{
                    math.cos(angle) * length,
                    math.sin(angle) * length,
                }
                
                // Draw flow field vectors
                if show_vectors {
                    end := rl.Vector2{
                        board[y][x].start_point.x + board[y][x].vec.x,
                        board[y][x].start_point.y + board[y][x].vec.y,
                    }
                    c := u8(map_to(0, 2 * math.PI, 50, 150, angle))
                    rl.DrawLineEx(board[y][x].start_point, end, 1, rl.Color{c/2, c, c, 100})
                }
            }
        }
        
        // Update and draw particles
        for i in 0..<NUM_PARTICLES {
            grid_x := min(i32(particles[i].pos.x / SCL), COLS - 1)
            grid_y := min(i32(particles[i].pos.y / SCL), ROWS - 1)
            
            // Bounds check (fixed)
            if grid_x >= 0 && grid_x < COLS && grid_y >= 0 && grid_y < ROWS {
                force := board[grid_y][grid_x].vec
                particle_apply_force(&particles[i], force)
            }
            
            particle_update(&particles[i])
            particle_draw(&particles[i], show_trails)
        }
        
        z += FLOW_SPEED
        
        // Draw UI
        rl.DrawText("SPACE: Toggle trails", 10, 10, 20, rl.WHITE)
        rl.DrawText("V: Toggle vectors", 10, 35, 20, rl.WHITE)
        rl.DrawText("R: Reset particles", 10, 60, 20, rl.WHITE)
        
        rl.EndDrawing()
    }
}