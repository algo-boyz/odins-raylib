package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import ta "../../"

// Typewriter Effect Animation
TypewriterAnimation :: struct {
    full_text: string,
    current_text: string,
    char_index: int,
    char_timer: f32,
    char_delay: f32,
    is_complete: bool,
    position: rl.Vector2,
    font_size: f32,
    color: rl.Color,
}

init_typewriter :: proc(text: string, pos: rl.Vector2, size: f32, delay: f32 = 0.05) -> TypewriterAnimation {
    return TypewriterAnimation{
        full_text = text,
        current_text = "",
        char_index = 0,
        char_timer = 0,
        char_delay = delay,
        is_complete = false,
        position = pos,
        font_size = size,
        color = rl.WHITE,
    }
}

update_typewriter :: proc(typewriter: ^TypewriterAnimation, dt: f32) {
    if typewriter.is_complete do return
    
    typewriter.char_timer += dt
    
    if typewriter.char_timer >= typewriter.char_delay {
        if typewriter.char_index < len(typewriter.full_text) {
            typewriter.current_text = typewriter.full_text[:typewriter.char_index + 1]
            typewriter.char_index += 1
            typewriter.char_timer = 0
        } else {
            typewriter.is_complete = true
        }
    }
}

render_typewriter :: proc(typewriter: ^TypewriterAnimation, font: rl.Font) {
    rl.DrawTextEx(font, rl.TextFormat("%s", typewriter.current_text), 
                 typewriter.position, typewriter.font_size, 1, typewriter.color)
    
    // Optional: Add blinking cursor
    if !typewriter.is_complete {
        cursor_x := typewriter.position.x + rl.MeasureTextEx(font, rl.TextFormat("%s", typewriter.current_text), 
                                                            typewriter.font_size, 1).x
        if int(typewriter.char_timer * 4) % 2 == 0 { // Blink every 0.25 seconds
            rl.DrawTextEx(font, "_", rl.Vector2{cursor_x, typewriter.position.y}, 
                         typewriter.font_size, 1, typewriter.color)
        }
    }
}

// Particle Text Effect
ParticleTextSystem :: struct {
    particles: [dynamic]TextParticle,
    font: rl.Font,
}

TextParticle :: struct {
    char: rune,
    position: rl.Vector2,
    velocity: rl.Vector2,
    lifetime: f32,
    max_lifetime: f32,
    color: rl.Color,
    rotation: f32,
    angular_velocity: f32,
    scale: f32,
}

init_particle_text_system :: proc(font: rl.Font) -> ParticleTextSystem {
    return ParticleTextSystem{
        particles = make([dynamic]TextParticle),
        font = font,
    }
}

explode_text :: proc(system: ^ParticleTextSystem, text: string, center: rl.Vector2, font_size: f32) {
    for char, i in text {
        if char == ' ' do continue
        
        // Fixed: Random angle from 0 to 2π radians (360 degrees)
        angle := f32(rand.int31_max(1000)) / 1000.0 * 2.0 * math.PI
        
        // Reduced speed for better visibility
        speed := 100 + f32(rand.int31_max(100)) // 50-150 pixels per second
        
        particle := TextParticle{
            char = char,
            position = center,
            velocity = rl.Vector2{
                math.cos(angle) * speed,
                math.sin(angle) * speed,
            },
            lifetime = 0,
            max_lifetime = 3.0 + f32(rand.int31_max(200)) / 100.0, // 3-5 seconds instead of 2-4
            color = rl.Color{
                u8(200 + rand.int31_max(56)), // 200-255
                u8(150 + rand.int31_max(106)), // 150-255  
                u8(50 + rand.int31_max(206)), // 50-255
                255,
            },
            rotation = 0,
            angular_velocity = (f32(rand.int31_max(1000)) / 1000.0 - 0.5) * 360, // ±180 degrees per second
            scale = 1.0,
        }
        
        append(&system.particles, particle)
    }
}

update_particle_text_system :: proc(system: ^ParticleTextSystem, dt: f32) {
    gravity := f32(150) // Reduced gravity for slower fall
    air_resistance := f32(0.98) // Add slight air resistance for more natural movement
    
    for i := len(system.particles) - 1; i >= 0; i -= 1 {
        particle := &system.particles[i]
        
        // Update physics
        particle.lifetime += dt
        particle.position.x += particle.velocity.x * dt
        particle.position.y += particle.velocity.y * dt
        particle.velocity.y += gravity * dt // Apply gravity
        
        // Apply air resistance
        particle.velocity.x *= air_resistance
        particle.velocity.y *= air_resistance
        
        particle.rotation += particle.angular_velocity * dt
        
        // Fade out over time - slower fade for better visibility
        fade_progress := particle.lifetime / particle.max_lifetime
        fade_factor := 1.0 - (fade_progress * fade_progress) // Quadratic fade for smoother transition
        particle.color.a = u8(255 * fade_factor)
        particle.scale = 1.0 - fade_progress * 0.3 // Less shrinking
        
        // Remove expired particles
        if particle.lifetime >= particle.max_lifetime {
            ordered_remove(&system.particles, i)
        }
    }
}

