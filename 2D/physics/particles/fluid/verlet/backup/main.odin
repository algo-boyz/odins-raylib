package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:thread"
import "core:sync"
import rl "vendor:raylib"
import mu "vendor:microui"
import "fibr"

WIDTH :: 1280
HEIGHT :: 720
Vec2 :: rl.Vector2
Color :: rl.Color

Particle :: struct {
    pos,
    old_pos,
    accel,
    velocity:      Vec2,
    color:         Color,
    density,
    near_density,
    pressure,
    near_pressure,
    radius:        f32,
}

// Spring structure for elasticity
Spring :: struct {
    a,
    b:   int,
    len: f32,
}

SimulationMode :: enum {
    VERLET,
    FLUID,
}

MouseAction :: enum {
    NONE,
    SPAWN,
    PUSH,
    PICK,
}
// Globals
particles: [dynamic]Particle
springs: [dynamic]Spring
grid: [dynamic][dynamic][dynamic]^Particle

// Simulation
den: f32 = 1.0
n_den: f32 = 35.0
pres: f32 = 2000.0
n_pres: f32 = 1.0
k: f32 = -0.5
k_near: f32 = 0.5
rho0: f32 = 500.0
h: f32 = 32.0
gravity: f32 = 98.1
damping: f32 = 0.999
hsq: f32 = h * h
EPS: f32 = h
BOUND_DAMPING: f32 = -1.0

// Elasticity and plasticity
k_spring: f32 = 0.3
plasticity_alpha: f32 = 0.3
yield_ratio: f32 = 0.2

// Viscosity
sigma: f32 = 0.5
beta: f32 = 0.5
max_velocity: f32 = 1.0
sigma_surface: f32 = 0.0728

// Grid
cell_size: f32 = h
grid_width: int
grid_height: int
// UI
current_mode: SimulationMode = .VERLET
current_action: MouseAction = .NONE
particle_radius: f32 = 5.0
push_force: f32 = 100.0
pick_radius: f32 = 100.0
pick_force: Vec2 = {-150.0, -150.0}
dragging: bool = false
particle_color: Color = rl.RAYWHITE
bg_color: Color = rl.BLACK
mu_ctx: mu.Context

// Text width callback for microui
text_width :: proc(font: mu.Font, text: string) -> i32 {
    return rl.MeasureText(cstring(raw_data(text)), 10)
}

// Text height callback for microui
text_height :: proc(font: mu.Font) -> i32 {
    return 10
}

initialize_particles :: proc(count: int, color: Color) {
    clear(&particles)
    for i in 0..<count {
        p := Particle{
            pos = {f32(rl.GetRandomValue(100, 700)), f32(rl.GetRandomValue(100, 500))},
            radius = 5.0,
            color = color,
            near_density = n_den,
            near_pressure = n_pres,
        }
        p.old_pos = p.pos
        append(&particles, p)
    }
    grid_width = int(math.ceil(f32(WIDTH) / cell_size))
    grid_height = int(math.ceil(f32(HEIGHT) / cell_size))
    // Init grid
    resize(&grid, grid_width)
    for i in 0..<grid_width {
        resize(&grid[i], grid_height)
        for j in 0..<grid_height {
            clear(&grid[i][j])
        }
    }
}

apply_force :: proc(p: ^Particle, force: Vec2) {
    p.accel = p.accel + force
}

velocity_to_color :: proc(velocity: Vec2, max_vel: f32) -> Color {
    speed := linalg.length(velocity)
    t := speed / max_vel * 2.0
    r := u8(0 * (1 - t) + 173 * t)
    g := u8(0 * (1 - t) + 216 * t)
    b := u8(139 * (1 - t) + 230 * t)
    return {r, g, b, 255}
}

verlet_integration :: proc(p: ^Particle, delta_time: f32) {
    temp := p.pos
    p.velocity = p.pos - p.old_pos
    p.pos = p.pos + p.velocity + (p.accel * 0.5 * delta_time * delta_time)
    p.old_pos = temp
    p.accel = {0, 0}
}

resolve_collision :: proc(p1, p2: ^Particle) {
    delta := p1.pos - p2.pos
    distance := linalg.length(delta)
    min_distance := p1.radius + p2.radius
    
    if distance < min_distance {
        overlap := 0.1 * (distance - min_distance)
        offset := delta * (overlap / distance)
        // Adjust positions
        p1.pos = p1.pos - offset
        p2.pos = p2.pos + offset
        // Apply damping
        p1_vel := p1.pos - p1.old_pos
        p2_vel := p2.pos - p2.old_pos
        p1_vel *= damping
        p2_vel *= damping
        p1.old_pos = p1.pos - p1_vel
        p2.old_pos = p2.pos - p2_vel
    }
}

