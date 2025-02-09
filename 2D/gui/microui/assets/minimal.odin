package demo

import "rlmu"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import mu "vendor:microui"

main :: proc() {
    rl.InitWindow(720, 600, "Odin/Raylib/microui Demo")
    defer rl.CloseWindow()

    ctx := rlmu.init_scope() // same as calling, `rlmu.init(); defer rlmu.destroy()`

    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        rl.BeginDrawing(); defer rl.EndDrawing()
        rl.ClearBackground(rl.BLACK)
        
        rlmu.begin_scope();
        
        if mu.begin_window(ctx, "Test Window", { 100, 100, 100, 100 }) {
            defer mu.end_window(ctx)
            
            mu.label(ctx, "Hello, world")
        }
    } 
}