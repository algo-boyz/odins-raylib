package main

import rl "vendor:raylib"

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 450
    
    rl.InitWindow(WIDTH, HEIGHT, "Fade In/Out Text")
    
    // Text definition and position
    text :: "Hello Raylib!"
    text_position := rl.Vector2{
        f32(WIDTH) / 2 - f32(rl.MeasureText(text, 40)) / 2,
        f32(HEIGHT) / 2 - 20,
    } // Centered
    
    // Variables for fade in/out animation
    alpha: f32 = 0.0          // Alpha value (opacity) initialized to 0 (transparent)
    fade_speed: f32 = 0.5     // Fade speed (adjust to modify speed)
    fading_in := true         // Indicates if we're doing a fade in
    
    rl.SetTargetFPS(60) // Set target frame rate
    
    for !rl.WindowShouldClose() {
        // Control fade in/out animation
        if fading_in {
            alpha += fade_speed * rl.GetFrameTime() // Increase alpha
            if alpha >= 1.0 {
                alpha = 1.0      // Limit to 1.0 (completely opaque)
                fading_in = false // Start fade out
            }
        } else {
            alpha -= fade_speed * rl.GetFrameTime() // Decrease alpha
            if alpha <= 0.0 {
                alpha = 0.0     // Limit to 0.0 (completely transparent)
                fading_in = true // Restart fade in
            }
        }
        rl.BeginDrawing()        
        rl.ClearBackground(rl.RAYWHITE) // Clear screen with white
        
        // Draw text with color and alpha
        text_color := rl.BLACK // Define text color (black)
        text_color.a = u8(alpha * 255) // Apply alpha to color
        
        rl.DrawText(text, i32(text_position.x), i32(text_position.y), 40, text_color)
        rl.DrawText("Use ESC key to quit", 10, 10, 20, rl.LIGHTGRAY)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}