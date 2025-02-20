package main

import "core:fmt"
import "../../../../rlutil/physics/springs"
import rl "vendor:raylib"

// based on: https://theorangeduck.com/page/spring-roll-call#velocityspring

HISTORY_MAX :: 256

// Global state
x_prev: [HISTORY_MAX]f32
v_prev: [HISTORY_MAX]f32
t_prev: [HISTORY_MAX]f32
xi_prev: [HISTORY_MAX]f32

main :: proc() {
    // Window initialization
    screen_width :: 640
    screen_height :: 360
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - spring damper")
    
    // Initialize variables
    t: f32 = 0.0
    x := f32(screen_height / 2)
    v: f32 = 0.0
    g: f32 = x
    goal_offset: f32 = 600

    halflife: f32 = 0.1
    dt: f32 = 1.0 / 60.0
    timescale: f32 = 240.0

    goal_velocity: f32 = 100.0
    apprehension: f32 = 2.0

    xi := x

    rl.SetTargetFPS(i32(1 / dt))
    
    // Initialize history
    for i := 0; i < HISTORY_MAX; i += 1 {
        x_prev[i] = x
        v_prev[i] = v
        t_prev[i] = t

        xi_prev[i] = x
    }
    
    for !rl.WindowShouldClose() {
        // Shift history
        for i := HISTORY_MAX - 1; i > 0; i -= 1 {
            x_prev[i] = x_prev[i - 1]
            v_prev[i] = v_prev[i - 1]
            t_prev[i] = t_prev[i - 1]
            xi_prev[i] = xi_prev[i - 1]
        }
        
        // Get goal
        if rl.IsMouseButtonDown(.RIGHT) {
            mouse_pos := rl.GetMousePosition()
            g = mouse_pos.y
        }
    
        // GUI controls

        rl.GuiSliderBar(
            rl.Rectangle{100, 20, 120, 20},
            "goal velocity",
            rl.TextFormat("%5.3f", goal_velocity),
            &goal_velocity,
            0.0,
            500.0,
        )

        rl.GuiSliderBar(
            rl.Rectangle{100, 45, 120, 20},
            "halflife",
            fmt.ctprintf("%5.3f", halflife),
            &halflife,
            0.0,
            1.0,
        )
        
        rl.GuiSliderBar(
            rl.Rectangle{100, 75, 120, 20},
            "apprehension",
            fmt.ctprintf("%5.3f", apprehension),
            &apprehension,
            0,
            5,
        )
        
        // Update spring
        rl.SetTargetFPS(i32(1.0 / dt))
        
        t += dt
        springs.velocity_spring_damper_exact(&x, &v, &xi, g, goal_velocity, halflife, dt)
        
        x_prev[0] = x
        v_prev[0] = v
        t_prev[0] = t
        xi_prev[0] = xi
        
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw goal and current position
        rl.DrawCircleV(rl.Vector2{goal_offset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goal_offset, x}, 5, rl.DARKBLUE)
        
        // Draw history
        for i := 0; i < HISTORY_MAX - 1; i += 1 {
            g_start := rl.Vector2{
                goal_offset - (t - t_prev[i]) * timescale,
                xi_prev[i],
            }
            g_stop := rl.Vector2{
                goal_offset - (t - x_prev[i + 1]) * timescale,
                xi_prev[i + 1],
            }
            
            rl.DrawLineV(g_start, g_stop, rl.MAROON)
            rl.DrawCircleV(g_start, 2, rl.MAROON)
        }
        for i := 0; i < HISTORY_MAX - 1; i += 1 {
            x_start := rl.Vector2{
                goal_offset - (t - t_prev[i]) * timescale,
                x_prev[i],
            }
            x_stop := rl.Vector2{
                goal_offset - (t - t_prev[i + 1]) * timescale,
                x_prev[i + 1],
            }
            
            rl.DrawLineV(x_start, x_stop, rl.BLUE)
            rl.DrawCircleV(x_start, 2, rl.BLUE)
        }
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}