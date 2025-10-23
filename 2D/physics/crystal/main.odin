package crystal

import "core:fmt"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Particle :: struct {
    x, y:    i32,
    stable:  bool,
    cycle:   i16,
    col:     rl.Color,
    age:     i32,
}

RectI :: struct {
    x1, y1, x2, y2: i32,
}

Walking_Strategy :: enum {
    RANDOMWALK,
    CENTERWISE_JITTER,
    CENTERWISE_JITTER_2,
    CENTERWISE_JITTER_3,
    CENTERWISE_JITTER_4,
}

Neighbor_Check :: enum {
    FOUR_NEIGHBORHOOD,
    FOUR_DIAGONAL_NEIGHBORHOOD,
    EIGHT_NEIGHBORHOOD,
}

// Global state
walking: Walking_Strategy = .CENTERWISE_JITTER
neighbor_check: Neighbor_Check = .FOUR_NEIGHBORHOOD

PARTICLE_COUNT :: 10000
MAX_AGE :: 2000
colors := [?]rl.Color{rl.BLACK, rl.RED, rl.BLUE, rl.GREEN, rl.PURPLE, rl.DARKGREEN}
save_frame_min_change :: 5
do_diagonal_movement := false
max_steps_before_draw :: 3
save_frames := false

cycle_walking_strategy :: proc() {
    walking = Walking_Strategy((int(walking) + 1) % len(Walking_Strategy))
}

get_walking_name :: proc() -> string {
    switch walking {
    case .RANDOMWALK:
        return "Random walk"
    case .CENTERWISE_JITTER:
        return "Center nudges"
    case .CENTERWISE_JITTER_2:
        return "Center nudges(x2)"
    case .CENTERWISE_JITTER_3:
        return "Center nudges(x4)"
    case .CENTERWISE_JITTER_4:
        return "Center nudges(x8)"
    }
    return "FAILURE"
}

cycle_neighborhood_check :: proc() {
    neighbor_check = Neighbor_Check((int(neighbor_check) + 1) % len(Neighbor_Check))
}

get_neighbor_check_name :: proc() -> string {
    switch neighbor_check {
    case .FOUR_NEIGHBORHOOD:
        return "4-cardinal"
    case .FOUR_DIAGONAL_NEIGHBORHOOD:
        return "4-diagonal"
    case .EIGHT_NEIGHBORHOOD:
        return "8-neighborhood"
    }
    return "FAILURE"
}

init_particle :: proc() -> Particle {
    p := Particle{}
    p.x = rand.int31_max(rl.GetScreenWidth())
    p.y = rand.int31_max(rl.GetScreenHeight())
    p.stable = false
    p.col = rl.BLACK
    p.age = 0
    p.cycle = 0
    return p
}

init_particles :: proc(particles: []Particle) {
    for i in 0..<len(particles) {
        particles[i] = init_particle()
    }
}

particle_is_adjacent :: proc(a, b: ^Particle) -> bool {
    switch neighbor_check {
    case .FOUR_NEIGHBORHOOD:
        return 1 == (abs(a.x - b.x) + abs(a.y - b.y))
    case .FOUR_DIAGONAL_NEIGHBORHOOD:
        return 1 == abs(a.x - b.x) && 1 == abs(a.y - b.y)
    case .EIGHT_NEIGHBORHOOD:
        return 1 >= abs(a.x - b.x) && 1 >= abs(a.y - b.y)
    }
    return false
}

move_to_border :: proc(p: ^Particle) {
    x, y: i32
    switch rand.int_max(4) {
    case 0: // Left border
        x = 0
        y = rand.int31_max(rl.GetScreenHeight())
    case 1: // Top border
        x = rand.int31_max(rl.GetScreenWidth())
        y = 0
    case 2: // Bottom border
        x = rand.int31_max(rl.GetScreenWidth())
        y = rl.GetScreenHeight()
    case 3: // Right border
        x = rl.GetScreenWidth()
        y = rand.int31_max(rl.GetScreenHeight())
    }
    p.x = x
    p.y = y
}

