package main

import "core:strings"
import "core:math/rand"
import rl "vendor:raylib"

MAX_LETTERS :: 20  // Maximum text length

LetterParticle :: struct {
    position:      rl.Vector2,
    velocity:      rl.Vector2,
    rotation:      f32,
    rotation_speed: f32,
    color:         rl.Color,
    is_active:     bool,
}

main :: proc() {
    // Configuration
    WIDTH: i32 = 800
    HEIGHT: i32 = 450
    
    rl.InitWindow(WIDTH, HEIGHT, "Collapsing Text Raylib")
    rl.SetTargetFPS(60)
    
    // Text to display
    text :: "Raylib!"
    text_c := strings.clone_to_cstring(text)
    text_length := len(text)
    
    // Text parameters
    font_size: i32 = 60
    font := rl.GetFontDefault()  // Use default font
    
    // Text position at center of screen
    text_width := rl.MeasureText(text_c, font_size)
    text_position := rl.Vector2{
        f32(WIDTH - text_width) / 2.0,
        f32(HEIGHT - font_size) / 2.0,
    }
    
    // Init particles (one per letter)
    particles: [MAX_LETTERS]LetterParticle
    
    for i in 0..<text_length {
        // Get substring from start to current position to measure width
        tmp := text
        substring := tmp[:i]
        substring_width := rl.MeasureText(strings.clone_to_cstring(substring), font_size)
        
        particles[i].position = rl.Vector2{
            text_position.x + f32(substring_width),
            text_position.y,
        }
        
        particles[i].velocity = rl.Vector2{
            f32(rand.int31_max(101) - 50) / 100.0 * 200,  // Random velocity -100 to 100, scaled to -200 to 200
            f32(rand.int31_max(101) - 50) / 100.0 * 200,
        }
        
        particles[i].rotation = 0.0
        particles[i].rotation_speed = f32(rand.int31_max(201) - 100) / 100.0 * 360  // Random rotation -360 to 360
        particles[i].color = rl.RAYWHITE
        particles[i].is_active = true
    }
    
    // Main loop
    for !rl.WindowShouldClose() {
        // Update
        delta_time := rl.GetFrameTime()
        
        // Update particles
        for i in 0..<text_length {
            if particles[i].is_active {
                particles[i].position.x += particles[i].velocity.x * delta_time
                particles[i].position.y += particles[i].velocity.y * delta_time
                particles[i].rotation += particles[i].rotation_speed * delta_time
                
                // Gradually slow down velocity
                particles[i].velocity.x *= 0.98
                particles[i].velocity.y *= 0.98
                
                // Decrease opacity for fading effect
                fade_amount := u8(255.0 * delta_time * 0.5)  // Reduce alpha progressively
                if particles[i].color.a > fade_amount {
                    particles[i].color.a -= fade_amount
                } else {
                    particles[i].color.a = 0
                }
                
                // Deactivate particle if completely transparent
                if particles[i].color.a <= 0 {
                    particles[i].is_active = false
                }
            }
        }
        
        // Draw
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.BLACK)
        
        // Draw letters as particles
        for i in 0..<text_length {
            if particles[i].is_active {
                // Get single character as string
                tmp := text
                letter := tmp[i:i+1]
                letter_cstr := strings.clone_to_cstring(letter)
                
                // Apply fade based on alpha
                faded_color := rl.Fade(particles[i].color, f32(particles[i].color.a) / 255.0)
                
                rl.DrawTextEx(
                    font, 
                    letter_cstr, 
                    particles[i].position, 
                    f32(font_size), 
                    0, 
                    faded_color
                )
                
                // Debug rectangle (uncomment to see particle bounds)
                // rl.DrawRectanglePro(
                //     rl.Rectangle{particles[i].position.x, particles[i].position.y, 10, 10},
                //     rl.Vector2{5, 5},
                //     particles[i].rotation,
                //     particles[i].color
                // )
            }
        }
        
        // Display FPS
        rl.DrawFPS(10, 10)
        
        rl.EndDrawing()
    }
    
    // Close window and free memory
    rl.CloseWindow()
}