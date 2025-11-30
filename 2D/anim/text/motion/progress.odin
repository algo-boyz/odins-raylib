package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 450
    rl.InitWindow(WIDTH, HEIGHT, "Loading Animation")
    rl.SetTargetFPS(60)
    
    loading_progress: f32 = 0.0
    loading_speed :: 0.5 // in percent per second
    max_dots :: 5 // Max points to display after "Progress"
    current_dots := 0
    dot_timer: f32 = 0.0
    dot_interval :: 0.3 // Time interval in seconds between adding a dot to the loading text
    
    for !rl.WindowShouldClose() {
        loading_progress += loading_speed * rl.GetFrameTime()
        if loading_progress > 100.0 {
            loading_progress = 100.0
        }
        // used to control the number of dots displayed after "Progress"
        dot_timer += rl.GetFrameTime()
        if dot_timer >= dot_interval && loading_progress < 100.0 {
            dot_timer = 0.0
            current_dots += 1
            if current_dots > max_dots {
                current_dots = 0
            }
        }
        loading_text := strings.builder_make()
        defer strings.builder_destroy(&loading_text)
        
        strings.write_string(&loading_text, "Progress")
        for i in 0..<current_dots {
            strings.write_string(&loading_text, ".")
        }
        loading_text_cstr := strings.clone_to_cstring(strings.to_string(loading_text))
        defer delete(loading_text_cstr)
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        {
            text_width := rl.MeasureText(loading_text_cstr, 20)
            rl.DrawText(loading_text_cstr, WIDTH / 2 - text_width / 2, HEIGHT / 2 - 10, 20, rl.BLACK)
            
            bar_width := i32(f32(WIDTH) * (loading_progress / 100.0))
            rl.DrawRectangle(0, HEIGHT - 20, bar_width, 20, rl.GREEN)
            
            progress_string := fmt.ctprintf("%.2f%%", loading_progress) // Format to 2 décimals
            progress_width := rl.MeasureText(progress_string, 10)
            rl.DrawText(progress_string, WIDTH / 2 - progress_width / 2, HEIGHT - 30, 10, rl.GRAY)
        }
        rl.EndDrawing()
    }
    rl.CloseWindow()
}