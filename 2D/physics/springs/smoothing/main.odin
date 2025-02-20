package main

import "core:fmt"
import "core:math/rand"
import "../../../../rlutil/physics/springs"
import rl "vendor:raylib"

// based on: https://theorangeduck.com/page/spring-roll-call#smoothing

HISTORY_MAX :: 256

State :: struct {
    x_prev: [HISTORY_MAX]f32,
    v_prev: [HISTORY_MAX]f32,
    t_prev: [HISTORY_MAX]f32,
}

main :: proc() {
    // Init Window
    screen_width :: 640
    screen_height :: 360
    
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - smoothing")
    
    // Init Variables
    state := State{}
    
    t := f32(0.0)
    x := f32(screen_height) / 2.0
    v := f32(0.0)
    g := x
    goal_offset := f32(600)
    
    halflife := f32(0.1)
    dt := f32(1.0 / 60.0)
    timescale := f32(240.0)
    
    noise := f32(0.0)
    jitter := f32(0.0)
    
    rl.SetTargetFPS(i32(1.0 / dt))
    
    // Initialize history arrays
    for i in 0..<HISTORY_MAX {
        state.x_prev[i] = x
        state.v_prev[i] = v
        state.t_prev[i] = t
    }
    
    for !rl.WindowShouldClose() {
        // Shift History
        for i := HISTORY_MAX-1; i > 0; i -= 1 {
            state.x_prev[i] = state.x_prev[i-1]
            state.v_prev[i] = state.v_prev[i-1]
            state.t_prev[i] = state.t_prev[i-1]
        }
        
        // Get Goal
        if rl.IsMouseButtonDown(.RIGHT) {
            mouse_pos := rl.GetMousePosition()
            g = mouse_pos.y
        }
        
        g += noise * (rand.float32() * 2.0 - 1.0)
        
        if jitter != 0 {
            g -= jitter
            jitter = 0
        } else if rand.int31_max(i32(0.5 / dt)) == 0 {
            jitter = noise * 10.0 * (rand.float32() * 2.0 - 1.0)
            g += jitter
        }
        
        // GUI Controls
        rl.GuiSliderBar(
            rl.Rectangle{100, 20, 120, 20},
            "halflife",
            fmt.ctprintf("%5.3f", halflife),
            &halflife,
            0.0,
            1.0,
        )
        
        rl.GuiSliderBar(
            rl.Rectangle{100, 45, 120, 20},
            "dt",
            fmt.ctprintf("%5.3f", dt),
            &dt,
            1.0/60.0,
            0.1,
        )
        
        rl.GuiSliderBar(
            rl.Rectangle{100, 70, 120, 20},
            "noise",
            fmt.ctprintf("%5.3f", noise),
            &noise,
            0.0,
            20.0,
        )
        
        // Update Spring
        rl.SetTargetFPS(i32(1.0 / dt))
        
        t += dt
        
        springs.simple_spring_damper_exact(&x, &v, g, halflife, dt)
        
        state.x_prev[0] = x
        state.v_prev[0] = v
        state.t_prev[0] = t
        
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        rl.DrawCircleV(rl.Vector2{goal_offset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goal_offset, x}, 5, rl.DARKBLUE)
        
        for i in 0..<HISTORY_MAX-1 {
            x_start := rl.Vector2{
                goal_offset - (t - state.t_prev[i]) * timescale,
                state.x_prev[i],
            }
            x_stop := rl.Vector2{
                goal_offset - (t - state.t_prev[i+1]) * timescale,
                state.x_prev[i+1],
            }
            
            rl.DrawLineV(x_start, x_stop, rl.BLUE)
            rl.DrawCircleV(x_start, 2, rl.BLUE)
        }
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}