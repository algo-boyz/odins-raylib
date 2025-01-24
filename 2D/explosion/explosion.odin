package main

import rl "vendor:raylib"

NUM_FRAMES_PER_LINE :: 5
NUM_LINES :: 5

main :: proc() {
    // Initialization
    SCREEN_WIDTH :: 800
    SCREEN_HEIGHT :: 450
    
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [textures] example - sprite explosion")
    rl.InitAudioDevice()
    
    // Load resources
    fx_boom := rl.LoadSound("assets/boom.wav")
    explosion := rl.LoadTexture("assets/explosion.png")
    
    // Animation variables
    frame_width := f32(explosion.width) / NUM_FRAMES_PER_LINE
    frame_height := f32(explosion.height) / NUM_LINES
    current_frame := 0
    current_line := 0
    
    frame_rec := rl.Rectangle{
        x = 0,
        y = 0,
        width = frame_width,
        height = frame_height,
    }
    
    position := rl.Vector2{ 0, 0}
    
    active := false
    frames_counter := 0
    
    rl.SetTargetFPS(60)
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        
        // Check for mouse button press and activate explosion
        if rl.IsMouseButtonPressed(.LEFT) && !active {
            position = rl.GetMousePosition()
            active = true
            
            // Center explosion on mouse position
            position.x -= frame_width / 2
            position.y -= frame_height / 2
            
            rl.PlaySound(fx_boom)
        }
        
        // Update explosion animation
        if active {
            frames_counter += 1
            
            if frames_counter > 2 {
                current_frame += 1
                
                if current_frame >= NUM_FRAMES_PER_LINE {
                    current_frame = 0
                    current_line += 1
                    
                    if current_line >= NUM_LINES {
                        current_line = 0
                        active = false
                    }
                }
                
                frames_counter = 0
            }
        }
        
        // Update frame rectangle position for sprite animation
        frame_rec.x = frame_width * f32(current_frame)
        frame_rec.y = frame_height * f32(current_line)
        
        // Draw
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        if active {
            rl.DrawTextureRec(explosion, frame_rec, position, rl.WHITE)
        }
        
        rl.EndDrawing()
    }
    
    // Cleanup
    rl.UnloadTexture(explosion)
    rl.UnloadSound(fx_boom)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}