random_walk :: proc(p: ^Particle, diagonals: bool) {
    max_dir := 2 if !diagonals else 3
    switch rand.int_max(max_dir) {
    case 0:
        p.x += rand.int31_max(3) - 1
    case 1:
        p.y += rand.int31_max(3) - 1
    case 2:
        p.x += rand.int31_max(3) - 1
        p.y += rand.int31_max(3) - 1
    }
}

center_nudge_chance := [?]i32{60, 30, 15, 7}

centerwise_jitter_walk :: proc(p: ^Particle, centerwise_nudge: i32) {
    if rand.int31_max(centerwise_nudge) == 1 {
        max_dir := 2 if !do_diagonal_movement else 3
        switch rand.int_max(max_dir) {
        case 0:
            p.x += -1 if p.x > rl.GetScreenWidth() / 2 else 1
        case 1:
            p.y += -1 if p.y > rl.GetScreenHeight() / 2 else 1
        case 2:
            p.x += -1 if p.x > rl.GetScreenWidth() / 2 else 1
            p.y += -1 if p.y > rl.GetScreenHeight() / 2 else 1
        }
    } else {
        random_walk(p, do_diagonal_movement)
    }
}

walk_particle :: proc(p: ^Particle) {
    switch walking {
    case .RANDOMWALK:
        random_walk(p, do_diagonal_movement)
    case .CENTERWISE_JITTER, .CENTERWISE_JITTER_2, .CENTERWISE_JITTER_3, .CENTERWISE_JITTER_4:
        idx := int(walking) - int(Walking_Strategy.CENTERWISE_JITTER)
        centerwise_jitter_walk(p, center_nudge_chance[idx])
    }
}

wrap_around :: proc(min_val, max_val, val: i32) -> i32 {
    if val < min_val {
        return max_val - 1
    }
    if val >= max_val {
        return min_val
    }
    return val
}

interp_color :: proc(c1, c2: rl.Color, t: f32) -> rl.Color {
    t_clamped := clamp(t, 0.0, 1.0)
    return rl.Color{
        u8(f32(c1.r) * (1.0 - t_clamped) + f32(c2.r) * t_clamped),
        u8(f32(c1.g) * (1.0 - t_clamped) + f32(c2.g) * t_clamped),
        u8(f32(c1.b) * (1.0 - t_clamped) + f32(c2.b) * t_clamped),
        u8(f32(c1.a) * (1.0 - t_clamped) + f32(c2.a) * t_clamped),
    }
}

get_particle_color :: proc(p: ^Particle) -> rl.Color {
    color_count := len(colors)
    c1 := colors[int(p.cycle) % color_count]
    c2 := colors[(int(p.cycle) + 1) % color_count]
    return interp_color(c1, c2, f32(p.age) / f32(MAX_AGE))
}

particle_step :: proc(p: ^Particle, others: []Particle) -> bool {
    collision := false
    
    if p.stable {
        return false
    }
    // Check for collisions and adjacency
    for i in 0..<len(others) {
        if !others[i].stable {
            break
        }
        
        // Check for collision (same position)
        if others[i].x == p.x && others[i].y == p.y {
            collision = true
            break
        }
        
        // Check for adjacency
        if particle_is_adjacent(p, &others[i]) {
            p.stable = true
            p.col = get_particle_color(p)
            break
        }
    }
    if !p.stable {
        walk_particle(p)
    }

    // Wrap around screen boundaries
    p.x = wrap_around(0, rl.GetScreenWidth(), p.x)
    p.y = wrap_around(0, rl.GetScreenHeight(), p.y)
    
    p.age += 1

    if collision {
        move_to_border(p)
        p.stable = false
    }
    if p.age > MAX_AGE {
        p.cycle += 1
        p.age = 0
    }
    return p.stable
}

compare_particle :: proc(a, b: Particle) -> slice.Ordering {
    if b.stable && !a.stable {
        return .Less
    }
    if !b.stable && a.stable {
        return .Greater
    }
    return .Equal
}

