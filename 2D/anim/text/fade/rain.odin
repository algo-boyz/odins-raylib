package main

import rl "vendor:raylib"

MAX_TEXT_LENGTH :: 256
MAX_DROPS :: 100

TextDrop :: struct {
    text:     [2]u8, // store a single character + null terminator
    position: rl.Vector2,
    speed:    f32,
    color:    rl.Color,
    active:   bool,
}

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 450

    rl.InitWindow(WIDTH, HEIGHT, "Text Rain")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    // Text to display
    full_text := "Raining Text" 
    // Array to store text drops
    drops: [MAX_DROPS]TextDrop 

    // Init drops
    for i in 0..<MAX_DROPS {
        drops[i].position = rl.Vector2 {
            cast(f32)rl.GetRandomValue(0, WIDTH - 10), // Subtract a bit to avoid drawing off-edge
            cast(f32)rl.GetRandomValue(-500, 0),
        }
        drops[i].speed = cast(f32)rl.GetRandomValue(50, 150)
        drops[i].color = rl.LIGHTGRAY
    }
    timer:      f32  = 0.0
    spawn_rate: f32  = 0.1 // Frequency of new drops (in seconds)
    text_index: int  = 0   // Current character index in full_text

    for !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        timer += delta_time

        // Create new drops
        // `len(full_text)` gives the number of bytes, which is fine for ASCII-like strings.
        if timer > spawn_rate && text_index < len(full_text) {
            timer = 0.0
            // Find an inactive drop
            for i in 0..<MAX_DROPS {
                if !drops[i].active {
                    drops[i].active = true
                    drops[i].text[0] = full_text[text_index] // Assign the character byte
                    drops[i].text[1] = 0                     // Null terminator
                    drops[i].position = rl.Vector2{
                        cast(f32)rl.GetRandomValue(0, WIDTH - 10), // -10 to keep char on screen
                        -20.0, // Start just above the screen
                    }
                    drops[i].speed = cast(f32)rl.GetRandomValue(50, 150)
                    drops[i].color = rl.LIGHTGRAY // Or cycle colors, etc.
                    text_index += 1
                    break // Exit loop after activating one drop
                }
            }
        }
        // Update drop positions
        for i in 0..<MAX_DROPS {
            if drops[i].active {
                drops[i].position.y += drops[i].speed * delta_time

                // Deactivate drop when it goes off screen
                if drops[i].position.y > cast(f32)HEIGHT + 20 {
                    drops[i].active = false
                    drops[i].text[0] = 0 // Clear text by setting the first char to null
                }
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        // Draw drops
        for i in 0..<MAX_DROPS {
            if drops[i].active {
                rl.DrawText(
                    cstring(&drops[i].text[0]), 
                    cast(i32)drops[i].position.x, 
                    cast(i32)drops[i].position.y, 
                    20, // Font size
                    drops[i].color,
                )
            }
        }
        rl.DrawFPS(10, 10) // Display frames per second
        rl.EndDrawing()
    }
}

