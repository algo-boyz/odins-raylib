package main

import rl "vendor:raylib" // Import the Raylib package for Odin
import "core:math"        // For sin, cos, PI, and potentially sqrt if needed

GRAVITY :: 0.2
FRICTION :: 0.95
TEXT_SIZE :: 40
ANIMATION_DURATION :: 2.0
ATTRACTION_FORCE :: 5.0

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 450

    rl.InitWindow(WIDTH, HEIGHT, "Odin - Magnetic/Floating Text")
    defer rl.CloseWindow() // Ensure window is closed when main exits
    rl.SetTargetFPS(60)
    
    text :: "Follow Me!"
    // Measure text size. rl.GetFontDefault() gets the default Raylib font.
    // TEXT_SIZE is an int, DrawTextEx expects fontSize as f32.
    text_size_vec := rl.MeasureTextEx(rl.GetFontDefault(), text, cast(f32)TEXT_SIZE, 1.0)

    // Position and Velocity of the text
    text_position: rl.Vector2 = {
        cast(f32)WIDTH / 2.0 - text_size_vec.x / 2.0,
        cast(f32)HEIGHT / 2.0 - text_size_vec.y / 2.0,
    }
    text_velocity: rl.Vector2 = {0, 0} // Init velocity to zero

    // Animation at startup (floating effect)
    initial_animation_timer: f32 = 0.0
    // animation_duration is defined as a global constant ANIMATION_DURATION
    initial_offset: rl.Vector2 = {50.0, 50.0} // Amplitude of initial float

    // Main game loop
    for !rl.WindowShouldClose() {
        // Update

        // Startup Animation
        if initial_animation_timer < ANIMATION_DURATION {
            initial_animation_timer += rl.GetFrameTime()
            animation_progress := initial_animation_timer / ANIMATION_DURATION // Progress from 0 to 1

            // Use sine/cosine for smooth movement. math.PI is from core:math
            text_position.x = (cast(f32)WIDTH / 2.0 - text_size_vec.x / 2.0) + 
                              math.sin_f32(animation_progress * math.PI * 4.0) * initial_offset.x
            text_position.y = (cast(f32)HEIGHT / 2.0 - text_size_vec.y / 2.0) + 
                              math.cos_f32(animation_progress * math.PI * 4.0) * initial_offset.y
        } else {
            // Once animation is done, text follows the mouse.
            // Calculate direction towards the mouse
            mouse_position := rl.GetMousePosition()
            direction: rl.Vector2 = {
                mouse_position.x - text_position.x,
                mouse_position.y - text_position.y,
            }
            // distance := Vector2Length(direction) // Using Raylib's built-in
            distance := rl.Vector2Length(direction)

            // Normalize direction (if distance > 0)
            if distance > 0 {
                direction.x = direction.x / distance
                direction.y = direction.y / distance
            }
            // Apply attraction force
            text_velocity.x += direction.x * ATTRACTION_FORCE
            text_velocity.y += direction.y * ATTRACTION_FORCE

            // Apply gravity (for a vertical floating effect)
            text_velocity.y += GRAVITY

            // Apply friction (to dampen movement)
            text_velocity.x *= FRICTION
            text_velocity.y *= FRICTION

            // Update position based on velocity
            text_position.x += text_velocity.x
            text_position.y += text_velocity.y

            // Keep text within screen bounds
            if text_position.x < 0 {
                text_position.x = 0
                text_velocity.x *= -0.5 // Reverse and reduce velocity on collision
            }
            if text_position.x > cast(f32)WIDTH - text_size_vec.x {
                text_position.x = cast(f32)WIDTH - text_size_vec.x
                text_velocity.x *= -0.5
            }
            if text_position.y < 0 {
                text_position.y = 0
                text_velocity.y *= -0.5
            }
            if text_position.y > cast(f32)HEIGHT - text_size_vec.y {
                text_position.y = cast(f32)HEIGHT - text_size_vec.y
                text_velocity.y *= -0.5
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        rl.DrawTextEx(rl.GetFontDefault(), text, text_position, cast(f32)TEXT_SIZE, 0, rl.BLACK)
        // Debug: Display mouse position
        // mouse_pos_str := fmt.tprintf("Mouse: %.0f, %.0f", rl.GetMousePosition().x, rl.GetMousePosition().y)
        // rl.DrawText(mouse_pos_str, 10, 10, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }
}

