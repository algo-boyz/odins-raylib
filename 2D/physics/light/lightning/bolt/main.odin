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
    segments:         [dynamic]Lightning_Segment,
    sparks:           [dynamic]Spark,
    start_pos:        rl.Vector2,
    end_pos:          rl.Vector2,
    active:           bool,
    timer:            f32, // Used for flicker/re-stroke timing
    branches:         [dynamic]Lightning_Bolt,
    allocated:        bool,     // Track if this bolt's memory is allocated
    // NEW: Fields for advanced branching and tapering
    depth:             int,      // Recursion depth of this branch
    max_initial_width: f32,      // Maximum width at the start of this bolt/branch
}

WIDTH         :: 1200
HEIGHT        :: 800
MAX_SEGMENTS         :: 30     // Max segments for the main bolt
MAX_SPARKS           :: 100
LIGHTNING_SPEED      :: 800.0  // Not currently used, but good to have
SPARK_COUNT          :: 8
INITIAL_MAX_WIDTH    :: 7.0    // NEW: Max width for a new user-created bolt
MIN_WIDTH            :: 0.5    // NEW: Minimum width for any segment
BRANCH_PROBABILITY   :: 0.15   // NEW: Base probability for branching
MAX_BRANCH_DEPTH     :: 3      // NEW: How deep branches can go

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Enhanced Lightning Arcs")
    rl.SetTargetFPS(60)
    
    lightning_bolts: [dynamic]Lightning_Bolt
    mouse_pressed := false
    start_pos: rl.Vector2
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        mouse_pos := rl.GetMousePosition()
        
        if rl.IsMouseButtonPressed(.LEFT) {
            mouse_pressed = true
            start_pos = mouse_pos
        }
        
        if rl.IsMouseButtonReleased(.LEFT) && mouse_pressed {
            mouse_pressed = false
            if rl.Vector2Distance(start_pos, mouse_pos) > 20 {
                // MODIFIED: Pass initial depth and width
                bolt := create_lightning_bolt(start_pos, mouse_pos, 0, INITIAL_MAX_WIDTH)
                append(&lightning_bolts, bolt)
            }
        }
        
        for i := 0; i < len(lightning_bolts); i += 1 {
            update_lightning_bolt(&lightning_bolts[i], dt)
        }
        
        for i := len(lightning_bolts) - 1; i >= 0; i -= 1 {
            bolt := &lightning_bolts[i]
            if !bolt.active && len(bolt.segments) == 0 && len(bolt.sparks) == 0 && len(bolt.branches) == 0 {
                free_lightning_bolt(bolt)
                ordered_remove(&lightning_bolts, i)
            }
        }
        
        rl.BeginDrawing()
        rl.ClearBackground({15, 15, 25, 255})
        
        if mouse_pressed {
            rl.DrawLineEx(start_pos, mouse_pos, 2, {100, 100, 150, 128})
        }
        
        for i := 0; i < len(lightning_bolts); i += 1 {
            draw_lightning_bolt(&lightning_bolts[i])
        }
        
        rl.DrawText("Click and drag to create enhanced lightning!", 10, 10, 20, rl.WHITE)
        rl.DrawText(rl.TextFormat("Active bolts: %d", len(lightning_bolts)), 10, 40, 16, rl.GRAY)
        
        rl.EndDrawing()
    }
    
    for i := 0; i < len(lightning_bolts); i += 1 {
        free_lightning_bolt(&lightning_bolts[i])
    }
    delete(lightning_bolts)
    
    rl.CloseWindow()
}

// MODIFIED: Added depth and max_width parameters
create_lightning_bolt :: proc(start, end: rl.Vector2, depth: int, max_width: f32) -> Lightning_Bolt {
    bolt: Lightning_Bolt
    bolt.segments = make([dynamic]Lightning_Segment, 0, MAX_SEGMENTS if depth == 0 else MAX_SEGMENTS / (depth + 1)) // Fewer segments for branches
    bolt.sparks = make([dynamic]Spark, 0, MAX_SPARKS)
    bolt.branches = make([dynamic]Lightning_Bolt, 0, 5 / (depth + 1)) // Fewer potential branches deeper down
    bolt.start_pos = start
    bolt.end_pos = end
    bolt.active = true
    bolt.timer = 0
    bolt.allocated = true
    // NEW: Init new fields
    bolt.depth = depth
    bolt.max_initial_width = max(max_width, MIN_WIDTH * 2) // Ensure max_width is reasonable

    generate_lightning_path(&bolt)
    return bolt
}

