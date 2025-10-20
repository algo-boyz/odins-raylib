package main

import rl "vendor:raylib"
import "../viewport"
import "../"

CURSOR_TIMEOUT :: 1.0

main :: proc() {
    // Init viewport
    vp := viewport.init_simple("Hide Cursor Timer", 1280, 720, 100)
    defer viewport.cleanup()
    
    // Init cursor manager
    cursor_manager := cursor.new(CURSOR_TIMEOUT)
    
    // Main game loop
    for !rl.WindowShouldClose() {
        if rl.IsKeyPressed(.Q) {
            break
        }
        
        delta_time := rl.GetFrameTime()
        
        // Update cursor manager
        cursor.update(&cursor_manager, delta_time)
        
        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw some debug info
        center := viewport.get_center(&vp)
        cursor_status := cursor.is_visible(&cursor_manager) ? "Visible" : "Hidden"
        text := rl.TextFormat("Cursor: %v", cursor_status)
        text_width := rl.MeasureText(text, 20)
        rl.DrawText(text, i32(center.x) - text_width/2, i32(center.y), 20, rl.DARKGRAY)
        
        rl.EndDrawing()
    }
}