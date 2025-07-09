package fluid

import "base:runtime"
import "core:thread"
import "core:math"
import "core:simd"
import "core:sync"

import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 600

PRESSURE_RADIUS: f32 = 20
VISCOSITY_RADIUS :: 20
PRESSURE :: 100
VISCOSITY :: 50
COLLISION_FORCE :: 100

PARTICLE_RADIUS :: 3
PARTICLE_COLOR :: rl.SKYBLUE

GRAVITY :: rl.Vector2{ 0, 300 }

PARTICLE_COUNT :: 1000

Grid :: struct {
    cells: [][]Cell,
    cell_size: f32, 
    width, height: int,
}

Cell :: struct {
    particles: [dynamic]^Particle,
    mutex: sync.Mutex,
}

Particle :: struct {
    pos : rl.Vector2,
    velocity : rl.Vector2,
    acceleration : rl.Vector2,
}

new_grid :: proc() -> Grid {
    cell_size := PRESSURE_RADIUS * 1.618
    width := int(WIDTH / cell_size) + 1
    height := int(HEIGHT / cell_size) + 1
    
    cells := make([][]Cell, height)
    for i in 0..<height {
        cells[i] = make([]Cell, width)
        for j in 0..<width {
            cells[i][j].particles = make([dynamic]^Particle)
        }
    }
    
    return Grid{cells, cell_size, width, height}
}

update_grid :: proc(grid: ^Grid, particles: []Particle) {
    // Clear grid
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            clear(&grid.cells[y][x].particles)
        }
    }
    
    // Insert particles
    for &p in particles {
        x := int(p.pos.x / grid.cell_size)
        y := int(p.pos.y / grid.cell_size)
        if x >= 0 && x < grid.width && y >= 0 && y < grid.height {
            sync.mutex_lock(&grid.cells[y][x].mutex)
            append(&grid.cells[y][x].particles, &p)
            sync.mutex_unlock(&grid.cells[y][x].mutex)
        }
    }
}

apply_forces :: proc(p: ^Particle, grid: ^Grid) {
    x := int(p.pos.x / grid.cell_size)
    y := int(p.pos.y / grid.cell_size)
    
    // Check neighboring cells
    for dy in -1..=1 {
        ny := y + dy
        if ny < 0 || ny >= grid.height { continue }
        
        for dx in -1..=1 {
            nx := x + dx
            if nx < 0 || nx >= grid.width { continue }
            
            cell := &grid.cells[ny][nx]
            sync.mutex_lock(&cell.mutex)
            for &other in cell.particles {
                if p == other { continue }
                particle_force_particle(p, other)
            }
            sync.mutex_unlock(&cell.mutex)
        }
    }
}

mov_particles :: proc(particles: []Particle, grid: ^Grid, dt: f32) {
    thread_count :: 8
    batch_size := len(particles) / thread_count
    
    Thread_Data :: struct {
        particles: []Particle,
        grid: ^Grid,
        dt: f32,
        start, end: int,
    }
    
    worker :: proc(t: ^thread.Thread) {
        data := (^Thread_Data)(t.data)
        
        for i := data.start; i < data.end; i += 1 {
            apply_forces(&data.particles[i], data.grid)
            mov_particle(&data.particles[i], data.dt)
            collide_boundary(&data.particles[i], {0, -HEIGHT * 5, WIDTH, HEIGHT * 6})
            force_on_boundary(&data.particles[i], {0, -HEIGHT * 5, WIDTH, HEIGHT * 6})
        }
    }
    
    threads := make([]^thread.Thread, thread_count)
    thread_data := make([]Thread_Data, thread_count)
    
    update_grid(grid, particles)
    
    for i := 0; i < thread_count; i += 1 {
        start := i * batch_size
        end := start + batch_size if i < thread_count-1 else len(particles)
        
        thread_data[i] = Thread_Data{
            particles = particles,
            grid = grid,
            dt = dt,
            start = start,
            end = end,
        }
        
        threads[i] = thread.create(worker)
        assert(threads[i] != nil)
        threads[i].data = &thread_data[i]
        thread.start(threads[i])
    }
    
    for t in threads {
        thread.join(t)
        thread.destroy(t)
    }
    
    delete(threads)
    delete(thread_data)
}

mov_particle :: proc(p : ^Particle, dt : f32) {
    p.velocity += p.acceleration * dt
    p.pos += p.velocity * dt
    p.acceleration = GRAVITY
}