assign_particles_to_grid :: proc() {
    // Clear grid
    for i in 0..<grid_width {
        for j in 0..<grid_height {
            clear(&grid[i][j])
        }
    }
    // Assign particles to grid
    for &particle in particles {
        cell_x := int(particle.pos.x / cell_size)
        cell_y := int(particle.pos.y / cell_size)
        if cell_x >= 0 && cell_x < grid_width && cell_y >= 0 && cell_y < grid_height {
            append(&grid[cell_x][cell_y], &particle)
        }
    }
}

resolve_grid_collisions :: proc() {
    for i in 0..<len(particles) {
        p1 := &particles[i]
        cell_x := int(p1.pos.x / cell_size)
        cell_y := int(p1.pos.y / cell_size)
        // Check neighboring cells
        for x in max(0, cell_x - 1)..=min(grid_width - 1, cell_x + 1) {
            for y in max(0, cell_y - 1)..=min(grid_height - 1, cell_y + 1) {
                for p2 in grid[x][y] {
                    if p1 != p2 {
                        resolve_collision(p1, p2)
                    }
                }
            }
        }
    }
}

constrain_to_bounds :: proc(p: ^Particle, screen_width, screen_height: int) {
    if p.pos.x < p.radius {
        p.pos.x = p.radius
    } else if p.pos.x > f32(screen_width) - p.radius {
        p.pos.x = f32(screen_width) - p.radius
    }
    if p.pos.y < p.radius {
        p.pos.y = p.radius
    } else if p.pos.y > f32(screen_height) - p.radius {
        p.pos.y = f32(screen_height) - p.radius
    }
}

fluid_bounds :: proc(p: ^Particle, screen_width, screen_height: int) {
    min_x := p.radius
    max_x := f32(screen_width) - p.radius
    min_y := p.radius
    max_y := f32(screen_height) - p.radius
    
    // Constrain X-axis
    if p.pos.x < min_x {
        p.pos.x = min_x
        p.velocity.x *= BOUND_DAMPING
    } else if p.pos.x > max_x {
        p.pos.x = max_x
        p.velocity.x *= BOUND_DAMPING
    }
    // Constrain Y-axis
    if p.pos.y < min_y {
        p.pos.y = min_y
        p.velocity.y *= BOUND_DAMPING
    } else if p.pos.y > max_y {
        p.pos.y = max_y
        p.velocity.y *= BOUND_DAMPING
    }
}

apply_viscosity :: proc(delta_time: f32) {
    for i in 0..<len(particles) {
        for j in i+1..<len(particles) {
            pi := &particles[i]
            pj := &particles[j]
            distance := linalg.length(pi.pos - pj.pos)
            
            if distance < h {
                direction := linalg.normalize(pj.pos - pi.pos)
                radial_velocity := linalg.dot(pj.velocity - pi.velocity, direction)
                
                if radial_velocity > 0 {
                    q := distance / h
                    impulse_magnitude := delta_time * (1 - q) * (sigma * radial_velocity + beta * radial_velocity * radial_velocity)
                    impulse := direction * impulse_magnitude
                    
                    pi.velocity = pi.velocity - impulse * 0.5
                    pj.velocity = pj.velocity + impulse * 0.5
                }
            }
        }
    }
}

double_density_relaxation :: proc(delta_time: f32) {
    for i in 0..<len(particles) {
        pi := &particles[i]
        pi.density = 0.0
        pi.near_density = 0.0
        
        neighbors: [dynamic]int
        neighbor_closeness: [dynamic]f32
        neighbor_direction: [dynamic]Vec2
        defer delete(neighbors)
        defer delete(neighbor_closeness)
        defer delete(neighbor_direction)
        
        // Compute density and near-density
        for j in 0..<len(particles) {
            if i == j do continue
            
            pj := &particles[j]
            rij := pj.pos - pi.pos
            r := linalg.length(rij)
            
            if r < h {
                q := r / h
                closeness := 1 - q
                closeness_sq := closeness * closeness
                
                pi.density += closeness_sq
                pi.near_density += closeness * closeness_sq
                
                append(&neighbors, j)
                append(&neighbor_closeness, closeness)
                append(&neighbor_direction, linalg.normalize(rij))
            }
        }
        // Compute pressure and near-pressure
        pressure := k * (pi.density - rho0)
        near_pressure := k_near * pi.near_density
        displacement := Vec2{0, 0}
        
        // Apply displacements
        for n in 0..<len(neighbors) {
            neighbor_idx := neighbors[n]
            pj := &particles[neighbor_idx]
            closeness := neighbor_closeness[n]
            direction := neighbor_direction[n]
            
            displacement_contribution := direction * (delta_time * delta_time) * (pressure * closeness + near_pressure * closeness * closeness)
            
            pj.pos = pj.pos + displacement_contribution * 0.5
            displacement = displacement - displacement_contribution * 0.5
        }
        pi.pos = pi.pos + displacement
    }
}

