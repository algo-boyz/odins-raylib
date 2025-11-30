package main

import "core:strings"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

MAX_LETTERS :: 20
PARTICLES_PER_LETTER :: 25  // Number of sand particles per letter
MAX_PARTICLES :: MAX_LETTERS * PARTICLES_PER_LETTER

SandParticle :: struct {
    position:      rl.Vector2,
    velocity:      rl.Vector2,
    size:          f32,
    life:          f32,
    max_life:      f32,
    color:         rl.Color,
    is_active:     bool,
}

LetterInfo :: struct {
    char:          u8,
    base_position: rl.Vector2,
    dispersion_timer: f32,
    is_dispersing: bool,
}

main :: proc() {
    // Configuration
    WIDTH: i32 = 800
    HEIGHT: i32 = 450
    
    rl.InitWindow(WIDTH, HEIGHT, "Sand Particle Text Dispersion")
    rl.SetTargetFPS(60)
    
    // Text to display
    text := "JEDI!"
    text_c := strings.clone_to_cstring(text)
    text_length := len(text)
    
    // Text parameters
    font_size: i32 = 80
    font := rl.GetFontDefault()
    
    // Text position at center of screen
    text_width := rl.MeasureText(text_c, font_size)
    text_position := rl.Vector2{
        f32(WIDTH - text_width) / 2.0,
        f32(HEIGHT - font_size) / 2.0,
    }
    
    // Init letter info
    letters: [MAX_LETTERS]LetterInfo
    for i in 0..<text_length {
        tmp := text
        substring := tmp[:i]
        substring_width := rl.MeasureText(strings.clone_to_cstring(substring), font_size)
        
        letters[i].char = text[i]
        letters[i].base_position = rl.Vector2{
            text_position.x + f32(substring_width),
            text_position.y,
        }
        letters[i].dispersion_timer = 0.0
        letters[i].is_dispersing = false
    }
    
    // Init sand particles
    particles: [MAX_PARTICLES]SandParticle
    particle_index := 0
    
    // Animation control
    dispersion_delay := f32(0.2)  // Delay between letter dispersions
    current_letter := 0
    global_timer := f32(0.0)
    
    for !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        global_timer += delta_time
        
        // Trigger letter dispersion with delay
        if current_letter < text_length && global_timer > f32(current_letter) * dispersion_delay + 1.0 {
            if !letters[current_letter].is_dispersing {
                letters[current_letter].is_dispersing = true
                
                // Create sand particles for this letter
                letter_width := rl.MeasureText("B", font_size)
                letter_height := font_size
                
                for p in 0..<PARTICLES_PER_LETTER {
                    if particle_index < MAX_PARTICLES {
                        // Random position within letter bounds
                        offset_x := f32(rand.int31_max(i32(letter_width)))
                        offset_y := f32(rand.int31_max(i32(letter_height)))
                        
                        particles[particle_index].position = rl.Vector2{
                            letters[current_letter].base_position.x + offset_x,
                            letters[current_letter].base_position.y + offset_y,
                        }
                        
                        // Random velocity with some upward bias and wind effect
                        angle := f32(rand.int31_max(360)) * rl.DEG2RAD
                        speed := f32(rand.int31_max(150) + 50)  // 50-200 speed
                        wind_force := f32(30 + rand.int31_max(40))  // Right wind
                        
                        particles[particle_index].velocity = rl.Vector2{
                            f32(math.cos(angle)) * speed + wind_force,
                            f32(math.sin(angle)) * speed - f32(rand.int31_max(50) + 20), // Slight upward bias
                        }
                        
                        particles[particle_index].size = f32(rand.int31_max(3) + 1)  // Size 1-4
                        particles[particle_index].max_life = f32(rand.int31_max(200) + 100) / 100.0  // 1-3 seconds
                        particles[particle_index].life = particles[particle_index].max_life
                        
                        // Color variation - sandy colors
                        base_color := u8(200 + rand.int31_max(56))  // 200-255
                        particles[particle_index].color = rl.Color{
                            base_color,
                            base_color - u8(rand.int31_max(30)),  // Slightly less green
                            base_color - u8(rand.int31_max(80)),  // Much less blue for sandy look
                            255,
                        }
                        
                        particles[particle_index].is_active = true
                        particle_index += 1
                    }
                }
                current_letter += 1
            }
        }
        
        // Update particles
        for i in 0..<particle_index {
            if particles[i].is_active {
                // Update position
                particles[i].position.x += particles[i].velocity.x * delta_time
                particles[i].position.y += particles[i].velocity.y * delta_time
                
                // Apply gravity
                particles[i].velocity.y += 300.0 * delta_time  // Gravity
                
                // Apply air resistance
                particles[i].velocity.x *= 0.995
                particles[i].velocity.y *= 0.998
                
                // Update life
                particles[i].life -= delta_time
                
                // Fade out over time
                life_ratio := particles[i].life / particles[i].max_life
                if life_ratio > 0 {
                    particles[i].color.a = u8(f32(255) * life_ratio)
                } else {
                    particles[i].is_active = false
                }
                
                // Deactivate if off screen
                if particles[i].position.x < -50 || particles[i].position.x > f32(WIDTH) + 50 ||
                   particles[i].position.y > f32(HEIGHT) + 50 {
                    particles[i].is_active = false
                }
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        // Draw intact letters (not yet dispersing)
        for i in 0..<text_length {
            if !letters[i].is_dispersing {
                // letter_str := string(letters[i].char)
                letter_str := "B"
                letter_cstr := strings.clone_to_cstring(letter_str)
                rl.DrawTextEx(font, letter_cstr, letters[i].base_position, f32(font_size), 0, rl.RAYWHITE)
            }
        }
        // Draw sand particles
        for i in 0..<particle_index {
            if particles[i].is_active {
                // Draw as circle for rounder particles
                rl.DrawCircleV(particles[i].position, particles[i].size / 2, particles[i].color)
            }
        }
        rl.DrawText("Watch the letters disperse into sand particles!", 10, 10, 20, rl.RAYWHITE)
        rl.DrawText("Press R to restart", 10, 40, 16, rl.GRAY)
        // Reset
        if rl.IsKeyPressed(rl.KeyboardKey.R) {
            current_letter = 0
            global_timer = 0.0
            particle_index = 0
            for i in 0..<text_length {
                letters[i].is_dispersing = false
            }
            for i in 0..<MAX_PARTICLES {
                particles[i].is_active = false
            }
        }
        rl.DrawFPS(10, HEIGHT - 30)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}