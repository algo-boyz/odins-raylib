package main

import "core:fmt"
import effect "../"
import rl "vendor:raylib"

// Example callback functions
hello_click :: proc(element: ^effect.TextElement) {
    fmt.println("Hello button clicked!")
    element.color_mode = .RAINBOW_WAVE
}

goodbye_hover :: proc(element: ^effect.TextElement) {
    fmt.println("Goodbye button hovered!")
}

world_release :: proc(element: ^effect.TextElement) {
    fmt.println("World button released!")
    element.animation_type = .SHAKE
}

main :: proc() {
    config := effect.DEFAULT_CONFIG
    
    // Init Raylib
    rl.InitWindow(config.WIDTH, config.HEIGHT, config.title)
    rl.SetTargetFPS(config.fps)
    
    // Create text manager
    manager := effect.make_text_manager(config)
    defer effect.cleanup_text_manager(&manager)
    
    // Create various text elements with different properties
    
    // Centered main text
    main_text := effect.make_centered_text("Click Me!", config.WIDTH, config.HEIGHT, 40)
    main_text.on_click = hello_click
    main_text.animation_type = .PULSE
    main_text.color_mode = .HSV_CYCLE
    effect.add_text(&manager, main_text)
    
    // Top-left corner text
    corner_text := effect.make_text_element("Hover Here", 50, 50, 25)
    corner_text.on_hover = goodbye_hover
    corner_text.animation_type = .BOUNCE
    corner_text.color_mode = .BRIGHTNESS_PULSE
    corner_text.hover_scale = 1.3
    effect.add_text(&manager, corner_text)
    
    // Bottom-right corner text
    world_text := effect.make_text_element("Release Me", f32(config.WIDTH - 200), f32(config.HEIGHT - 100), 20)
    world_text.on_release = world_release
    world_text.animation_type = .WAVE
    world_text.color_mode = .RAINBOW_WAVE
    world_text.base_color = rl.YELLOW
    effect.add_text(&manager, world_text)
    
    // Static text (no interaction)
    static_text := effect.make_text_element("Static Text", f32(config.WIDTH / 2 - 60), 100, 18)
    static_text.clickable = false
    static_text.hoverable = false
    static_text.animation_type = .GROW_SHRINK
    static_text.color_mode = .STATIC
    static_text.base_color = rl.GREEN
    effect.add_text(&manager, static_text)
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        effect.update_text_manager(&manager)
        
        // Toggle debug mode with D key
        if rl.IsKeyPressed(.D) {
            manager.config.debug_mode = !manager.config.debug_mode
        }
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(config.background)
        
        effect.draw_text_manager(&manager)
        
        // Instructions
        if manager.config.debug_mode {
            rl.DrawText("Press 'D' to toggle debug mode", 10, config.HEIGHT - 30, 16, rl.LIGHTGRAY)
        }
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}