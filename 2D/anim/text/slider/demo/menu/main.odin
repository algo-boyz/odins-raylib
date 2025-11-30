package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import ta "../../"

// Title Screen Animation
create_title_screen :: proc(manager: ^ta.AnimationManager, WIDTH, HEIGHT: i32) {
    center_x := f32(WIDTH) / 2
    
    // Main title with dramatic entrance
    ta.add_animation(manager, ta.create_slide_animation(
        text = "EPIC QUEST",
        target_x = center_x,
        y = f32(HEIGHT) * 0.3,
        font_size = 84,
        slide_distance = 600,
        duration = 2.0,
        easing = .EASE_OUT_BACK,
    ))
    
    // Subtitle with delayed entrance
    ta.add_animation(manager, ta.create_slide_animation(
        text = "Legends Reborn",
        target_x = center_x,
        y = f32(HEIGHT) * 0.45,
        font_size = 36,
        start_delay = 2.2,
        slide_distance = 400,
        duration = 1.5,
        easing = .EASE_OUT_CUBIC,
    ))
    
    // Menu options with staggered timing
    menu_items := []string{"New Game", "Load Game", "Settings", "Exit"}
    for item, i in menu_items {
        ta.add_animation(manager, ta.create_slide_animation(
            text = item,
            target_x = center_x,
            y = f32(HEIGHT) * 0.65 + f32(i) * 50,
            font_size = 28,
            start_delay = 3.0 + f32(i) * 0.2,
            slide_distance = 300,
            duration = 1.0,
            easing = .EASE_OUT_CUBIC,
        ))
    }
}

// Dialogue System Animation
DialogueAnimation :: struct {
    character_name: string,
    dialogue_text: []string,
    current_line: int,
    line_delay: f32,
    manager: ta.AnimationManager,
}

init_dialogue_animation :: proc(font: rl.Font, character: string, lines: []string) -> DialogueAnimation {
    return DialogueAnimation{
        character_name = character,
        dialogue_text = lines,
        current_line = 0,
        line_delay = 1.5,
        manager = ta.init_animation_manager(font, ta.OCEAN_GRADIENT),
    }
}

update_dialogue :: proc(dialogue: ^DialogueAnimation, dt: f32, WIDTH: i32) {
    ta.update_animations(&dialogue.manager, dt)
    
    // Add next line when previous is complete
    if dialogue.current_line < len(dialogue.dialogue_text) && 
       ta.all_animations_complete(&dialogue.manager) {
        
        // Character name
        if dialogue.current_line == 0 {
            ta.add_animation(&dialogue.manager, ta.create_slide_animation(
                text = dialogue.character_name,
                target_x = 100,
                y = 500,
                font_size = 32,
                start_delay = 0,
                slide_distance = 200,
                duration = 0.8,
                easing = .EASE_OUT_CUBIC,
            ))
        }
        
        // Dialogue line
        ta.add_animation(&dialogue.manager, ta.create_slide_animation(
            text = dialogue.dialogue_text[dialogue.current_line],
            target_x = 120,
            y = 540 + f32(dialogue.current_line % 3) * 35,
            font_size = 24,
            start_delay = 0.3,
            slide_distance = 300,
            duration = 1.0,
            easing = .EASE_OUT_CUBIC,
        ))
        
        dialogue.current_line += 1
    }
}

// Score/Stats Display Animation
ScoreDisplay :: struct {
    score: int,
    target_score: int,
    display_score: int,
    animation_speed: f32,
    manager: ta.AnimationManager,
}

init_score_display :: proc(font: rl.Font, initial_score: int) -> ScoreDisplay {
    return ScoreDisplay{
        score = initial_score,
        target_score = initial_score,
        display_score = initial_score,
        animation_speed = 50.0, // Points per second
        manager = ta.init_animation_manager(font, ta.FIRE_GRADIENT),
    }
}

update_score :: proc(display: ^ScoreDisplay, new_score: int, dt: f32, WIDTH: i32) {
    if new_score != display.target_score {
        display.target_score = new_score
        
        // Animate score change
        ta.add_animation(&display.manager, ta.create_slide_animation(
            text = fmt.tprintf("SCORE: %d", new_score),
            target_x = f32(WIDTH) - 200,
            y = 50,
            font_size = 36,
            start_delay = 0,
            slide_distance = 150,
            duration = 0.8,
            easing = .EASE_OUT_BACK,
        ))
    }
    
    // Smoothly interpolate displayed score
    if display.display_score != display.target_score {
        diff := display.target_score - display.display_score
        step := int(display.animation_speed * dt)
        if abs(diff) < step {
            display.display_score = display.target_score
        } else {
            display.display_score += step if diff > 0 else -step
        }
    }
    
    ta.update_animations(&display.manager, dt)
}

// Combat Text Animation
CombatText :: struct {
    active_texts: [dynamic]CombatTextEntry,
    manager: ta.AnimationManager,
}

