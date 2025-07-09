package main

import "core:math"
import "../../../../rlutil/phys"
import rl "vendor:raylib"

// based on: https://theorangeduck.com/page/spring-roll-call#timedspring

HISTORY_MAX :: 256

x_prev: [HISTORY_MAX]f32
v_prev: [HISTORY_MAX]f32
t_prev: [HISTORY_MAX]f32
xi_prev: [HISTORY_MAX]f32

timed_spring_damper_exact :: proc(
    x: ^f32,
    v: ^f32,
    xi: ^f32,
    x_goal: f32,
    t_goal: f32,
    halflife: f32,
    dt: f32,
    apprehension: f32 = 2.0,
) {
    min_time := t_goal > dt ? t_goal : dt
    
    v_goal := (x_goal - xi^) / min_time
    
    t_goal_future := dt + apprehension * halflife
    x_goal_future := t_goal_future < t_goal ? xi^ + v_goal * t_goal_future : x_goal
        
    phys.simple_spring_damper_exact(x, v, x_goal_future, halflife, dt)
    
    xi^ += v_goal * dt
}

main :: proc() {
    screen_width :: 640
    screen_height :: 360
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - timedspring")

    // Init Variables
    t := f32(0.0)
    x := f32(screen_height) / 2.0
    v := f32(0.0)
    g := x
    goal_offset := f32(600)

    halflife := f32(0.1)
    dt := f32(1.0 / 60.0)
    timescale := f32(240.0)

    goal_time := f32(1.0)
    ti := f32(0.0)
    apprehension := f32(2.0)
    xi := x

    rl.SetTargetFPS(i32(1.0 / dt))
    // Initialize history arrays
    for i := 0; i < HISTORY_MAX; i += 1 {
        x_prev[i] = x
        v_prev[i] = v
        t_prev[i] = t
        xi_prev[i] = x
    }
    for !rl.WindowShouldClose() {
        // Shift History
        for i := HISTORY_MAX - 1; i > 0; i -= 1 {
            x_prev[i] = x_prev[i - 1]
            v_prev[i] = v_prev[i - 1]
            t_prev[i] = t_prev[i - 1]
            xi_prev[i] = xi_prev[i - 1]
        }
        // Get Goal
        if rl.IsMouseButtonDown(.RIGHT) {
            g = rl.GetMousePosition().y
            ti = goal_time
        }
        // GUI Controls
        rl.GuiSliderBar(
            rl.Rectangle{100, 20, 120, 20},
            "halflife",
            rl.TextFormat("%5.3f", halflife),
            &halflife,
            0.0,
            1.0,
        )
        rl.GuiSliderBar(
            rl.Rectangle{100, 45, 120, 20},
            "timer reset",
            rl.TextFormat("%5.3f", goal_time),
            &goal_time,
            0.0,
            3.0,
        )
        rl.GuiSliderBar(
            rl.Rectangle{100, 75, 120, 20},
            "apprehension",
            rl.TextFormat("%5.3f", apprehension),
            &apprehension,
            0.0,
            5.0,
        )
        rl.GuiLabel(
            rl.Rectangle{525, 20, 120, 20},
            rl.TextFormat("Timer: %4.2f", ti),
        )
        // Update Spring
        rl.SetTargetFPS(i32(1.0 / dt))
        
        t += dt
        ti -= dt
        ti = ti < 0.0 ? 0.0 : ti
        
        timed_spring_damper_exact(&x, &v, &xi, g, ti, halflife, dt, apprehension)
        
        x_prev[0] = x
        v_prev[0] = v      
        t_prev[0] = t
        xi_prev[0] = xi
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        rl.DrawCircleV(rl.Vector2{goal_offset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goal_offset, x}, 5, rl.DARKBLUE)
        
        // Draw history lines
        for i := 0; i < HISTORY_MAX - 1; i += 1 {
            g_start := rl.Vector2{
                goal_offset - (t - t_prev[i]) * timescale,
                xi_prev[i],
            }
            g_stop := rl.Vector2{
                goal_offset - (t - t_prev[i + 1]) * timescale,
                xi_prev[i + 1],
            }
            
            rl.DrawLineV(g_start, g_stop, rl.MAROON)
            rl.DrawCircleV(g_start, 2, rl.MAROON)
            
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