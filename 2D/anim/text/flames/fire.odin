package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Structure to represent a particle
Particle :: struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    color:    rl.Color,
    life:     f32,
    size:     f32,
}

MAX_PARTICLES :: 200
particles: [MAX_PARTICLES]Particle

// Fire parameters
INITIAL_VELOCITY_RANGE :: 30.0
PARTICLE_LIFE :: 2.0
PARTICLE_SIZE_START :: 8.0
PARTICLE_SIZE_END :: 1.0
GRAVITY_VEC2 :: rl.Vector2{0.0, -30.0} // Upward gravity for fire effect

// Text properties
text :: "FIRE TEXT"
font_size: i32 = 80
text_position: rl.Vector2
text_size: rl.Vector2

// Function to check if a point is inside the text
is_point_in_text :: proc(point: rl.Vector2) -> bool {
    // Simple bounding box check for text area
    return point.x >= text_position.x && 
           point.x <= text_position.x + text_size.x &&
           point.y >= text_position.y && 
           point.y <= text_position.y + text_size.y
}

// Function to get a random point along the text outline/area
get_text_emission_point :: proc() -> rl.Vector2 {
    // Generate random points within text bounds until we find one that's "close" to text
    for i in 0..<20 { // Max attempts to avoid infinite loop
        x := rand.float32_range(text_position.x, text_position.x + text_size.x)
        y := rand.float32_range(text_position.y + text_size.y * 0.7, text_position.y + text_size.y) // Bottom part of text
        
        point := rl.Vector2{x, y}
        return point
    }
    
    // Fallback to center bottom of text
    return rl.Vector2{
        text_position.x + text_size.x / 2,
        text_position.y + text_size.y,
    }
}

// Function to initialize a particle
init_particle :: proc(particle: ^Particle) {
    emission_point := get_text_emission_point()
    
    // Add some randomness around the emission point
    particle.position = rl.Vector2{
        emission_point.x + rand.float32_range(-5, 5),
        emission_point.y + rand.float32_range(-2, 2),
    }
    
    particle.velocity = rl.Vector2{
        rand.float32_range(-INITIAL_VELOCITY_RANGE, INITIAL_VELOCITY_RANGE),
        // Fixed: Corrected the range order for upward velocity
        rand.float32_range(-INITIAL_VELOCITY_RANGE * 1.5, -INITIAL_VELOCITY_RANGE * 0.5), // Mostly upward
    }
    
    particle.life = PARTICLE_LIFE + rand.float32_range(-0.5, 0.5) // Add some variation
    particle.size = PARTICLE_SIZE_START
    
    // Fire colors: red to orange to yellow
    color_temp := rand.float32_range(0.0, 1.0)
    if color_temp < 0.3 {
        // Red
        particle.color = rl.Color{255, u8(rand.float32_range(0, 100)), 0, 255}
    } else if color_temp < 0.7 {
        // Orange
        particle.color = rl.Color{255, u8(rand.float32_range(100, 200)), 0, 255}
    } else {
        // Yellow
        particle.color = rl.Color{255, u8(rand.float32_range(200, 255)), u8(rand.float32_range(0, 100)), 255}
    }
}

main :: proc() {
    // Initialization
    WIDTH: i32 = 800
    HEIGHT: i32 = 600
    
    rl.InitWindow(WIDTH, HEIGHT, "Fire Text Animation")
    rl.SetTargetFPS(60)
    
    // Calculate text position (centered)
    text_size = rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), 0)
    text_position = rl.Vector2{
        (f32(WIDTH) - text_size.x) / 2.0,
        (f32(HEIGHT) - text_size.y) / 2.0,
    }
    
    // Init particles
    for i in 0..<MAX_PARTICLES {
        init_particle(&particles[i])
    }
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        frame_time := rl.GetFrameTime()
        
        // Update particles
        for i in 0..<MAX_PARTICLES {
            particles[i].position.x += particles[i].velocity.x * frame_time
            particles[i].position.y += particles[i].velocity.y * frame_time
            particles[i].velocity.x += GRAVITY_VEC2.x * frame_time
            particles[i].velocity.y += GRAVITY_VEC2.y * frame_time
            particles[i].life -= frame_time
            
            // Size decreases over time
            life_ratio := particles[i].life / PARTICLE_LIFE
            particles[i].size = rl.Lerp(PARTICLE_SIZE_END, PARTICLE_SIZE_START, life_ratio)
            
            // Fade out over time
            particles[i].color.a = u8(life_ratio * 255)
            
            // Add some horizontal drift
            particles[i].velocity.x += rand.float32_range(-10, 10) * frame_time
            
            // Reset particle if its lifetime is over
            if particles[i].life <= 0.0 {
                init_particle(&particles[i])
            }
        }
        
        // Drawing
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.BLACK)
        
        // Draw particles behind the text
        for i in 0..<MAX_PARTICLES {
            rl.DrawCircleV(particles[i].position, particles[i].size, particles[i].color)
        }
        
        // Draw text with a slight glow effect
        // Draw text shadow/glow
        for offset_x in -2..=2 {
            for offset_y in -2..=2 {
                if offset_x != 0 || offset_y != 0 {
                    shadow_pos := rl.Vector2{text_position.x + f32(offset_x), text_position.y + f32(offset_y)}
                    rl.DrawTextEx(rl.GetFontDefault(), text, shadow_pos, f32(font_size), 0, rl.Color{255, 100, 0, 50})
                }
            }
        }
        
        // Draw main text
        rl.DrawTextEx(rl.GetFontDefault(), text, text_position, f32(font_size), 0, rl.WHITE)
        
        rl.EndDrawing()
    }
    
    // Cleanup
    rl.CloseWindow()
}