force_on_boundary :: proc(p : ^Particle, boundary : rl.Rectangle) {
    PARTICLE_ENERGY_LOSS :: 1
    force := rl.Vector2(0)
    if p.pos.x - PRESSURE_RADIUS < boundary.x {
        force.x = (boundary.x - (p.pos.x - PRESSURE_RADIUS))
    } else if p.pos.x + PRESSURE_RADIUS > boundary.x + boundary.width {
        force.x = (boundary.x + boundary.width) - (p.pos.x + PRESSURE_RADIUS)
    } 
    if p.pos.y - PRESSURE_RADIUS < boundary.y {
        force.y = boundary.y - (p.pos.y - PRESSURE_RADIUS)
    } else if p.pos.y + PRESSURE_RADIUS > boundary.y + boundary.height {
        force.y = (boundary.y + boundary.height) - (p.pos.y + PRESSURE_RADIUS)
    }
    if force != 0 {
        p.velocity *= PARTICLE_ENERGY_LOSS
    }
    apply_force(p, force * COLLISION_FORCE)
}

particle_force_particle :: proc(p : ^Particle, other: ^Particle) {
    kernel_sin :: proc(dist, h: f32) -> f32 {
        return math.sin(((h - dist) / h - 0.5) * (math.PI / 2)) / 2 + 0.5
    }
    kernel_lin :: proc(dist, h: f32) -> f32 {
        return (h - dist) / h
    }
    kernel : proc(dist, h: f32) -> f32 : kernel_sin
    ENERGY_LOSS :: 1
    dist := rl.Vector2Distance(p.pos, other.pos)
    if dist < PRESSURE_RADIUS {
        p.velocity *= ENERGY_LOSS
        other.velocity *= ENERGY_LOSS
    }
    h : f32 = PRESSURE_RADIUS*2
    if dist < h {
        w := kernel(dist, h)
        apply_force(p, rl.Vector2Normalize(p.pos - other.pos) * w * PRESSURE)
        apply_force(other, rl.Vector2Normalize(other.pos - p.pos) * w * PRESSURE)
    }
    h = VISCOSITY_RADIUS*2
    if dist < h {
        w := kernel(dist, h)
        p_force := rl.Vector2Normalize((other.pos + other.velocity) - (p.pos + p.velocity))
        other_force := rl.Vector2Normalize((p.pos + p.velocity) - (other.pos + other.velocity))
        apply_force(p, p_force * w * VISCOSITY)
        apply_force(other, other_force * w * VISCOSITY)
    }
}

apply_force :: proc(p : ^Particle, force : rl.Vector2) {
    p.acceleration += force
}

collide_boundary :: proc(p : ^Particle, boundary : rl.Rectangle) {
    if p.pos.x < boundary.x {
        p.pos.x = boundary.x
        p.velocity.x = 0
    } else if p.pos.x > boundary.x + boundary.width {
        p.pos.x = boundary.x + boundary.width
        p.velocity.x = 0
    }
    if p.pos.y < boundary.y {
        p.pos.y = boundary.y
        p.velocity.y = 0
    } else if p.pos.y > boundary.y + boundary.height {
        p.pos.y = boundary.y + boundary.height
        p.velocity.y = 0
    }
}

main :: proc() {
    // Initialize particles
    particles: [PARTICLE_COUNT]Particle
    grid := new_grid()
    
    rl.InitWindow(WIDTH, HEIGHT, "2D Fluid Simulation")
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        
        mouse := rl.GetMousePosition()
        for &p in particles {
            if rl.Vector2Distance(mouse, p.pos) < 100 {
                force: rl.Vector2
                if rl.IsMouseButtonDown(.LEFT) {
                    force = mouse - p.pos
                } else if rl.IsMouseButtonDown(.RIGHT) {
                    force = p.pos - mouse
                }
                apply_force(&p, force * 17)
            }
        }
        mov_particles(particles[:], &grid, dt)
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{0x18, 0x18, 0x18, 0xFF})
        
        for particle in particles {
            rl.DrawCircleV(particle.pos, PRESSURE_RADIUS, rl.ColorAlpha(PARTICLE_COLOR, 0.05))
            rl.DrawCircleV(particle.pos, PARTICLE_RADIUS, PARTICLE_COLOR)
        }
        
        rl.DrawFPS(WIDTH - 100, 10)
        rl.EndDrawing()
    }
}