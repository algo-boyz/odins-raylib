package main

import "core:fmt"
import "core:math/rand"
import "core:time"

import rl "vendor:raylib"

Streamer :: struct {
    column:    i32,
    position:  f32,
    speed:     f32,
    text:      []rune,
}

SCREEN_WIDTH  :: 1280
SCREEN_HEIGHT :: 800
CHAR_SIZE     :: 12
MAX_STREAMERS :: 200

random_character :: proc() -> rune {
    // Use Unicode range similar to original (0x00C0 to 0x1EF)
    return rune(rand.int_max(0x1EF - 0x00C0) + 0x00C0)
}

prepare_streamer :: proc(s: ^Streamer) {
    if s.text != nil {
        delete(s.text)
    }
    
    s.column = rand.int31_max(SCREEN_WIDTH / CHAR_SIZE) * CHAR_SIZE
    s.position = 0
    s.speed = f32(rand.int31_max(40) + 5)
    
    length := rand.int31_max(80) + 10
    s.text = make([]rune, length)
    for i := 0; i < len(s.text); i += 1 {
        s.text[i] = random_character()
    }
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Matrix")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    
    // Initialize streamers
    streamers := make([dynamic]Streamer, MAX_STREAMERS)
    defer delete(streamers)
    
    for &s in &streamers {
        prepare_streamer(&s)
    }
    
    for !rl.WindowShouldClose() {
        elapsed := rl.GetFrameTime()
        
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.BLACK)
        
        for &s in &streamers {
            s.position += elapsed * s.speed
            
            for i := 0; i < len(s.text); i += 1 {
                y_pos := int(s.position) * CHAR_SIZE - (i * CHAR_SIZE)
                if y_pos < -CHAR_SIZE || y_pos > SCREEN_HEIGHT {
                    continue
                }
                
                char_index := (i - int(s.position)) % len(s.text)
                if char_index < 0 {
                    char_index += len(s.text)
                }
                
                // Determine character color based on position
                color := rl.GREEN
                if i == 0 {
                    color = rl.WHITE
                } else if i <= 3 {
                    color = rl.GRAY
                } else if s.speed < 15 {
                    color = {0, 100, 0, 255} // Dark green
                }
                
                // Draw the character
                rl.DrawText(
                    fmt.ctprintf("%r", s.text[char_index]),
                    s.column,
                    i32(y_pos),
                    CHAR_SIZE,
                    color,
                )
                
                // Occasionally glitch a character
                if rand.int31_max(1000) < 5 {
                    s.text[i] = random_character()
                }
            }
            
            // Reset streamer if it's gone off screen
            if s.position * f32(CHAR_SIZE) - f32(len(s.text) * CHAR_SIZE) >= f32(SCREEN_HEIGHT) {
                prepare_streamer(&s)
            }
        }
        rl.EndDrawing()
    }
}