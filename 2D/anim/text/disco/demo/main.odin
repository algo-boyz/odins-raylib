package main

import "../../"
import rl "vendor:raylib"

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 450
    rl.InitWindow(WIDTH, HEIGHT, "Multi Disco")
    rl.SetTargetFPS(60)
    
    // Create multiple disco texts with different configurations
    title := disco.create(
        "DISCO PARTY!", 
        {f32(WIDTH) / 2, 100}
    )
    disco.set_colors(&title, rl.MAGENTA, rl.PINK)
    disco.set_timing(&title, 0.15, 3) // Faster, more frequent
    
    subtitle := disco.create_custom({
        text = "Feel the beat!",
        position = {f32(WIDTH) / 2, 200},
        font_size = 30,
        base_color = rl.BLUE,
        highlight_color = rl.SKYBLUE,
        sparkle_interval = 0.08,
        highlight_chance = 4,
        font = rl.GetFontDefault(),
    })
    
    footer := disco.create(
        "Press SPACE for more fun!", 
        {f32(WIDTH) / 2, f32(HEIGHT) - 80},
        25
    )
    disco.set_colors(&footer, rl.GREEN, rl.LIME)
    disco.set_timing(&footer, 0.2, 6) // Slower, less frequent
    
    // Additional disco text that can be toggled
    bonus := disco.create(
        "🌟 BONUS DISCO! 🌟", 
        {f32(WIDTH) / 2, 300}
    )
    disco.set_colors(&bonus, rl.ORANGE, rl.RED)
    show_bonus := false
    
    for !rl.WindowShouldClose() {
        // Toggle bonus text with SPACE
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            show_bonus = !show_bonus
        }
        // Update all disco animations
        disco.update(&title, rl.GetFrameTime())
        disco.update(&subtitle, rl.GetFrameTime())
        disco.update(&footer, rl.GetFrameTime())
        if show_bonus {
            disco.update(&bonus, rl.GetFrameTime())
        }
        rl.BeginDrawing()
        {
            rl.ClearBackground(rl.DARKPURPLE)
            // Draw all disco texts
            disco.draw_centered(&title)
            disco.draw_centered(&subtitle)
            disco.draw_centered(&footer)
            
            if show_bonus {
                disco.draw_centered(&bonus)
            }
            rl.DrawText("Press ESC to quit", 10, 10, 20, rl.GRAY)
        }
        rl.EndDrawing()
    }
    rl.CloseWindow()
}