CombatTextEntry :: struct {
    text: string,
    x, y: f32,
    lifetime: f32,
    max_lifetime: f32,
    velocity_y: f32,
    color: rl.Color,
}

init_combat_text :: proc(font: rl.Font) -> CombatText {
    return CombatText{
        active_texts = make([dynamic]CombatTextEntry),
        manager = ta.init_animation_manager(font),
    }
}

add_combat_text :: proc(combat: ^CombatText, text: string, x, y: f32, text_type: string) {
    color := rl.RED
    velocity := f32(-60) // Float upward
    
    switch text_type {
    case "damage":
        color = rl.RED
    case "heal":
        color = rl.GREEN
        velocity = -40
    case "critical":
        color = rl.YELLOW
        velocity = -80
    case "miss":
        color = rl.GRAY
        velocity = -30
    }
    
    entry := CombatTextEntry{
        text = text,
        x = x,
        y = y,
        lifetime = 0,
        max_lifetime = 2.0,
        velocity_y = velocity,
        color = color,
    }
    
    append(&combat.active_texts, entry)
}

update_combat_text :: proc(combat: ^CombatText, dt: f32) {
    // Update existing combat text
    for i := len(combat.active_texts) - 1; i >= 0; i -= 1 {
        entry := &combat.active_texts[i]
        entry.lifetime += dt
        entry.y += entry.velocity_y * dt
        
        // Fade out over time
        alpha := 1.0 - (entry.lifetime / entry.max_lifetime)
        entry.color.a = u8(255 * alpha)
        
        // Remove expired entries
        if entry.lifetime >= entry.max_lifetime {
            ordered_remove(&combat.active_texts, i)
        }
    }
}

render_combat_text :: proc(combat: ^CombatText, font: rl.Font) {
    for entry in combat.active_texts {
        rl.DrawTextEx(font, rl.TextFormat("%s", entry.text), 
                     rl.Vector2{entry.x, entry.y}, 24, 1, entry.color)
    }
}

// Custom Gradient Builder
create_custom_gradient :: proc(colors: []rl.Color) -> ta.GradientConfig {
    positions := make([]f32, len(colors))
    defer delete(positions)
    
    for i in 0..<len(colors) {
        positions[i] = f32(i) / f32(len(colors) - 1)
    }
    
    // Note: In real usage, you'd want to manage memory properly
    return ta.GradientConfig{
        colors = colors,
        positions = positions,
    }
}

main :: proc() {
    WIDTH: i32 = 1200
    HEIGHT: i32 = 800
    
    rl.InitWindow(WIDTH, HEIGHT, "Animation Examples")
    defer rl.CloseWindow()
    
    font := rl.LoadFontEx("fonts/font.ttf", 32, nil, 0)
    defer rl.UnloadFont(font)
    
    // Create different animation systems
    title_manager := ta.init_animation_manager(font, ta.SUNSET_GRADIENT)
    defer ta.destroy_animation_manager(&title_manager)
    
    dialogue := init_dialogue_animation(font, "Hero", []string{
        "The ancient temple looms before us...",
        "I can feel the power emanating from within.",
        "Are you ready to face what lies ahead?",
    })
    defer ta.destroy_animation_manager(&dialogue.manager)
    
    score_display := init_score_display(font, 0)
    defer ta.destroy_animation_manager(&score_display.manager)
    
    combat_text := init_combat_text(font)
    defer ta.destroy_animation_manager(&combat_text.manager)
    defer delete(combat_text.active_texts)
    
    // Init title screen
    create_title_screen(&title_manager, WIDTH, HEIGHT)
    
    current_score := 0
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        
        // Update all systems
        ta.update_animations(&title_manager, dt)
        update_dialogue(&dialogue, dt, WIDTH)
        update_score(&score_display, current_score, dt, WIDTH)
        update_combat_text(&combat_text, dt)
        
        // Test combat text
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            add_combat_text(&combat_text, "-50", 400, 300, "damage")
            current_score += 100
        }
        
        if rl.IsKeyPressed(rl.KeyboardKey.H) {
            add_combat_text(&combat_text, "+25", 450, 250, "heal")
        }
        
        if rl.IsKeyPressed(rl.KeyboardKey.C) {
            add_combat_text(&combat_text, "CRITICAL!", 500, 200, "critical")
            current_score += 500
        }
        
        // Render everything
        rl.BeginDrawing()        
        rl.ClearBackground(rl.BLACK)
        
        // Render different systems based on game state
        ta.render_animations(&title_manager, WIDTH)
        ta.render_animations(&dialogue.manager, WIDTH)
        ta.render_animations(&score_display.manager, WIDTH)
        render_combat_text(&combat_text, font)
        
        // Instructions
        rl.DrawText("SPACE - Deal Damage | H - Heal | C - Critical Hit", 10, HEIGHT - 30, 20, rl.WHITE)
        rl.EndDrawing()
    }
}