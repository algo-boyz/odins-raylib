package main

import "core:fmt"

import rl "vendor:raylib"

is_texture_valid :: proc(texture: ^rl.Texture2D) -> bool {
    return texture.id > 0
}

// todo add sounds: https://keasigmadelta.com/assets/Uploads/2D-Character2.c
// sfx: https://www.fesliyanstudios.com/royalty-free-sound-effects-download/footsteps-on-grass-284
main :: proc() {
    // Window constants
    SCREEN_WIDTH :: 800
    SCREEN_HEIGHT :: 450
    
    // Physics constants
    GRAVITY :: 1
    JUMP_VELOCITY :: -13
    SCARFY_SPEED :: 5
    
    // Initialize window
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Run, run, run as fast as you can")
    
    // Load Scarfy texture
    filename:cstring = "assets/scarfy.png"
    texture := rl.LoadTexture(filename)
    if !is_texture_valid(&texture) {
        for !rl.WindowShouldClose() {
            rl.BeginDrawing()
            defer rl.EndDrawing()

            rl.ClearBackground(rl.WHITE)
            rl.DrawText(fmt.ctprintf("ERROR: Couldn't load %s.", filename), 20, 20, 20, rl.BLACK)
        }
        return
    }

    // Create rectangle for sprite
    num_frames := 6
    frame_width := f32(texture.width) / f32(num_frames)
    scarfy := rl.Rectangle{
        x = 0,
        y = 0,
        width = f32(texture.width) / 6,  // 6 frames in sprite sheet
        height = f32(texture.height),
    }
    
    // Set initial position
    scarfy_position := rl.Vector2{
        f32(SCREEN_WIDTH)/2 - scarfy.width/2,
        f32(SCREEN_HEIGHT) - scarfy.height,
    }
    
    // Game state
    velocity := rl.Vector2{0, 0}
    frame_delay := 5
    frame_delay_counter := 0
    frame_index := 0
    in_air := false
    
    rl.SetTargetFPS(60)
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
            velocity.x = f32(SCARFY_SPEED)
            if scarfy.width < 0 {
                scarfy.width = -scarfy.width
            }
        } else if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
            velocity.x = -f32(SCARFY_SPEED)
            if scarfy.width > 0 {
                scarfy.width = -scarfy.width
            }
        } else {
            velocity.x = 0
        }
        
        // Ground check
        if scarfy_position.y >= f32(SCREEN_HEIGHT) - scarfy.height {
            scarfy_position.y = f32(SCREEN_HEIGHT) - scarfy.height  // Prevent sinking below ground
            velocity.y = 0  // Only reset y-velocity
            in_air = false
        } else {
            velocity.y += GRAVITY  // Correctly add gravity to y-velocity
            in_air = true
        }
        
        // Jump input
        if rl.IsKeyPressed(.SPACE) && !in_air {
            velocity.y = JUMP_VELOCITY  // Set y-velocity instead of adding
        }

        // Update position
        scarfy_moving := velocity.x != 0 || velocity.y != 0
        scarfy_position += velocity

        // Prevent falling through floor
        if scarfy_position.y > f32(SCREEN_HEIGHT) - scarfy.height {
            scarfy_position.y = f32(SCREEN_HEIGHT) - scarfy.height
        }

        frame_delay_counter += 1
        if frame_delay_counter > frame_delay {
            frame_delay_counter = 0

            if scarfy_moving {
                frame_index = (frame_index + 1) % num_frames
                scarfy.x = frame_width * f32(frame_index)
            }
        }

        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        rl.DrawTextureRec(
            texture,
            scarfy,
            scarfy_position,
            rl.WHITE,
        )
        rl.EndDrawing()
    }
    
    // Cleanup
    rl.UnloadTexture(texture)
    rl.CloseWindow()
}