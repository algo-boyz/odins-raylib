package main

import rl "vendor:raylib"
import "core:math"
WIDTH :: 800
HEIGHT :: 450

main :: proc() {
    text :: "Raylib in Space!"
    font_size :: 40
    text_color := rl.WHITE
    
    rl.InitWindow(WIDTH, HEIGHT, "Levitating Text")
    rl.SetTargetFPS(60)
    
    // Initial text position (centered on screen)
    text_position := rl.Vector2{
        f32(WIDTH) / 2 - f32(rl.MeasureText(text, font_size)) / 2,
        f32(HEIGHT) / 2,
    }
    time: f32 = 0.0          // Elapsed time for sinusoidal movement
    amplitude: f32 = 30.0    // Amplitude of vertical movement
    frequency: f32 = 1.0     // Frequency of vertical movement
    
    for !rl.WindowShouldClose() {
        time += rl.GetFrameTime()
        
        // Calculate vertical position based on sinusoidal function
        text_position.y = f32(HEIGHT) / 2 + math.sin(time * frequency) * amplitude
        
        rl.BeginDrawing()        
        rl.ClearBackground(rl.BLACK)
        // Draw text at updated position
        rl.DrawText(text, i32(text_position.x), i32(text_position.y), font_size, text_color)
        
        // Add some stars in the background
        for i in 0..<100 {
            star_position := rl.Vector2{
                f32(rl.GetRandomValue(0, WIDTH)),
                f32(rl.GetRandomValue(0, HEIGHT)),
            }
            star_size := f32(rl.GetRandomValue(1, 3))
            // Stars with varying brightness
            star_alpha := f32(rl.GetRandomValue(20, 80)) / 100.0
            star_color := rl.Fade(rl.WHITE, star_alpha)
            rl.DrawPixelV(star_position, star_color)
        }
        rl.EndDrawing()
    }
    rl.CloseWindow()
}