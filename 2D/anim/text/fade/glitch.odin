package main

import rl "vendor:raylib"
import "core:math/rand"
import "core:time"

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 450
    rl.InitWindow(WIDTH, HEIGHT, "Raylib Glitch Text")
    rl.SetTargetFPS(60)
    
    // Text to display
    text :: "GLITCHED TEXT"
    font_size :: 60
    text_position := rl.Vector2{
        f32(WIDTH) / 2.0 - f32(rl.MeasureText(text, font_size)) / 2.0,
        f32(HEIGHT) / 2.0 - f32(font_size) / 2.0,
    }
    // Glitch variables
    glitch_timer := 0
    glitch_duration :: 10  // Glitch duration in frames
    is_glitching := true

    for !rl.WindowShouldClose() {
        glitch_timer += 1
        if glitch_timer > glitch_duration {
            is_glitching = false
        }
        rl.BeginDrawing()        
        rl.ClearBackground(rl.RAYWHITE)
        
        if is_glitching {
            // Glitch effect
            // Loop to display text multiple times with random offsets
            for i in 0..<5 {
                offset_x := rand.float32_range(-10, 11)  // Random horizontal offset (-10 to 10)
                offset_y := rand.float32_range(-5, 6)    // Random vertical offset (-5 to 5)
                
                // Random color
                glitch_color := rl.Color{
                    u8(rand.float32_range(0, 256)),
                    u8(rand.float32_range(0, 256)),
                    u8(rand.float32_range(0, 256)),
                    255,
                }
                rl.DrawText(
                    text,
                    i32(text_position.x) + i32(offset_x),
                    i32(text_position.y) + i32(offset_y),
                    font_size,
                    glitch_color
                )
            }
        } else {
            // Display text normally
            rl.DrawText(text, i32(text_position.x), i32(text_position.y), font_size, rl.BLACK)
            // Display instructions after glitch
            rl.DrawText("Text fixed!", 10, 10, 20, rl.GREEN)
        }
        rl.EndDrawing()
    }
    rl.CloseWindow()
}