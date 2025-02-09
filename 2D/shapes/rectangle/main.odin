package main

import rl "vendor:raylib"

MOUSE_SCALE_MARK_SIZE :: 12
SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450

rec: rl.Rectangle
mouse_position: rl.Vector2
mouse_scale_ready: bool
mouse_scale_mode: bool

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "rectangle scaling")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    rec = {100, 100, 200, 80}
    mouse_position = {0, 0}
    mouse_scale_ready = false
    mouse_scale_mode = false

    for !rl.WindowShouldClose() {
        mouse_position := rl.GetMousePosition()

        if rl.CheckCollisionPointRec(mouse_position, {rec.x + rec.width - MOUSE_SCALE_MARK_SIZE, rec.y + rec.height - MOUSE_SCALE_MARK_SIZE, MOUSE_SCALE_MARK_SIZE, MOUSE_SCALE_MARK_SIZE}) {
            mouse_scale_ready = true
            if rl.IsMouseButtonPressed(.LEFT) do mouse_scale_mode = true
        }
        else do mouse_scale_ready = false
    
        if mouse_scale_mode {
            mouse_scale_ready = true
    
            rec.width = (mouse_position.x - rec.x)
            rec.height = (mouse_position.y - rec.y)
    
            // Check minimum rec size
            if rec.width < MOUSE_SCALE_MARK_SIZE do rec.width = MOUSE_SCALE_MARK_SIZE
            if rec.height < MOUSE_SCALE_MARK_SIZE do rec.height = MOUSE_SCALE_MARK_SIZE
            
            // Check maximum rec size
            if rec.width > (f32(rl.GetScreenWidth()) - rec.x) do rec.width = f32(rl.GetScreenWidth()) - rec.x
            if rec.height > (f32(rl.GetScreenHeight()) - rec.y) do rec.height = f32(rl.GetScreenHeight()) - rec.y
    
            if rl.IsMouseButtonReleased(.LEFT)  do mouse_scale_mode = false
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)
    
        rl.DrawText("Scale rectangle by dragging bottom-right corner", 10, 10, 20, rl.GRAY)
        rl.DrawRectangleRec(rec, rl.Fade(rl.GREEN, 0.5))
    
        if mouse_scale_ready {
            rl.DrawRectangleLinesEx(rec, 1, rl.RED)
            rl.DrawTriangle({ rec.x + rec.width - MOUSE_SCALE_MARK_SIZE, rec.y + rec.height },
                            { rec.x + rec.width, rec.y + rec.height },
                            { rec.x + rec.width, rec.y + rec.height - MOUSE_SCALE_MARK_SIZE }, rl.RED)
        }
        rl.EndDrawing()
    }
}