// NEW: Helper function to re-energize existing segments for strobing
re_energize_bolt :: proc(bolt: ^Lightning_Bolt) {
    if !bolt.allocated || len(bolt.segments) == 0 do return

    base_width_factor := rand.float32_range(0.8, 1.2) // Slight width variation for the re-stroke

    for i := 0; i < len(bolt.segments); i += 1 {
        segment := &bolt.segments[i]
        segment.age = rand.float32_range(0.0, 0.05) // Reset age, with slight variance for less uniform appearance

        // Recalculate width for tapering effect, potentially with a slight strobe variation
        taper_factor := 1.0 - (f32(i) / f32(len(bolt.segments)))
        current_width := MIN_WIDTH + (bolt.max_initial_width - MIN_WIDTH) * taper_factor
        segment.width = max(MIN_WIDTH, current_width * base_width_factor * rand.float32_range(0.9, 1.1))
    }

    // Optionally, re-energize branches too
    for i := 0; i < len(bolt.branches); i += 1 {
        if rand.float32() < 0.7 { // Chance to re-energize branch
             re_energize_bolt(&bolt.branches[i])
        }
    }
}


generate_lightning_path :: proc(bolt: ^Lightning_Bolt) {
    if !bolt.allocated do return
    
    // MODIFIED: Free old branches before generating new ones for this path
    for i := 0; i < len(bolt.branches); i += 1 {
        free_lightning_bolt(&bolt.branches[i])
    }
    clear(&bolt.branches) // Clear the slice of branch bolts
    clear(&bolt.segments)
    
    distance := rl.Vector2Distance(bolt.start_pos, bolt.end_pos)
    if distance < 10 { // Reduced minimum distance a bit
        return
    }
    
    // MODIFIED: Number of segments can depend on depth too
    num_segments := clamp(distance / (20.0 - f32(bolt.depth * 3)), 3, MAX_SEGMENTS) // Fewer segments for deeper branches
    if num_segments <= 0 { num_segments = 1 }
    segment_length := distance / f32(num_segments)
    
    current_pos := bolt.start_pos
    
    for i in 0..<num_segments {
        // Calculate direction towards the end_pos for the current segment
        // This helps guide the lightning even with jitter
        main_direction := rl.Vector2Normalize(bolt.end_pos - current_pos)
        
        // If this is the last segment, aim directly for the end_pos
        next_ideal_pos: rl.Vector2
        if i == num_segments - 1 {
            next_ideal_pos = bolt.end_pos
        } else {
            next_ideal_pos = current_pos + (main_direction * segment_length)
        }

        // MODIFIED: Jitter calculation for more perpendicular displacement
        jitter_strength := min(30.0 - f32(bolt.depth * 5), distance * 0.25) // Jitter reduces with depth
        jitter_strength = max(5.0, jitter_strength)

        perpendicular_dir := rl.Vector2{ -main_direction.y, main_direction.x }
        offset_val := rand.float32_range(-jitter_strength, jitter_strength)
        
        // For segments not the very last one, apply full jitter
        // The last actual segment before the final connection can also jitter
        jittered_pos := next_ideal_pos
        if i < num_segments -1 { // Don't jitter the final target point if it IS the target
             jittered_pos = next_ideal_pos + (perpendicular_dir * offset_val)
             // Add some smaller forward/backward jitter to vary segment length slightly
             jittered_pos += main_direction * rand.float32_range(-jitter_strength * 0.3, jitter_strength * 0.3)
        }


        // MODIFIED: Tapering width calculation
        // Closer to 1.0 at start (i=0), closer to 0.0 at end
        taper_factor := 1.0 - (f32(i) / f32(num_segments)) 
        current_width := MIN_WIDTH + (bolt.max_initial_width - MIN_WIDTH) * taper_factor
        current_width = max(MIN_WIDTH, current_width * rand.float32_range(0.8, 1.2)) // Add bit of randomness to width

        segment := Lightning_Segment{
            start = current_pos,
            end = jittered_pos, // Use the jittered position
            width = current_width,
            age = 0,
        }
        append(&bolt.segments, segment)
        
        // MODIFIED: Branching logic
        // Branch probability decreases with depth and if we already have many branches
        current_branch_probability := BRANCH_PROBABILITY / f32(bolt.depth + 1)
        if bolt.depth < MAX_BRANCH_DEPTH && len(bolt.branches) < (5 / (bolt.depth + 1)) && rand.float32() < current_branch_probability {
            branch_distance_factor := rand.float32_range(0.3, 0.7 - f32(bolt.depth) * 0.1) // Branches are shorter deeper down
            branch_distance := distance * branch_distance_factor
            branch_angle_offset := rand.float32_range(-math.PI/2.5, math.PI/2.5) // Wider potential angle range

            // Angle relative to the current segment's actual direction
            actual_segment_dir := rl.Vector2Normalize(jittered_pos - current_pos)
            if rl.Vector2LengthSqr(actual_segment_dir) == 0 { actual_segment_dir = main_direction } // fallback

            branch_angle_rad := math.atan2(actual_segment_dir.y, actual_segment_dir.x) + branch_angle_offset
            
            branch_dir := rl.Vector2{ math.cos(branch_angle_rad), math.sin(branch_angle_rad) }
            branch_end := jittered_pos + (branch_dir * branch_distance)
            
            // Branches are thinner than the parent segment
            branch_max_width := segment.width * rand.float32_range(0.5, 0.7)
            
            branch := create_lightning_bolt(jittered_pos, branch_end, bolt.depth + 1, branch_max_width)
            append(&bolt.branches, branch)
        }
        
        current_pos = jittered_pos // Update current_pos to the end of the new segment

        // Break if we're very close to the end_pos to prevent overshooting or tiny segments
        if rl.Vector2Distance(current_pos, bolt.end_pos) < segment_length * 0.5 {
            break
        }
    }
    
    // Always connect to the final end point if segments were generated
    if len(bolt.segments) > 0 {
        last_segment_end := bolt.segments[len(bolt.segments)-1].end
        if rl.Vector2Distance(last_segment_end, bolt.end_pos) > 1.0 { // If not already at the end
            final_taper_factor: f32 = 0.0 // Thinnest at the very end
            final_width := MIN_WIDTH + (bolt.max_initial_width - MIN_WIDTH) * final_taper_factor
            final_segment := Lightning_Segment{
                start = last_segment_end,
                end = bolt.end_pos,
                width = max(MIN_WIDTH, final_width),
                age = 0,
            }
            append(&bolt.segments, final_segment)
        }
    }
}