update_sph_particles :: proc(delta_time: f32) {
    screen_width := rl.GetScreenWidth()
    screen_height := rl.GetScreenHeight()
    
    apply_viscosity(delta_time)
    
    for &particle in particles {
        apply_force(&particle, {0, gravity})
        verlet_integration(&particle, delta_time) 
        speed := linalg.length(particle.velocity)
        if speed > max_velocity {
            max_velocity = speed
        }
        particle.color = velocity_to_color(particle.velocity, max_velocity)
        fluid_bounds(&particle, int(screen_width), int(screen_height))
    }
    double_density_relaxation(delta_time)
}

update_verlet_particles :: proc(delta_time: f32) {
    WIDTH := rl.GetScreenWidth()
    HEIGHT := rl.GetScreenHeight()
    for &particle in particles {
        apply_force(&particle, {0, gravity})
        verlet_integration(&particle, delta_time)
        constrain_to_bounds(&particle, int(WIDTH), int(HEIGHT))
    }
    assign_particles_to_grid()
    resolve_grid_collisions()
}

draw_particles :: proc() {
    for particle in particles {
        switch current_mode {
        case .FLUID:
            rl.DrawCircleV(particle.pos, particle.radius, particle.color)
        case .VERLET:
            rl.DrawCircleV(particle.pos, particle.radius, particle_color)
        }
    }
}

spawn_particle :: proc(position: Vec2, radius: f32, color: Color) {
    p := Particle{
        pos = position,
        old_pos = position,
        accel = {0, 0},
        radius = radius,
        color = color,
        density = den,
        near_density = n_den,
        pressure = pres,
        near_pressure = n_pres,
    }
    append(&particles, p)
}

clear_particles :: proc() {
    clear(&particles)
}

push_particles :: proc(position: Vec2, force: f32) {
    for &particle in particles {
        direction := particle.pos - position
        distance := linalg.length(direction)
        if distance < 1.0 do distance = 1.0
        normalized := direction / distance
        apply_force(&particle, normalized * force)
    }
}

pick_up_particles :: proc(position: Vec2, radius: f32, force: Vec2) {
    for &particle in particles {
        delta := particle.pos - position
        distance := linalg.length(delta)
        if distance < radius {
            normalized := delta / distance
            apply_force(&particle, normalized * force.x)
            apply_force(&particle, {0, force.y})
        }
    }
}

mu_button :: proc(ctx: ^mu.Context, label: string) -> bool {
    return mu.button(ctx, label) == {.SUBMIT}
}

mu_slider :: proc(ctx: ^mu.Context, value: ^f32, low, high: f32) -> bool {
    return mu.slider(ctx, value, low, high) == {.CHANGE}
}

