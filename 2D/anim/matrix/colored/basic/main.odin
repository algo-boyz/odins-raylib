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
            if stream.y - f32(stream.length) * 35 > HEIGHT {
                stream.y = 0
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
                state.streams[i].speed -= 2
            }
        }
    }
    if rl.IsKeyPressed(.K) {
        for i in 0..<state.cnt {
            if state.streams[i].active {
                state.streams[i].speed += 2
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
}

draw_game :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    rl.DrawTexturePro(state.bg, {0, 0, f32(state.bg.width), f32(state.bg.height)},
                   {0, 0, WIDTH, HEIGHT}, {0, 0}, 0.0, rl.WHITE);

    colors := [10]rl.Color{
        {0, 100, 0, 255},     // DARKGREEN
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
                // Calculate fading color (brighter at the top)
                alpha := 255 - (i32(j) * 255 / stream.length)
                color := rl.Color{base_color.r, base_color.g, base_color.b, u8(alpha)}
                // Draw each character
                char_str := string([]u8{stream.characters[j]})
                cstring_char := rl.TextFormat("%s", char_str)
                rl.DrawTextEx(state.font, cstring_char, {stream.x, stream.y - f32(j) * 20}, 20, 0, color)
            }
        }
    }
    if state.pause {
        pause_text :: "PAUSE"
        text_size := rl.MeasureTextEx(state.font, pause_text, 30, 1)
        pos := rl.Vector2{
            f32(rl.GetScreenWidth()) / 2 - text_size.x / 2,
            f32(rl.GetScreenHeight()) / 2,
        }
        rl.DrawTextEx(state.font, pause_text, pos, 30, 1, colors[state.selected_color_index])
    }
    rl.EndDrawing()
}

main :: proc() {
    rl.SetConfigFlags({.WINDOW_TRANSPARENT})
    rl.InitWindow(WIDTH, HEIGHT, "Matrix Rain")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    
    // Note: You'll need to adjust the font path or use a default font
    state.font = rl.LoadFontEx("../../assets/font1.ttf", 96, nil, 0)
    if state.font.texture.id == 0 {
        // Fallback to default font if custom font fails to load
        state.font = rl.GetFontDefault()
    }
    defer rl.UnloadFont(state.font)

    state.bg = rl.LoadTexture("../../assets/bg/alley.png")
    defer rl.UnloadTexture(state.bg)

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