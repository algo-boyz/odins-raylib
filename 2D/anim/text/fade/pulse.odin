package main

import rl "vendor:raylib"
import "core:math"

main :: proc() {
    WIDTH  :: 800
    HEIGHT :: 450
    rl.InitWindow(WIDTH, HEIGHT, "Pulsating Text")
    rl.SetTargetFPS(60)
    
    // Text to display
    text :: "Pulsating Text!"
    text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, 40, 1)
    
    // Variables for pulsation effect
    pulse_timer: f32 = 0.0
    pulse_speed: f32 = 1.0
    min_scale: f32 = 0.8
    max_scale: f32 = 1.2
    scale: f32 = 1.0
    
    for !rl.WindowShouldClose() {
        pulse_timer += rl.GetFrameTime() * pulse_speed
        // Calculate scale using sine function for pulsation effect
        scale = min_scale + (max_scale - min_scale) * (math.sin(pulse_timer) + 1.0) / 2.0
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        // Center the text
        text_position := rl.Vector2{
            (WIDTH - text_size.x * scale) / 2.0,
            (HEIGHT - text_size.y * scale) / 2.0,
        }
        // Draw text with calculated scale
        rl.DrawTextEx(
            rl.GetFontDefault(), 
            text, 
            text_position, 
            40 * scale, 
            1 * scale, 
            rl.BLACK
        )
        rl.EndDrawing()
    }
    rl.CloseWindow()
}