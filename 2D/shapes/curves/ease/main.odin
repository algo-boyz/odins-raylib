
package ease

import "core:fmt"
import "core:strings"
import "core:reflect"

import rl "vendor:raylib"

// based on: https://gist.github.com/jakubtomsu/75ef92cc7914ecde740d4943ef6161c5
main :: proc() {
    WINDOW_X :: 800
    WINDOW_Y :: 480
    rl.InitWindow(800, 480, "Ease Example")
    
    e := Mode.linear
    
    for !rl.WindowShouldClose() {      
        // Cycle between easing functions
        if rl.IsKeyPressed(.LEFT) do e = Mode((int(e) - 1) %% len(Mode))
        if rl.IsKeyPressed(.RIGHT) do e = Mode((int(e) + 1) %% len(Mode))
        
        rl.BeginDrawing()
        rl.ClearBackground({50, 55, 60, 255})
                
        NUM_POINTS :: 256
        Y_MORE :: 0.15
        for i in 0 ..< NUM_POINTS - 1 {
            x := f32(i) / NUM_POINTS
            y := 1.0 - Y_MORE - mode_ease(e, x) * (1.0 - Y_MORE * 2)
            x_next := f32(i + 1) / NUM_POINTS
            y_next := 1.0 - Y_MORE- mode_ease(e, x_next) * (1.0 - Y_MORE * 2)
            rl.DrawLineEx({x * WINDOW_X, y * WINDOW_Y}, {x_next * WINDOW_X, y_next * WINDOW_Y}, 5.0, {200, 200, 220, 100})
        }
        
        rl.DrawLineEx({0, Y_MORE * WINDOW_Y}, {WINDOW_X, Y_MORE * WINDOW_Y}, 2.0, {200, 200, 220, 50})
        rl.DrawLineEx({0, (1.0 - Y_MORE) * WINDOW_Y}, {WINDOW_X, (1.0 - Y_MORE) * WINDOW_Y}, 2.0, {200, 200, 220, 50})

        rl.DrawText(strings.clone_to_cstring(fmt.tprint("Easing function: <", reflect.enum_string(e), ">"), context.temp_allocator), 5, 5, 20, rl.WHITE)
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}