package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

WIDTH :: 1500
HEIGHT :: 900
MAX_STREAMS :: 100
MAX_CHARS :: 50

Stream :: struct {
    x: f32,
    y: f32,
    speed: f32,
    characters: [MAX_CHARS]u8,
    length: i32,
    active: bool,
}

State :: struct {
    streams: [MAX_STREAMS]Stream,
    cnt: i32,
    selected_color_index: i32,
    random_color_mode: bool,
    pause: bool,
    font: rl.Font,
    bg: rl.Texture2D,
    render_target: rl.RenderTexture2D,
    reveal_mode: bool,
}

state: State

init_streams :: proc() {
    state.cnt = WIDTH / 20
    
    for i in 0..<state.cnt {
        stream := &state.streams[i]
        stream.x = f32(i * 20)
        stream.y = rand.float32_range(0, HEIGHT)
        stream.speed = rand.float32_range(2, 7)
        stream.length = i32(rand.float32_range(10, 30))
        stream.active = true
        
        // Fill character array with random printable ASCII characters
        for j in 0..<stream.length {
            stream.characters[j] = u8(rand.float32_range(33, 127)) // ASCII 33-126
        }
    }
}

update_streams :: proc() {
    for i in 0..<state.cnt {
        stream := &state.streams[i]
        
        if stream.active {
            // Update stream position
            stream.y += stream.speed
            
            // Reset stream if it goes off screen
            if stream.y - f32(stream.length) * 20 > HEIGHT {
                stream.y = rand.float32_range(-f32(stream.length) * 20, 0)
                stream.length = i32(rand.float32_range(10, 30))
                for j in 0..<stream.length {
                    stream.characters[j] = u8(rand.float32_range(33, 127))
                }
            }
            
            // Occasionally change a character in the stream
            if rand.float32_range(0, 100) < 10 {
                char_index := rand.float32_range(0, f32(stream.length))
                stream.characters[int(char_index)] = u8(rand.float32_range(33, 127))
            }
        }
    }
}

update_game :: proc() {
    if state.pause {
        return
    }
    update_streams()
    
    // Speed controls
    if rl.IsKeyPressed(.J) {
        for i in 0..<state.cnt {
            if state.streams[i].active {
                state.streams[i].speed = max(0.5, state.streams[i].speed - 1)
            }
        }
    }
    if rl.IsKeyPressed(.K) {
        for i in 0..<state.cnt {
            if state.streams[i].active {
                state.streams[i].speed = min(10, state.streams[i].speed + 1)
            }
        }
    }
    
    // Color selection
    if rl.IsKeyPressed(.ONE) do state.selected_color_index = 0
    if rl.IsKeyPressed(.TWO) do state.selected_color_index = 1
    if rl.IsKeyPressed(.THREE) do state.selected_color_index = 2
    if rl.IsKeyPressed(.FOUR) do state.selected_color_index = 3
    if rl.IsKeyPressed(.FIVE) do state.selected_color_index = 4
    if rl.IsKeyPressed(.SIX) do state.selected_color_index = 5
    if rl.IsKeyPressed(.SEVEN) do state.selected_color_index = 6
    if rl.IsKeyPressed(.EIGHT) do state.selected_color_index = 7
    if rl.IsKeyPressed(.NINE) do state.selected_color_index = 8
    if rl.IsKeyPressed(.ZERO) do state.selected_color_index = 9
    
    // Toggle random color mode
    if rl.IsKeyPressed(.R) {
        state.random_color_mode = !state.random_color_mode
    }
    
    // Toggle reveal mode
    if rl.IsKeyPressed(.T) {
        state.reveal_mode = !state.reveal_mode
    }
}

