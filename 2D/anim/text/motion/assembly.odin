package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

MAX_TEXT_PARTS :: 6 // Maximum number of text parts (6 letters in "RAYLIB")

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 450
    rl.InitWindow(i32(WIDTH), i32(HEIGHT), "Text Assembly Animation")

    text := "RAYLIB"
    text_c := strings.clone_to_cstring(text)
    defer delete(text_c)
    
    // Individual letter parts
    text_parts: [MAX_TEXT_PARTS]cstring = {
        "R", "A", "Y", "L", "I", "B",
    }
    num_text_parts :: MAX_TEXT_PARTS

    // Initial random positions for each text part
    text_part_positions: [MAX_TEXT_PARTS]rl.Vector2
    for i in 0..<num_text_parts {
        text_part_positions[i].x = f32(rl.GetRandomValue(0, i32(WIDTH) - 40))
        text_part_positions[i].y = f32(rl.GetRandomValue(0, i32(HEIGHT) - 40))
    }

    // Final position for the assembled text (centered)
    target_text_width := rl.MeasureText(text_c, 40)
    target_text_position := rl.Vector2{
        (f32(WIDTH) - f32(target_text_width)) / 2.0,
        f32(HEIGHT) / 2.0 - 20.0,
    }

    // Movement parameters
    move_speed: f32 = 200.0
    snap_threshold: f32 = 3.0  // Increased threshold to prevent jittering
    
    // Track which parts have reached their destination
    parts_reached: [MAX_TEXT_PARTS]bool
    animation_complete := false
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()

        if !animation_complete {
            all_parts_reached := true
            
            for i in 0..<num_text_parts {
                // Skip if this part has already reached its destination
                if parts_reached[i] {
                    continue
                }
                // Calculate target position for this letter part
                prefix_width: i32 = 0
                if i > 0 {
                    temp_str := text[:i]
                    temp_cstr := strings.clone_to_cstring(temp_str)
                    defer delete(temp_cstr)
                    prefix_width = rl.MeasureText(temp_cstr, 40)
                }
                target_pos_for_part := rl.Vector2{
                    target_text_position.x + f32(prefix_width),
                    target_text_position.y,
                }
                // Calculate movement towards target
                delta_vec := target_pos_for_part - text_part_positions[i]
                distance := rl.Vector2Length(delta_vec)

                if distance > snap_threshold {
                    // Move towards target with easing for smoother animation
                    direction := rl.Vector2Normalize(delta_vec)
                    
                    // Apply easing: slow down as we get closer
                    speed_multiplier: f32 = 1.0
                    if distance < 50.0 {
                        speed_multiplier = distance / 50.0  // Gradual slowdown
                        speed_multiplier = max(speed_multiplier, 0.1)  // Minimum speed
                    }
                    movement := direction * (move_speed * speed_multiplier * delta_time)
                    
                    // Ensure we don't overshoot the target
                    if rl.Vector2Length(movement) > distance {
                        text_part_positions[i] = target_pos_for_part
                        parts_reached[i] = true
                    } else {
                        text_part_positions[i] = text_part_positions[i] + movement
                        all_parts_reached = false
                    }
                } else {
                    // Snap to exact target position
                    text_part_positions[i] = target_pos_for_part
                    parts_reached[i] = true
                }
                if !parts_reached[i] {
                    all_parts_reached = false
                }
            }
            animation_complete = all_parts_reached
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        if animation_complete {
            // Display the assembled text once animation is complete
            rl.DrawText(text_c, i32(target_text_position.x), i32(target_text_position.y), 40, rl.DARKBLUE)
        } else {
            // Display each text part at its current position
            for i in 0..<num_text_parts {
                rl.DrawText(text_parts[i], i32(text_part_positions[i].x), i32(text_part_positions[i].y), 40, rl.DARKBLUE)
            }
        }
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}