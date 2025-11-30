package main

import "core:strings"
import rl "vendor:raylib"

main :: proc() {
    WIDTH: i32 = 800
    HEIGHT: i32 = 450
    
    rl.InitWindow(WIDTH, HEIGHT, "Horizontal Mirror Effect")
    rl.SetTargetFPS(60)
    
    text: cstring = "Raylib Mirror"
    text_str := string(text)  // Convert cstring to string first
    text_bytes := transmute([]u8)text_str  // Then convert string to byte slice
    text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, 40, 1)
    text_position := rl.Vector2{
        f32(WIDTH) / 2 - text_size.x / 2,
        f32(HEIGHT) / 2 - text_size.y / 2,
    }
    
    mirror_factor: f32 = 0.0  // Value between 0.0 and 1.0 for mirror effect
    mirror_speed: f32 = 0.01
    mirror_increasing := true
    
    for !rl.WindowShouldClose() {
        // Mirror effect animation
        if mirror_increasing {
            mirror_factor += mirror_speed
            if mirror_factor >= 1.0 {
                mirror_factor = 1.0
                mirror_increasing = false
            }
        } else {
            mirror_factor -= mirror_speed
            if mirror_factor <= 0.0 {
                mirror_factor = 0.0
                mirror_increasing = true
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        // Draw text with progressive horizontal mirror effect
        text_len := len(text_str)
        char_x_offset: f32 = 0.0  // Track cumulative character width
        
        for i := 0; i < text_len; i += 1 {
            // Get individual character
            current_char_byte := text_bytes[i]
            current_char := [2]u8{current_char_byte, 0}  // Create null-terminated string
            current_char_cstr := cstring(raw_data(current_char[:]))
            
            // Get character width for proper spacing
            char_size := rl.MeasureTextEx(rl.GetFontDefault(), current_char_cstr, 40, 1) + 10 // Add some spacing
            
            // Calculate normal position (left to right)
            normal_x := text_position.x + char_x_offset
            
            // Calculate mirrored position (right to left)
            mirrored_x := text_position.x + text_size.x - char_x_offset - char_size.x
            
            // Interpolate between normal and mirrored positions
            mirror_x := normal_x * (1.0 - mirror_factor) + mirrored_x * mirror_factor
            
            // Draw character at interpolated position
            rl.DrawTextEx(
                rl.GetFontDefault(),
                current_char_cstr,
                rl.Vector2{mirror_x, text_position.y},
                40,
                1,
                rl.BLACK)
            // Update character offset for next character
            char_x_offset += char_size.x
        }
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}