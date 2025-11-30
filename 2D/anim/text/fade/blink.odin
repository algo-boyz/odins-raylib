package main

import rl "vendor:raylib" // Import the Raylib package for Odin

main :: proc() {
    // Initialization
    WIDTH :: 800 // Use cint for C interop with Raylib functions expecting int
    HEIGHT :: 450

    rl.InitWindow(WIDTH, HEIGHT, "Blinking Text")

    // Text to display
    text :: "Blinking Text" // Odin string

    // Calculate text position to center it
    // MeasureText returns a cint (C int), which we'll use for calculations.
    // Vector2 components are f32, so we cast for the assignment.
    text_font_size :: 20
    text_width := rl.MeasureText(text, text_font_size)
    
    text_position: rl.Vector2 = {
        // Perform calculations with f32 for precision before assigning to Vector2 components
        cast(f32)WIDTH / 2.0 - cast(f32)text_width / 2.0,
        cast(f32)HEIGHT / 2.0 - cast(f32)text_font_size / 2.0, // Center vertically too
    }

    // Variables for blinking
    blink_timer:   f32 = 0.0  // Timer for blink interval
    blink_speed:   f32 = 0.5  // Blink speed in seconds (how long each state lasts)
    text_visible:  bool = true // Flag to control text visibility

    rl.SetTargetFPS(60) // Set our game to run at 60 frames-per-second

    // Main game loop
    // Loop continues as long as the window is open (WindowShouldClose() returns false)
    for !rl.WindowShouldClose() { 
        // Update
        // Increment timer by the time elapsed since the last frame
        blink_timer += rl.GetFrameTime() 

        // Check if the blink timer has exceeded the blink speed
        if blink_timer >= blink_speed {
            text_visible = !text_visible // Toggle text visibility
            blink_timer = 0.0            // Reset the blink timer
        }

        // Draw
        rl.BeginDrawing() // Start the drawing sequence

        rl.ClearBackground(rl.RAYWHITE) // Clear the background to white

        if text_visible {
            // Draw the text if it's currently visible
            // DrawText expects position components (x, y) and fontSize as cint
            rl.DrawText(
                text, 
                i32(text_position.x), 
                i32(text_position.y), 
                text_font_size, 
                rl.BLACK,
            )
        }
        rl.EndDrawing()
    }

    // De-initialization
    rl.CloseWindow() // Close window and free OpenGL context
}

