package main

import "btn"
import rl "vendor:raylib"

WIDTH  :: 800
HEIGHT :: 600

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Button Component")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)


    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()
    
    // Load assets
    btn_sound := rl.LoadSound("assets/buttonfx.wav")
    defer rl.UnloadSound(btn_sound)
    
    btn_texture := rl.LoadTexture("assets/button.png")
    defer rl.UnloadTexture(btn_texture)
    
    // Create multiple buttons
    play_button := btn.init(
        btn_texture, 
        btn_sound, 
        f32(WIDTH)/2 - f32(btn_texture.width)/2, 
        f32(HEIGHT)/2 - 100,
        "PLAY"
    )
    btn.set_text(&play_button, "PLAY", rl.WHITE, 24)
    
    settings_button := btn.init(
        btn_texture, 
        btn_sound, 
        f32(WIDTH)/2 - f32(btn_texture.width)/2, 
        f32(HEIGHT)/2 - 20,
        "SETTINGS"
    )
    btn.set_text(&settings_button, "SETTINGS", rl.WHITE, 20)
    
    quit_button := btn.init(
        btn_texture, 
        btn_sound, 
        f32(WIDTH)/2 - f32(btn_texture.width)/2, 
        f32(HEIGHT)/2 + 60,
        "QUIT"
    )
    btn.set_text(&quit_button, "QUIT", rl.WHITE, 24)

    message:cstring = "Click a button!"
    message_color := rl.BLACK
        
    for !rl.WindowShouldClose() {
        // Update buttons
        btn.update(&play_button)
        btn.update(&settings_button)
        btn.update(&quit_button)
        
        // Handle button clicks
        if btn.is_clicked(&play_button) {
            message = "Play button clicked!"
            message_color = rl.GREEN
        } else if btn.is_clicked(&settings_button) {
            message = "Settings button clicked!"
            message_color = rl.BLUE
        } else if btn.is_clicked(&quit_button) {
            message = "Quit button clicked!"
            message_color = rl.RED
            // Could add: break to exit the game loop
        }
        // Example of disabling/enabling buttons
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            btn.set_enabled(&settings_button, !settings_button.enabled)
        }
        // Draw everything
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw buttons
        btn.draw(&play_button)
        btn.draw(&settings_button)
        btn.draw(&quit_button)
        
        // Draw message
        message_width := rl.MeasureText(message, 20)
        rl.DrawText(message, (WIDTH - message_width) / 2, 50, 20, message_color)
        
        // Draw instructions
        rl.DrawText("Press SPACE to toggle Settings button", 10, HEIGHT - 30, 16, rl.DARKGRAY)
        
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
}