draw_characters_normal :: proc() {
    colors := [10]rl.Color{
        {0, 255, 0, 255},     // BRIGHT GREEN
        {218, 165, 32, 255},  // GOLD
        {128, 128, 128, 255}, // GRAY
        {255, 165, 0, 255},   // ORANGE
        {128, 0, 0, 255},     // MAROON
        {135, 206, 235, 255}, // SKYBLUE
        {0, 0, 139, 255},     // DARKBLUE
        {238, 130, 238, 255}, // VIOLET
        {139, 0, 139, 255},   // DARKPURPLE
        {255, 255, 255, 255}, // WHITE
    }
    
    for i in 0..<state.cnt {
        stream := &state.streams[i]
        
        if stream.active {
            base_color := state.random_color_mode ? colors[i % 10] : colors[state.selected_color_index]
            
            for j in 0..<stream.length {
                char_y := stream.y - f32(j) * 20
                
                // Only draw if character is on screen
                if char_y >= -20 && char_y <= HEIGHT + 20 {
                    // Calculate fading color (brighter at the top)
                    fade_factor := 1.0 - (f32(j) / f32(stream.length))
                    alpha := u8(255 * fade_factor)
                    color := rl.Color{
                        u8(f32(base_color.r) * fade_factor),
                        u8(f32(base_color.g) * fade_factor),
                        u8(f32(base_color.b) * fade_factor),
                        alpha
                    }
                    
                    // Draw each character
                    char_str := string([]u8{stream.characters[j]})
                    cstring_char := rl.TextFormat("%s", char_str)
                    rl.DrawTextEx(state.font, cstring_char, {stream.x, char_y}, 20, 0, color)
                }
            }
        }
    }
}

draw_mask :: proc() {
    // Draw white circles/rectangles where characters are (for the mask)
    for i in 0..<state.cnt {
        stream := &state.streams[i]
        
        if stream.active {
            for j in 0..<stream.length {
                char_y := stream.y - f32(j) * 20
                
                // Only draw if character is on screen
                if char_y >= -20 && char_y <= HEIGHT + 20 {
                    // Calculate fade factor for smoother reveal effect
                    fade_factor := 1.0 - (f32(j) / f32(stream.length))
                    alpha := u8(255 * fade_factor)
                    
                    // Draw a circular mask area
                    rl.DrawCircle(
                        i32(stream.x + 10), 
                        i32(char_y + 10), 
                        25.0, 
                        {255, 255, 255, alpha}
                    )
                }
            }
        }
    }
}