draw_ui :: proc(ctx: ^mu.Context) {
    if mu.window(ctx, "Simulation Settings", {40, 40, 300, 400}) {
        // Simulation mode
        mu.layout_row(ctx, {80, -1}, 0)
        mu.label(ctx, "Mode:")
        
        if mu.button(ctx, current_mode == .VERLET ? "Verlet*" : "Verlet") == {.SUBMIT} {
            current_mode = .VERLET
        }
        mu.layout_row(ctx, {80, -1}, 0)
        mu.label(ctx, "")
        if mu.button(ctx, current_mode == .FLUID ? "Fluid*" : "Fluid") == {.SUBMIT} {
            current_mode = .FLUID
        }
        // Mouse action
        mu.layout_row(ctx, {80, -1}, 0)
        mu.label(ctx, "Action:")
        
        actions := [?]string{"None", "Spawn", "Push", "Pick Up"}
        for action, i in actions {
            selected := current_action == MouseAction(i)
            if mu.button(ctx, selected ? fmt.tprintf("%s*", action) : action) == {.SUBMIT} {
                current_action = MouseAction(i)
            }
        }
        mu.layout_row(ctx, {-1}, 0)
        
        if current_action == .SPAWN {
            mu.label(ctx, "Particle Radius:")
            mu_slider(ctx, &particle_radius, 2.0, 10.0)
        } else if current_action == .PUSH {
            mu.label(ctx, "Push Force:")
            mu_slider(ctx, &push_force, 100.0, 1000.0)
        }
        mu.label(ctx, "Gravity:")
        mu_slider(ctx, &gravity, -98.1, 98.1)
        
        if current_mode == .FLUID {
            mu.label(ctx, "Density:")
            mu_slider(ctx, &den, 1.0, 100.0)
            
            mu.label(ctx, "Near Density:")
            mu_slider(ctx, &n_den, 1.0, 100.0)
            
            mu.label(ctx, "Pressure Mult:")
            mu_slider(ctx, &k, -1.0, 1.0)
            
            mu.label(ctx, "Near Pressure Mult:")
            mu_slider(ctx, &k_near, 0.1, 1.0)
            
            mu.label(ctx, "Rest Density:")
            mu_slider(ctx, &rho0, 0.1, 50.0)
            
            mu.label(ctx, "Smooth Radius:")
            mu_slider(ctx, &h, 0.1, 32.0)
            
            mu.label(ctx, "Sigma:")
            mu_slider(ctx, &sigma, 0.001, 0.999)
        }
        if mu_button(ctx, "Clear") {
            clear_particles()
        }
    }
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Verlet Integration")
    defer rl.CloseWindow()
    
    initialize_particles(2000, particle_color)
    defer delete(particles)
    defer delete(springs)
    defer {
        for row in grid {
            for cell in row {
                delete(cell)
            }
            delete(row)
        }
        delete(grid)
    }
    
    // Initialize microui with required callbacks
    mu.init(&mu_ctx)
    mu_ctx.text_width = text_width
    mu_ctx.text_height = text_height
    
    rl.SetTargetFPS(144)
    
    for !rl.WindowShouldClose() {
        // Update physics
        switch current_mode {
        case .VERLET:
            update_verlet_particles(0.08)
        case .FLUID:
            update_sph_particles(0.07)
        }
        // Handle mouse input
        if rl.IsMouseButtonDown(.LEFT) {
            mouse_pos := rl.GetMousePosition()
            
            switch current_action {
            case .SPAWN:
                if dragging {
                    spawn_particle(mouse_pos, particle_radius, particle_color)
                }
            case .PUSH:
                push_particles(mouse_pos, -push_force)
            case .PICK:
                pick_up_particles(mouse_pos, pick_radius, pick_force)
            case .NONE:
                // Do nothing
            }
            dragging = true
        } else {
            dragging = false
        }
        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(bg_color)
        draw_particles()

        mu.input_mouse_move(&mu_ctx, rl.GetMouseX(), rl.GetMouseY())
        if rl.IsMouseButtonPressed(.LEFT) {
            mu.input_mouse_down(&mu_ctx, rl.GetMouseX(), rl.GetMouseY(), .LEFT)
        }
        if rl.IsMouseButtonReleased(.LEFT) {
            mu.input_mouse_up(&mu_ctx, rl.GetMouseX(), rl.GetMouseY(), .LEFT)
        }
        
        mu.begin(&mu_ctx)
        draw_ui(&mu_ctx)
        mu.end(&mu_ctx)
        
        command: ^mu.Command
        for mu.next_command(&mu_ctx, &command) {
            #partial switch cmd in command.variant {
            case ^mu.Command_Rect:
                rl.DrawRectangle(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, 
                    {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a})
            case ^mu.Command_Text:
                // Simple text rendering - you might want to improve this
                rl.DrawText(cstring(raw_data(cmd.str)), cmd.pos.x, cmd.pos.y, 10, 
                    {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a})
            case ^mu.Command_Clip:
                rl.BeginScissorMode(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
            }
        }
        rl.DrawFPS(WIDTH / 2, 10)
        particle_count_text := fmt.tprintf("Particles: %d", len(particles))
        text_width := rl.MeasureText(cstring(raw_data(particle_count_text)), 20)
        rl.DrawText(cstring(raw_data(particle_count_text)), WIDTH - text_width - 10, 10, 20, rl.DARKGRAY)
    }
}