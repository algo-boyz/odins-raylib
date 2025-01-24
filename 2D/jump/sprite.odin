package main

import rl "vendor:raylib"

main :: proc() {
    // Window constants
    SCREEN_WIDTH :: 800
    SCREEN_HEIGHT :: 450
    
    // Physics constants
    GRAVITY :: 1
    JUMP_VELOCITY :: -13
    
    // Initialize window
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Run, run, run as fast as you can")
    
    // Load Scarfy texture
    scarfy := rl.LoadTexture("assets/scarfy.png")
    
    // Create rectangle for sprite
    scarfy_rec := rl.Rectangle{
        x = 0,
        y = 0,
        width = f32(scarfy.width) / 6,  // 6 frames in sprite sheet
        height = f32(scarfy.height),
    }
    
    // Set initial position
    scarfy_position := rl.Vector2{
        f32(SCREEN_WIDTH)/2 - scarfy_rec.width/2,
        f32(SCREEN_HEIGHT) - scarfy_rec.height,
    }
    
    // Game state
    velocity := 0
    in_air := false
    
    rl.SetTargetFPS(60)
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        
        // Ground check
        if scarfy_position.y >= f32(SCREEN_HEIGHT) - scarfy_rec.width {
            velocity = 0
            in_air = false
        } else {
            velocity += GRAVITY
            in_air = true
        }
        
        // Jump input
        if rl.IsKeyPressed(.SPACE) && !in_air {
            velocity += JUMP_VELOCITY
        }
        
        // Update position
        scarfy_position.y += f32(velocity)
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        rl.DrawTextureRec(
            scarfy,
            scarfy_rec,
            scarfy_position,
            rl.WHITE,
        )
        
        rl.EndDrawing()
    }
    
    // Cleanup
    rl.UnloadTexture(scarfy)
    rl.CloseWindow()
}