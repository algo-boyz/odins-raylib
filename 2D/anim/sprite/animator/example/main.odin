package main

import "core:fmt"
import rl "vendor:raylib"
import anim "../"

WIDTH :: 800
HEIGHT :: 600

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "sprite animation")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(120)
    
    // Init animator and sprite
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
        WIDTH / 3.5,
        HEIGHT - 150,
    }
    
    // Assign sprite to animator
    anim.assign_sprite(&sprite_animator, sprite)
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        anim.play(&sprite_animator)
        
        // Draw
        rl.BeginDrawing()        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw the current frame of the animated sprite
        rl.DrawTextureRec(
            sprite_animator.sprite,
            sprite_animator.frame_rec,
            location,
            rl.WHITE,
        )
        rl.EndDrawing()
    }
}