update_lightning_bolt :: proc(bolt: ^Lightning_Bolt, dt: f32) {
    if !bolt.allocated do return
    
    bolt.timer += dt // This timer is for flicker/re-stroke logic
    
    // Update segments (aging)
    has_active_segments := false
    for i := 0; i < len(bolt.segments); i += 1 {
        bolt.segments[i].age += dt
        if bolt.segments[i].age <= 0.4 { // Assuming 0.4s is max segment age
            has_active_segments = true
        }
    }
    
    // Remove old segments
    // Only remove if the bolt is not active OR if it's active and we are about to regenerate/fade anyway
    // This prevents segments from vanishing mid-flicker if re_energize is used.
    // However, for simplicity now, let's keep the original removal logic.
    // For a better strobing, you might delay segment removal until the bolt deactivates.
    for i := len(bolt.segments) - 1; i >= 0; i -= 1 {
        if bolt.segments[i].age > 0.4 { // Max age for a segment visual
            ordered_remove(&bolt.segments, i)
        }
    }
    
    // Generate sparks
    if bolt.active && len(bolt.segments) > 0 && len(bolt.sparks) < MAX_SPARKS {
        sparks_to_add := min(SPARK_COUNT, MAX_SPARKS - len(bolt.sparks))
        for _ in 0..<sparks_to_add {
            seg_idx := int(rand.float32_range(0, f32(len(bolt.segments) -1))) // Ensure valid index
            spark_pos_t := rand.float32() // Position along the segment
            spark_pos := rl.Vector2Lerp(bolt.segments[seg_idx].start, bolt.segments[seg_idx].end, spark_pos_t)
            
            spark := Spark{
                pos = spark_pos,
                vel = rl.Vector2{rand.float32_range(-80, 80), rand.float32_range(-80, 80)},
                life = rand.float32_range(0.2, 0.7), // Shorter life for sparks
                max_life = rand.float32_range(0.2, 0.7),
                color = { u8(rand.float32_range(180, 255)), u8(rand.float32_range(180, 255)), u8(rand.float32_range(200, 255)), 255},
            }
            append(&bolt.sparks, spark)
        }
    }
    
    // Update sparks (same as before)
    for i := 0; i < len(bolt.sparks); i += 1 {
        spark := &bolt.sparks[i]
        spark.pos += spark.vel * dt
        spark.vel *= 0.95 
        spark.life -= dt
        if spark.max_life > 0 { spark.color.a = u8(255 * max(0, spark.life / spark.max_life)) }
    }
    for i := len(bolt.sparks) - 1; i >= 0; i -= 1 {
        if bolt.sparks[i].life <= 0 { ordered_remove(&bolt.sparks, i) }
    }
    
    // Update branches
    for i := 0; i < len(bolt.branches); i += 1 {
        update_lightning_bolt(&bolt.branches[i], dt)
    }
    // Remove dead branches (branches manage their own segments)
    for i := len(bolt.branches) - 1; i >= 0; i -= 1 {
        branch := &bolt.branches[i]
        // A branch is dead if it's not active AND all its own segments and sparks are gone
        // AND its sub-branches are also dead (this is implicitly handled by recursive calls)
        if !branch.active && len(branch.segments) == 0 && len(branch.sparks) == 0 && len(branch.branches) == 0 {
            free_lightning_bolt(branch) // Free its memory
            ordered_remove(&bolt.branches, i)
        }
    }
    
    // MODIFIED: Strobing and regeneration logic
    if bolt.active && bolt.timer > (0.1 + rand.float32_range(0, 0.1)) { // Base flicker time, slightly randomized
        bolt.timer = 0 // Reset timer for next flicker decision
        
        random_action := rand.float32()
        if random_action < 0.45 { // ~45% chance to re-energize (strobe)
            re_energize_bolt(bolt)
        } else if random_action < 0.85 { // ~40% chance to generate a new path
            generate_lightning_path(bolt) // This will also clear and regenerate branches from the new path
        } else { // ~10% chance to deactivate the bolt
            bolt.active = false
            // When deactivating, don't immediately clear segments. Let them fade.
        }
    }

    // If bolt becomes inactive, and all its parts have faded, it will be cleaned up by the main loop.
    // If not active, but still has segments, let them fade out.
    if !bolt.active && !has_active_segments && len(bolt.sparks) == 0 && len(bolt.branches) == 0 {
        // This bolt is truly finished, main loop will catch it.
        // To ensure it's caught quickly if it deactivates itself and segments were already faded:
        clear(&bolt.segments) // Ensure segments are cleared if it becomes inactive
    }
}