draw_game :: proc() {
    if state.reveal_mode {
        // REVEAL MODE: Use render target for proper masking
        
        // Step 1: Create the mask in the render target
        rl.BeginTextureMode(state.render_target)
        rl.ClearBackground(rl.BLACK) // Black background
        draw_mask() // Draw white circles where characters are
        rl.EndTextureMode()
        
        // Step 2: Draw to screen
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        // Draw the background image
        rl.DrawTexturePro(
            state.bg, 
            {0, 0, f32(state.bg.width), f32(state.bg.height)},
            {0, 0, WIDTH, HEIGHT}, 
            {0, 0}, 
            0.0, 
            rl.WHITE
        )
        
        // Apply dark overlay everywhere
        rl.DrawRectangle(0, 0, WIDTH, HEIGHT, {0, 0, 0, 180})
        
        // Use the mask to reveal parts of the background
        // We'll draw the background again but only where the mask is white
        rl.BeginBlendMode(.ADD_COLORS)
        rl.DrawTexturePro(
            state.render_target.texture,
            {0, 0, f32(state.render_target.texture.width), -f32(state.render_target.texture.height)}, // Flip Y
            {0, 0, WIDTH, HEIGHT},
            {0, 0},
            0.0,
            rl.WHITE
        )
        rl.EndBlendMode()
        
        // Now draw the background again but masked
        rl.BeginBlendMode(.ALPHA_PREMULTIPLY)
        rl.DrawTexturePro(
            state.bg, 
            {0, 0, f32(state.bg.width), f32(state.bg.height)},
            {0, 0, WIDTH, HEIGHT}, 
            {0, 0}, 
            0.0, 
            {255, 255, 255, 100} // Semi-transparent to blend with dark overlay
        )
        rl.EndBlendMode()
        
        // Draw characters on top
        draw_characters_normal()
        
        // Draw UI text
        rl.DrawText("Press T to toggle reveal mode", 10, 10, 20, rl.WHITE)
        rl.DrawText("Reveal Mode: ON", 10, 35, 20, rl.GREEN)
        
    } else {
        // NORMAL MODE: Characters over background
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        // Draw background first
        rl.DrawTexturePro(
            state.bg, 
            {0, 0, f32(state.bg.width), f32(state.bg.height)},
            {0, 0, WIDTH, HEIGHT}, 
            {0, 0}, 
            0.0, 
            rl.WHITE
        )
        
        // Draw characters on top
        draw_characters_normal()
        
        // Draw UI text
        rl.DrawText("Press T to toggle reveal mode", 10, 10, 20, rl.WHITE)
        rl.DrawText("Reveal Mode: OFF", 10, 35, 20, rl.RED)
    }
    
    // Draw pause indicator
    if state.pause {
        pause_text :: "PAUSE"
        colors := [10]rl.Color{
            {0, 255, 0, 255},     // BRIGHT GREEN
            {218, 165, 32, 255},  // GOLD
            {128, 128, 128, 255}, // GRAY
            {255, 165, 0, 255},   // ORANGE
            {128, 0, 0, 255},     // MAROON
            {135, 206, 235, 255}, // SKYBLUE
            {0, 0, 139, 255},     // DARKBLUE
            {238, 130, 238, 255}, // VIOLET
            {139, 0, 139, 255},   // DARKPURPLE
            {255, 255, 255, 255}, // WHITE
        }
        
        text_size := rl.MeasureTextEx(state.font, pause_text, 30, 1)
        pos := rl.Vector2{
            f32(rl.GetScreenWidth()) / 2 - text_size.x / 2,
            f32(rl.GetScreenHeight()) / 2,
        }
        rl.DrawTextEx(state.font, pause_text, pos, 30, 1, colors[state.selected_color_index])
    }
    
    // Draw controls
    rl.DrawText("Controls:", 10, HEIGHT - 120, 16, rl.WHITE)
    rl.DrawText("SPACE: Pause", 10, HEIGHT - 100, 16, rl.WHITE)
    rl.DrawText("J/K: Speed Down/Up", 10, HEIGHT - 80, 16, rl.WHITE)
    rl.DrawText("R: Random Colors", 10, HEIGHT - 60, 16, rl.WHITE)
    rl.DrawText("T: Toggle Reveal Mode", 10, HEIGHT - 40, 16, rl.WHITE)
    rl.DrawText("1-0: Select Color", 10, HEIGHT - 20, 16, rl.WHITE)
    
    rl.EndDrawing()
}

main :: proc() {
    rl.SetConfigFlags({.WINDOW_TRANSPARENT})
    rl.InitWindow(WIDTH, HEIGHT, "Matrix Rain - Reality Reveal")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    
    // Load font
    state.font = rl.LoadFontEx("../../assets/font1.ttf", 96, nil, 0)
    if state.font.texture.id == 0 {
        state.font = rl.GetFontDefault()
    }
    defer rl.UnloadFont(state.font)

    // Load background texture
    state.bg = rl.LoadTexture("../../assets/bg/alley.png")
    defer rl.UnloadTexture(state.bg)

    // Create render target for masking
    state.render_target = rl.LoadRenderTexture(WIDTH, HEIGHT)
    defer rl.UnloadRenderTexture(state.render_target)

    // Init
    state.reveal_mode = false // Start in normal mode
    init_streams()
    
    for !rl.WindowShouldClose() {
        // Toggle pause
        if rl.IsKeyPressed(.SPACE) {
            state.pause = !state.pause
        }
        
        update_game()
        draw_game()
    }
}