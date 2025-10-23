package main

import "core:math"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

// Lightning segment represents a single segment of a lightning bolt
Lightning_Segment :: struct {
    start: rl.Vector2,
    end:   rl.Vector2,
    width: f32,
    age:   f32,
}

// Spark particle for visual effects
Spark :: struct {
    pos:      rl.Vector2,
    vel:      rl.Vector2,
    life:     f32,
    max_life: f32,
    color:    rl.Color,
}

// Lightning bolt containing multiple segments and branches
Lightning_Bolt :: struct {
    segments:  [dynamic]Lightning_Segment,
    sparks:    [dynamic]Spark,
    start_pos: rl.Vector2,
    end_pos:   rl.Vector2,
    active:    bool,
    timer:     f32,
    branches:  [dynamic]Lightning_Bolt,
    allocated: bool, // Track if this bolt's memory is allocated
}

WIDTH  :: 1200
HEIGHT :: 800
MAX_SEGMENTS  :: 30
MAX_SPARKS    :: 100
LIGHTNING_SPEED :: 800.0
SPARK_COUNT   :: 8

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Lightning Arcs with Sparks")
    rl.SetTargetFPS(60)
    
    lightning_bolts: [dynamic]Lightning_Bolt
    mouse_pressed := false
    start_pos: rl.Vector2
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        mouse_pos := rl.GetMousePosition()
        
        // Handle input - create lightning on mouse drag
        if rl.IsMouseButtonPressed(.LEFT) {
            mouse_pressed = true
            start_pos = mouse_pos
        }
        
        if rl.IsMouseButtonReleased(.LEFT) && mouse_pressed {
            mouse_pressed = false
            // Only create lightning if we have a meaningful distance
            if rl.Vector2Distance(start_pos, mouse_pos) > 20 {
                bolt := create_lightning_bolt(start_pos, mouse_pos)
                append(&lightning_bolts, bolt)
            }
        }
        
        // Update all lightning bolts
        for i := 0; i < len(lightning_bolts); i += 1 {
            update_lightning_bolt(&lightning_bolts[i], dt)
        }
        
        // Remove dead lightning bolts
        for i := len(lightning_bolts) - 1; i >= 0; i -= 1 {
            bolt := &lightning_bolts[i]
            if !bolt.active && len(bolt.segments) == 0 && len(bolt.sparks) == 0 {
                free_lightning_bolt(bolt)
                ordered_remove(&lightning_bolts, i)
            }
        }
        
        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground({15, 15, 25, 255})
        
        // Draw preview line when dragging
        if mouse_pressed {
            rl.DrawLineEx(start_pos, mouse_pos, 2, {100, 100, 150, 128})
        }
        
        // Draw all lightning bolts
        for i := 0; i < len(lightning_bolts); i += 1 {
            draw_lightning_bolt(&lightning_bolts[i])
        }
        
        // Draw instructions
        rl.DrawText("Click and drag to create lightning arcs!", 10, 10, 20, rl.WHITE)
        rl.DrawText(rl.TextFormat("Active bolts: %d", len(lightning_bolts)), 10, 40, 16, rl.GRAY)
        
        rl.EndDrawing()
    }
    
    // Cleanup
    for i := 0; i < len(lightning_bolts); i += 1 {
        free_lightning_bolt(&lightning_bolts[i])
    }
    delete(lightning_bolts)
    
    rl.CloseWindow()
}

create_lightning_bolt :: proc(start, end: rl.Vector2) -> Lightning_Bolt {
    bolt: Lightning_Bolt
    bolt.segments = make([dynamic]Lightning_Segment, 0, MAX_SEGMENTS)
    bolt.sparks = make([dynamic]Spark, 0, MAX_SPARKS)
    bolt.branches = make([dynamic]Lightning_Bolt, 0, 5)
    bolt.start_pos = start
    bolt.end_pos = end
    bolt.active = true
    bolt.timer = 0
    bolt.allocated = true
    
    generate_lightning_path(&bolt)
    return bolt
}

generate_lightning_path :: proc(bolt: ^Lightning_Bolt) {
    if !bolt.allocated do return
    
    clear(&bolt.segments)
    
    distance := rl.Vector2Distance(bolt.start_pos, bolt.end_pos)
    if distance < 20 {
        return
    }
    
    num_segments := min(int(distance / 25), MAX_SEGMENTS)
    segment_length := distance / f32(num_segments)
    
    current_pos := bolt.start_pos
    direction := rl.Vector2Normalize(bolt.end_pos - bolt.start_pos)
    
    for i in 0..<num_segments {
        remaining_distance := rl.Vector2Distance(current_pos, bolt.end_pos)
        if remaining_distance < segment_length {
            break
        }
        
        // Add some randomness to the lightning path
        jitter_strength := min(30.0, remaining_distance * 0.3)
        jitter := rl.Vector2{
            rand.float32_range(-jitter_strength, jitter_strength),
            rand.float32_range(-jitter_strength, jitter_strength),
        }
        
        next_pos := current_pos + (direction * segment_length) + jitter
        
        segment := Lightning_Segment{
            start = current_pos,
            end = next_pos,
            width = rand.float32_range(2, 5),
            age = 0,
        }
        
        append(&bolt.segments, segment)
        
        // Reduced chance for branches to avoid complexity
        if rand.float32() < 0.1 && len(bolt.branches) < 2 {
            branch_distance := rand.float32_range(30, 80)
            branch_angle := rand.float32_range(-math.PI/3, math.PI/3)
            
            branch_dir := rl.Vector2{
                math.cos(math.atan2(direction.y, direction.x) + branch_angle),
                math.sin(math.atan2(direction.y, direction.x) + branch_angle),
            }
            
            branch_end := next_pos + (branch_dir * branch_distance)
            branch := create_lightning_bolt(next_pos, branch_end)
            append(&bolt.branches, branch)
        }
        
        current_pos = next_pos
    }
    
    // Always connect to end point if we have segments
    if len(bolt.segments) > 0 {
        final_segment := Lightning_Segment{
            start = current_pos,
            end = bolt.end_pos,
            width = 3,
            age = 0,
        }
        append(&bolt.segments, final_segment)
    }
}