draw_lightning_bolt :: proc(bolt: ^Lightning_Bolt) {
    if !bolt.allocated do return
    
    // Draw main segments
    for i := 0; i < len(bolt.segments); i += 1 {
        segment := &bolt.segments[i]
        // MODIFIED: Fade factor can be more aggressive or have a minimum visibility
        age_factor := clamp(1.0 - (segment.age / 0.35), 0.0, 1.0) // Segments fade a bit faster
        alpha := u8(255 * age_factor)
        
        if alpha > 10 && segment.width > 0 { // Only draw if somewhat visible
            // Adjust glow width based on segment width
            glow_width := segment.width * (2.0 + age_factor * 1.5) // Glow is wider when newer
            core_width := segment.width * (0.3 + age_factor * 0.3) // Core is also more pronounced when newer

            glow_color := rl.Color{80, 120, 255, alpha / 5} // Reduced alpha for outer glow
            rl.DrawLineEx(segment.start, segment.end, glow_width, glow_color)
            
            main_color := rl.Color{180, 200, 255, alpha}
            rl.DrawLineEx(segment.start, segment.end, segment.width, main_color)
            
            core_color := rl.Color{220, 230, 255, alpha} // Slightly less stark white for core unless very new
            if age_factor > 0.8 { core_color = rl.WHITE } // Brightest white for newest parts
            rl.DrawLineEx(segment.start, segment.end, core_width, core_color)
        }
    }
    
    // Draw sparks
    for i := 0; i < len(bolt.sparks); i += 1 {
        spark := &bolt.sparks[i]
        if spark.color.a > 10 {
            rl.DrawCircleV(spark.pos, clamp(spark.life * 3.0, 0.5, 1.5), spark.color) // Spark size can vary with life
        }
    }
    
    // Draw branches
    for i := 0; i < len(bolt.branches); i += 1 {
        draw_lightning_bolt(&bolt.branches[i])
    }
}

free_lightning_bolt :: proc(bolt: ^Lightning_Bolt) {
    if !bolt.allocated do return
    
    bolt.allocated = false // Mark as not allocated first to prevent re-entry issues
    
    for i := 0; i < len(bolt.branches); i += 1 {
        free_lightning_bolt(&bolt.branches[i])
    }
    
    delete(bolt.segments)
    delete(bolt.sparks)
    delete(bolt.branches) // This deletes the dynamic array itself, elements (bolts) are freed above
}