format_status :: proc() -> string {
    return fmt.tprintf("Walking: %s(diagonal: %c)\nNeighbor check: %s\nFPS: %.1f\nSaving frames? %c",
        get_walking_name(),
        'Y' if do_diagonal_movement else 'N',
        get_neighbor_check_name(),
        1.0 / rl.GetFrameTime(),
        'Y' if save_frames else 'N')
}

main :: proc() {
    rl.InitWindow(425, 425, "Crystal")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    
    particles: [PARTICLE_COUNT]Particle
    stable_particles := 0
    draw_all := true
    draw_text := true
    frames_dumped := 0
    images_dumped := 0
    
    // Init first particle at center
    particles[0] = Particle{
        x = rl.GetScreenWidth() / 2,
        y = rl.GetScreenHeight() / 2,
        stable = true,
        cycle = 0,
        col = rl.BLACK,
        age = 0,
    }
    // Init remaining particles
    init_particles(particles[1:])
    
    thing := rl.GenImageColor(425, 425, rl.RAYWHITE)
    defer rl.UnloadImage(thing)
    
    last_stable_particles := 0
    
    for !rl.WindowShouldClose() {
        dump_image := false
        stable_particles = 0
        
        // Step particles
        for step in 0..<max_steps_before_draw {
            stop := false
            
            for i := PARTICLE_COUNT - 1; i >= 0; i -= 1 {
                if particles[i].stable {
                    break
                }
                
                stabilized := particle_step(&particles[i], particles[:])
                if stabilized {
                    stop = true
                }
            }
            if stop {
                // Sort particles to move stable ones to the front
                slice.reverse_sort_by_cmp(particles[:], compare_particle)
            }
            if stop {
                break
            }
        }
        
        // Handle input
        if rl.IsKeyPressed(.A) {
            draw_all = !draw_all
        }
        if rl.IsKeyPressed(.T) {
            draw_text = !draw_text
        }
        if rl.IsKeyPressed(.R) {
            particles[0].x = rl.GetScreenWidth() / 2
            particles[0].y = rl.GetScreenHeight() / 2
            init_particles(particles[1:])
            rl.ImageClearBackground(&thing, rl.RAYWHITE)
            frames_dumped = 0
            fmt.println("RESET")
        }
        if rl.IsKeyPressed(.D) {
            do_diagonal_movement = !do_diagonal_movement
        }
        if rl.IsKeyPressed(.W) {
            cycle_walking_strategy()
        }
        if rl.IsKeyPressed(.N) {
            cycle_neighborhood_check()
        }
        if rl.IsKeyPressed(.F) {
            save_frames = !save_frames
        }
        if rl.IsKeyPressed(.O) {
            dump_image = true
        }
        
        // Drawing
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw particles
        for i in 0..<PARTICLE_COUNT {
            if particles[i].stable {
                stable_particles += 1
            }
            
            if draw_all || particles[i].stable {
                rl.DrawPixel(particles[i].x, particles[i].y, particles[i].col)
            }
            
            if particles[i].stable {
                rl.ImageDrawPixel(&thing, particles[i].x, particles[i].y, particles[i].col)
            }
        }
        
        // Draw UI text
        if draw_text && stable_particles != PARTICLE_COUNT {
            text := fmt.ctprintf("Stable Particles %d", stable_particles)
            rl.DrawText(text, 100, rl.GetScreenHeight() / 8, 16, rl.BLACK)
            
            status := format_status()
            status_cstr := fmt.ctprintf("%s", status)
            rl.DrawText(status_cstr, 100, rl.GetScreenHeight() / 8 + 16, 16, rl.BLACK)
        }
        
        // Handle screenshot
        if dump_image {
            screenshot_name := fmt.ctprintf("Crystal-%03d.png", images_dumped)
            rl.TakeScreenshot(screenshot_name)
            images_dumped += 1
        }
        
        // Handle frame saving
        if stable_particles - last_stable_particles > save_frame_min_change && save_frames {
            frame_name := fmt.ctprintf("Frame-%05d.png", frames_dumped)
            rl.ExportImage(thing, frame_name)
            frames_dumped += 1
            last_stable_particles = stable_particles
        }
    }
}