update_lightning_bolt :: proc(bolt: ^Lightning_Bolt, dt: f32) {
    if !bolt.allocated do return
    
    bolt.timer += dt
    
    // Update segments
    for i := 0; i < len(bolt.segments); i += 1 {
        bolt.segments[i].age += dt
    }
    
    // Remove old segments
    for i := len(bolt.segments) - 1; i >= 0; i -= 1 {
        if bolt.segments[i].age > 0.4 {
            ordered_remove(&bolt.segments, i)
        }
    }
    
    // Generate sparks only if we have segments
    if bolt.active && len(bolt.segments) > 0 && len(bolt.sparks) < MAX_SPARKS {
        sparks_to_add := min(SPARK_COUNT, MAX_SPARKS - len(bolt.sparks))
        
        for _ in 0..<sparks_to_add {
            // Pick a random segment safely
            seg_idx := int(rand.float32_range(0, f32(len(bolt.segments))))
            if seg_idx >= len(bolt.segments) do continue
            
            spark_pos := bolt.segments[seg_idx].end
            
            spark := Spark{
                pos = spark_pos,
                vel = rl.Vector2{
                    rand.float32_range(-80, 80),
                    rand.float32_range(-80, 80),
                },
                life = rand.float32_range(0.3, 1.0),
                max_life = rand.float32_range(0.3, 1.0),
                color = {
                    u8(rand.float32_range(180, 255)),
                    u8(rand.float32_range(120, 255)),
                    u8(rand.float32_range(40, 120)),
                    255,
                },
            }
            append(&bolt.sparks, spark)
        }
    }
    
    // Update sparks
    for i := 0; i < len(bolt.sparks); i += 1 {
        spark := &bolt.sparks[i]
        spark.pos += spark.vel * dt
        spark.vel *= 0.95 // Friction
        spark.life -= dt
        
        // Fade alpha
        if spark.max_life > 0 {
            life_ratio := max(0, spark.life / spark.max_life)
            spark.color.a = u8(255 * life_ratio)
        }
    }
    
    // Remove dead sparks
    for i := len(bolt.sparks) - 1; i >= 0; i -= 1 {
        if bolt.sparks[i].life <= 0 {
            ordered_remove(&bolt.sparks, i)
        }
    }
    
    // Update branches
    for i := 0; i < len(bolt.branches); i += 1 {
        update_lightning_bolt(&bolt.branches[i], dt)
    }
    
    // Remove dead branches
    for i := len(bolt.branches) - 1; i >= 0; i -= 1 {
        branch := &bolt.branches[i]
        if !branch.active && len(branch.segments) == 0 && len(branch.sparks) == 0 {
            free_lightning_bolt(branch)
            ordered_remove(&bolt.branches, i)
        }
    }
    
    // Regenerate lightning occasionally
    if bolt.active && bolt.timer > 0.15 {
        if rand.float32() < 0.6 {
            generate_lightning_path(bolt)
        }
        bolt.timer = 0
        
        // Chance to deactivate
        if rand.float32() < 0.03 {
            bolt.active = false
        }
    }
}

draw_lightning_bolt :: proc(bolt: ^Lightning_Bolt) {
    if !bolt.allocated do return
    
    // Draw main segments with glow effect
    for i := 0; i < len(bolt.segments); i += 1 {
        segment := &bolt.segments[i]
        age_factor := max(0, 1.0 - (segment.age / 0.4))
        alpha := u8(255 * age_factor)
        
        if alpha > 0 {
            // Outer glow
            glow_color := rl.Color{80, 120, 255, alpha / 4}
            rl.DrawLineEx(segment.start, segment.end, segment.width * 2.5, glow_color)
            
            // Main lightning
            main_color := rl.Color{180, 200, 255, alpha}
            rl.DrawLineEx(segment.start, segment.end, segment.width, main_color)
            
            // Core
            core_color := rl.Color{255, 255, 255, alpha}
            rl.DrawLineEx(segment.start, segment.end, segment.width * 0.4, core_color)
        }
    }
    
    // Draw sparks
    for i := 0; i < len(bolt.sparks); i += 1 {
        spark := &bolt.sparks[i]
        if spark.color.a > 0 {
            rl.DrawCircleV(spark.pos, 1.5, spark.color)
        }
    }
    
    // Draw branches
    for i := 0; i < len(bolt.branches); i += 1 {
        draw_lightning_bolt(&bolt.branches[i])
    }
}

free_lightning_bolt :: proc(bolt: ^Lightning_Bolt) {
    if !bolt.allocated do return
    
    bolt.allocated = false
    
    // Free branches first
    for i := 0; i < len(bolt.branches); i += 1 {
        free_lightning_bolt(&bolt.branches[i])
    }
    
    // Then free our arrays
    delete(bolt.segments)
    delete(bolt.sparks)
    delete(bolt.branches)
}