render_particle_text_system :: proc(system: ^ParticleTextSystem, font_size: f32) {
    for particle in system.particles {
        char_str := rl.TextFormat("%c", particle.char)
        
        // Calculate scaled font size
        scaled_size := font_size * particle.scale
        
        // Simple rotation simulation by offsetting position
        // (For true rotation, you'd need more complex rendering)
        render_pos := particle.position
        
        rl.DrawTextEx(system.font, char_str, render_pos, scaled_size, 1, particle.color)
    }
}

// Chain Animation System
ChainAnimation :: struct {
    animations: []ta.TextAnimation,
    current_step: int,
    chain_delay: f32,
    auto_advance: bool,
}

create_chain_animation :: proc(manager: ^ta.AnimationManager, texts: []string, 
                              base_config: ta.TextAnimationConfig, 
                              chain_delay: f32 = 0.5) -> ChainAnimation {
    
    for text, i in texts {
        config := base_config
        config.text = text
        config.start_delay = f32(i) * chain_delay
        config.y += f32(i) * 60 // Stack vertically
        
        ta.add_animation(manager, config)
    }
    
    return ChainAnimation{
        current_step = 0,
        chain_delay = chain_delay,
        auto_advance = true,
    }
}

main :: proc() {
    WIDTH: i32 = 1200
    HEIGHT: i32 = 800
    
    rl.InitWindow(WIDTH, HEIGHT, "Text Animation Package Demo")
    defer rl.CloseWindow()
    
    font := rl.LoadFontEx("fonts/font.ttf", 32, nil, 0)
    defer rl.UnloadFont(font)
    
    // Create multiple animation managers for different effects
    title_manager := ta.init_animation_manager(font, ta.SUNSET_GRADIENT)
    defer ta.destroy_animation_manager(&title_manager)
    
    ui_manager := ta.init_animation_manager(font, ta.OCEAN_GRADIENT)
    defer ta.destroy_animation_manager(&ui_manager)
    
    // Typewriter system
    typewriter := init_typewriter("Welcome to the Text Animation Package Demo!", 
                                 rl.Vector2{100, 600}, 24, 0.03)
    
    // Particle system
    particle_system := init_particle_text_system(font)
    defer delete(particle_system.particles)
    
    // Demo sequence
    demo_stage := 0
    stage_timer := f32(0)
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        stage_timer += dt
        
        // Progress through demo stages
        switch demo_stage {
        case 0: // Title animation
            if stage_timer > 1.0 {
                ta.add_animation(&title_manager, ta.create_slide_animation(
                    "TEXT ANIMATION",
                    f32(WIDTH) / 2, 150, 64,
                    0, 500, 2.0, .EASE_OUT_BACK))
                ta.add_animation(&title_manager, ta.create_slide_animation(
                    "PACKAGE DEMO",
                    f32(WIDTH) / 2, 220, 48,
                    0.8, 400, 1.5, .EASE_OUT_CUBIC))
                demo_stage = 1
            }
            
        case 1: // UI elements
            if stage_timer > 4.0 {
                ui_elements := []string{"Feature 1: Smooth Animations", "Feature 2: Custom Gradients", 
                                       "Feature 3: Multiple Easing Functions", "Feature 4: Easy Integration"}
                for element, i in ui_elements {
                    ta.add_animation(&ui_manager, ta.create_slide_animation(
                        element, 200, 300 + f32(i) * 40, 24,
                        f32(i) * 0.3, 300, 1.0, .EASE_OUT_CUBIC))
                }
                demo_stage = 2
            }
            
        case 2: // Typewriter effect
            update_typewriter(&typewriter, dt)
            if stage_timer > 8.0 && typewriter.is_complete {
                demo_stage = 3
            }
        }
        
        // Update all systems
        ta.update_animations(&title_manager, dt)
        ta.update_animations(&ui_manager, dt)
        update_particle_text_system(&particle_system, dt)
        
        // Input for particle explosion
        if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
            mouse_pos := rl.GetMousePosition()
            explode_text(&particle_system, "BOOM!", mouse_pos, 32)
        }
        
        // Render
        rl.BeginDrawing()        
        rl.ClearBackground({15, 15, 25, 255})
        
        // Render all systems
        ta.render_animations(&title_manager, WIDTH)
        ta.render_animations(&ui_manager, WIDTH)
        render_typewriter(&typewriter, font)
        render_particle_text_system(&particle_system, 32)
        
        // Instructions
        rl.DrawText("Click anywhere to create particle explosion", 10, HEIGHT - 30, 16, rl.LIGHTGRAY)
        rl.EndDrawing()
    }
}