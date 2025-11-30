package main

import "core:fmt"
import rl "vendor:raylib"
import "../../"

main :: proc() {
    // Init window
    WIDTH: i32 = 1200
    HEIGHT: i32 = 800
    
    rl.InitWindow(WIDTH, HEIGHT, "Indiana Jones Text")
    rl.SetTargetFPS(60)
    
    // Load custom font
    font := rl.LoadFontEx("fonts/indiana_jones.otf", 36, nil, 0)
    defer rl.UnloadFont(font)
    
    // Set font properties
    rl.SetTextureFilter(font.texture, .BILINEAR)
    rl.SetTextLineSpacing(72)
    
    // Init animation manager with sunset gradient
    animation_manager := slider.init_animation_manager(font, slider.SUNSET_GRADIENT)
    defer slider.destroy_animation_manager(&animation_manager)
    
    // Create and add animations
    center_x := f32(WIDTH) / 2
    
    // "INDIANA JONES" - large text, slides in first
    slider.add_animation(&animation_manager, slider.create_slide_animation(
        text = "INDIANA JONES",
        target_x = center_x,
        y = 250,
        font_size = 72,
        start_delay = 0.5,
        slide_distance = 400,
        duration = 1.5,
        easing = .EASE_OUT_CUBIC,
    ))
    
    // "AND THE" - smaller text, slides in second
    slider.add_animation(&animation_manager, slider.create_slide_animation(
        text = "AND THE",
        target_x = center_x,
        y = 350,
        font_size = 48,
        start_delay = 1.0,
        slide_distance = 400,
        duration = 1.5,
        easing = .EASE_OUT_CUBIC,
    ))
    
    // "LAST CRUSADE" - large text, slides in last with back easing
    slider.add_animation(&animation_manager, slider.create_slide_animation(
        text = "LAST CRUSADE",
        target_x = center_x,
        y = 420,
        font_size = 72,
        start_delay = 1.5,
        slide_distance = 400,
        duration = 2.0,
        easing = .EASE_OUT_BACK,
    ))
    
    // Main game loop
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        
        // Update animations
        slider.update_animations(&animation_manager, dt)
        
        // Handle input
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            slider.reset_animations(&animation_manager)
        }
        
        // Switch gradients with number keys
        if rl.IsKeyPressed(rl.KeyboardKey.ONE) {
            animation_manager.renderer_config.gradient = slider.SUNSET_GRADIENT
        }
        if rl.IsKeyPressed(rl.KeyboardKey.TWO) {
            animation_manager.renderer_config.gradient = slider.OCEAN_GRADIENT
        }
        if rl.IsKeyPressed(rl.KeyboardKey.THREE) {
            animation_manager.renderer_config.gradient = slider.FIRE_GRADIENT
        }
        if rl.IsKeyPressed(rl.KeyboardKey.FOUR) {
            animation_manager.renderer_config.gradient = slider.NEON_GRADIENT
        }
        if rl.IsKeyPressed(rl.KeyboardKey.FIVE) {
            animation_manager.renderer_config.gradient = slider.FOREST_GRADIENT
        }
        
        // Render
        rl.BeginDrawing()
        rl.ClearBackground({20, 15, 10, 255}) // Dark brown background
        
        // Draw background gradient effect
        draw_background_gradient(WIDTH, HEIGHT)
        
        // Render all animations
        slider.render_animations(&animation_manager, WIDTH)
        
        // Draw instructions
        draw_instructions(WIDTH, HEIGHT)
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}

// Draw atmospheric background gradient
draw_background_gradient :: proc(WIDTH, HEIGHT: i32) {
    for i in 0..<HEIGHT {
        alpha := u8(20 * (1.0 - f32(i) / f32(HEIGHT)))
        color := rl.Color{40, 30, 20, alpha}
        rl.DrawLine(0, i32(i), WIDTH, i32(i), color)
    }
}

// Draw UI instructions
draw_instructions :: proc(WIDTH, HEIGHT: i32) {
    instructions := []string{
        "Press SPACE to restart animation",
        "Press 1-5 to change gradient:",
        "1: Sunset  2: Ocean  3: Fire  4: Neon  5: Forest",
    }
    
    y_offset := HEIGHT - 80
    for instruction, i in instructions {
        rl.DrawText(rl.TextFormat("%s", instruction), 10, y_offset + i32(i * 20), 16, rl.LIGHTGRAY)
    }
}