package main

import "core:fmt"
import "../../../../../rlutil/phys"
import rl "vendor:raylib"

// based on: https://theorangeduck.com/page/spring-roll-call#doublespring

HISTORY_MAX :: 256

X_Prev  : [HISTORY_MAX]f32
V_Prev  : [HISTORY_MAX]f32
T_Prev  : [HISTORY_MAX]f32
Xi_Prev : [HISTORY_MAX]f32
Vi_Prev : [HISTORY_MAX]f32

double_spring_damper_exact :: proc(
    x: ^f32,
    v: ^f32,
    xi: ^f32,
    vi: ^f32,
    x_goal: f32,
    halflife: f32,
    dt: f32,
) {
    // Assuming simple_spring_damper_exact is defined in common
    phys.simple_spring_damper_exact(xi, vi, x_goal, 0.5 * halflife, dt)
    phys.simple_spring_damper_exact(x, v, xi^, 0.5 * halflife, dt)
}

main :: proc() {
    screen_width :: 640
    screen_height :: 360
    
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - doublespring")
    
    // Init Variables
    t := f32(0.0)
    x := f32(screen_height) / 2.0
    v := f32(0.0)
    g := x
    goal_offset := f32(600)
    halflife := f32(0.1)
    dt := f32(1.0 / 60.0)
    timescale := f32(240.0)
    xi := x
    vi := v
    
    rl.SetTargetFPS(i32(1.0 / dt))
    
    // Initialize history arrays
    for i := 0; i < HISTORY_MAX; i += 1 {
        X_Prev[i] = x
        V_Prev[i] = v
        T_Prev[i] = t
        Xi_Prev[i] = x
        Vi_Prev[i] = v
    }
    
    for !rl.WindowShouldClose() {
        // Shift History
        for i := HISTORY_MAX - 1; i > 0; i -= 1 {
            X_Prev[i] = X_Prev[i-1]
            V_Prev[i] = V_Prev[i-1]
            T_Prev[i] = T_Prev[i-1]
            Xi_Prev[i] = Xi_Prev[i-1]
            Vi_Prev[i] = Vi_Prev[i-1]
        }
        
        // Get Goal
        if rl.IsMouseButtonDown(.RIGHT) {
            mouse_pos := rl.GetMousePosition()
            g = mouse_pos.y
        }
        
        // Note: GUI elements removed as they require additional raylib-specific GUI handling in Odin
        
        // Update Spring
        rl.SetTargetFPS(i32(1.0 / dt))
        
        t += dt
        
        double_spring_damper_exact(&x, &v, &xi, &vi, g, halflife, dt)
        
        X_Prev[0] = x
        V_Prev[0] = v
        T_Prev[0] = t
        Xi_Prev[0] = xi
        Vi_Prev[0] = vi
        
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw goal and current position
        rl.DrawCircleV(rl.Vector2{goal_offset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goal_offset, x}, 5, rl.DARKBLUE)
        
        // Draw history for intermediate position
        for i := 0; i < HISTORY_MAX - 1; i += 1 {
            g_start := rl.Vector2{
                goal_offset - (t - T_Prev[i]) * timescale,
                Xi_Prev[i],
            }
            g_stop := rl.Vector2{
                goal_offset - (t - T_Prev[i + 1]) * timescale,
                Xi_Prev[i + 1],
            }
            
            rl.DrawLineV(g_start, g_stop, rl.MAROON)
            rl.DrawCircleV(g_start, 2, rl.MAROON)
        }
        
        // Draw history for final position
        for i := 0; i < HISTORY_MAX - 1; i += 1 {
            x_start := rl.Vector2{
                goal_offset - (t - T_Prev[i]) * timescale,
                X_Prev[i],
            }
            x_stop := rl.Vector2{
                goal_offset - (t - T_Prev[i + 1]) * timescale,
                X_Prev[i + 1],
            }
            
            rl.DrawLineV(x_start, x_stop, rl.BLUE)
            rl.DrawCircleV(x_start, 2, rl.BLUE)
        }
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}