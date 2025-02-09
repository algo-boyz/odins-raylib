package main

import "core:math"
import rl "vendor:raylib"

WindowState :: struct {
    position: rl.Vector2,
    is_dragging: bool,
    last_position: rl.Vector2,
    window_center: rl.Vector2,
}

main :: proc() {
    screen_width :: 800
    screen_height :: 450

    rl.SetConfigFlags({.WINDOW_TRANSPARENT})
    rl.InitWindow(screen_width, screen_height, "Transparent Drag Me Window")
    
    state := WindowState{
        position = {
            f32(rl.GetMonitorWidth(0) / 2 - screen_width / 2),
            f32(rl.GetMonitorHeight(0) / 2 - screen_height / 2),
        },
    }
    state.last_position = state.position
    state.window_center = {f32(screen_width) / 2, f32(screen_height) / 2}
    
    rl.SetWindowPosition(i32(state.position.x), i32(state.position.y))
    rl.SetWindowState({.WINDOW_UNDECORATED})

    target := rl.LoadRenderTexture(screen_width, screen_height)
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        if rl.IsMouseButtonPressed(.LEFT) {
            state.is_dragging = true
            state.last_position = state.position
            
            // Hide cursor and center it
            rl.HideCursor()
            rl.SetMousePosition(i32(state.window_center.x), i32(state.window_center.y))
            rl.DisableEventWaiting()
        }
        
        if state.is_dragging {
            mouse_pos := rl.GetMousePosition()
            
            // Calculate offset from center
            delta_x := mouse_pos.x - state.window_center.x
            delta_y := mouse_pos.y - state.window_center.y
            
            if delta_x != 0 || delta_y != 0 {
                // Update window position based on delta
                new_x := i32(state.position.x + delta_x)
                new_y := i32(state.position.y + delta_y)
                
                rl.SetWindowPosition(new_x, new_y)
                state.position = {f32(new_x), f32(new_y)}
                
                // Recenter the mouse
                rl.SetMousePosition(i32(state.window_center.x), i32(state.window_center.y))
            }
            
            if !rl.IsMouseButtonDown(.LEFT) {
                state.is_dragging = false
                rl.ShowCursor()
                rl.EnableEventWaiting()
            }
        }

        // Rendering
        rl.BeginTextureMode(target)
        rl.ClearBackground(rl.BLANK)
        rl.DrawRectangle(50, 50, 200, 100, rl.Color{255, 0, 0, 192})
        rl.EndTextureMode()

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLANK)
        
        source := rl.Rectangle{0, 0, 800, -450}
        dest := rl.Rectangle{0, 0, 800, 450}
        origin := rl.Vector2{0, 0}
        
        rl.DrawTexturePro(
            target.texture,
            source,
            dest,
            origin,
            0.0,
            rl.WHITE,
        )
        
        rl.EndDrawing()
    }

    rl.UnloadRenderTexture(target)
    rl.CloseWindow()
}