package main

import "core:fmt"
import rl "vendor:raylib"
import anim "./animator"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "sprite animation")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(120)
    
    // Initialize animator and sprite
    sprite_animator := anim.new_animator(
        animator_name = "GiveItAName",
        frames_per_row = 6,
        num_rows = 1,
        speed = 7,
        play_in_reverse = false,
        continuous = true,
        looping = true,
    )
    
    // Load sprite texture
    sprite := rl.LoadTexture("assets/scarfy.png")
    defer rl.UnloadTexture(sprite)
    
    // Set sprite location
    location := rl.Vector2{
        SCREEN_WIDTH / 3.5,
        SCREEN_HEIGHT - 150,
    }
    
    // Assign sprite to animator
    anim.assign_sprite(&sprite_animator, sprite)
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        anim.play(&sprite_animator)
        
        // Draw
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw the current frame of the animated sprite
        rl.DrawTextureRec(
            sprite_animator.sprite,
            sprite_animator.frame_rec,
            location,
            rl.WHITE,
        )
    }
}