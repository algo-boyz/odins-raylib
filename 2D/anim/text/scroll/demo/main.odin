package example

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

import "../"
import "../../../../../rlutil/texture"

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 600
    rl.InitWindow(WIDTH, HEIGHT, "Animated Scroll Text")
    rl.SetTargetFPS(60)

    // Init text to scroll
    story_text := "Once upon a time, in a distant kingdom, there was a magical scroll that revealed its secrets word by word. The ancient parchment held the wisdom of ages, and those who were patient enough to read it slowly would discover treasures beyond imagination..."
    
    scroll_text := scroll.create({
        text = story_text,
        char_delay = 0.05,
    })
    // Load parchment background
    parchment := texture.load("parchement.png")
    defer texture.unload(&parchment)

    for !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        scroll.update(&scroll_text, delta_time)

        // Handle input
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            scroll.reset(&scroll_text)
        }
        if rl.IsKeyPressed(rl.KeyboardKey.UP) {
            scroll.set_speed(&scroll_text, scroll_text.char_delay - 0.01)
        }
        if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
            scroll.set_speed(&scroll_text, scroll_text.char_delay + 0.01)
        }
        // Drawing
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        // Draw parchment background
        texture.draw(parchment, WIDTH, HEIGHT)

        // Draw scroll text with cursor
        text_position := rl.Vector2{50, 80}
        font_size: i32 = 24
        text_color := rl.DARKBROWN
        
        scroll.draw_with_cursor(scroll_text, text_position, font_size, text_color, WIDTH - 100)

        // Draw UI
        instructions_y := HEIGHT - 80
        rl.DrawText("SPACE: Reset | UP/DOWN: Speed", 20, i32(instructions_y), 16, rl.DARKGRAY)
        
        // Progress indicator
        progress := scroll.get_progress(scroll_text)
        progress_text := fmt.tprintf("Progress: %.1f%% | Speed: %.2f chars/sec", 
                                   progress * 100, 1.0 / scroll_text.char_delay)
        progress_cstring := strings.clone_to_cstring(progress_text)
        rl.DrawText(progress_cstring, 20, i32(instructions_y + 25), 16, rl.DARKGRAY)
        delete(progress_cstring)

        if scroll.is_complete(scroll_text) {
            rl.DrawText("COMPLETE!", 20, i32(instructions_y + 50), 16, rl.GREEN)
        }
        rl.EndDrawing()
    }
    rl.CloseWindow()
}