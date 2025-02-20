package main

import "core:math"
import rl "vendor:raylib"

// https://theorangeduck.com/page/spring-roll-call#filtering

HISTORY_MAX :: 256

x_prev: [HISTORY_MAX]f32
v_prev: [HISTORY_MAX]f32
t_prev: [HISTORY_MAX]f32
g_prev: [HISTORY_MAX]f32

dead_blending_transition :: proc(
    ext_x: ^f32,  // Extrapolated position
    ext_v: ^f32,  // Extrapolated velocity
    ext_t: ^f32,  // Time since transition
    src_x: f32,   // Current position
    src_v: f32,   // Current velocity
) {
    ext_x^ = src_x
    ext_v^ = src_v
    ext_t^ = 0.0
}

smoothstep :: proc(x: f32) -> f32 {
    x_clamped := clamp(x, 0.0, 1.0)
    return x_clamped * x_clamped * (3.0 - 2.0 * x_clamped)
}

dead_blending_update :: proc(
    out_x: ^f32,    // Output position
    out_v: ^f32,    // Output velocity
    ext_x: ^f32,    // Extrapolated position
    ext_v: ^f32,    // Extrapolated velocity
    ext_t: ^f32,    // Time since transition
    in_x: f32,      // Input position
    in_v: f32,      // Input velocity
    blendtime: f32, // Blend time
    dt: f32,        // Delta time
    eps: f32 = 1e-8,
) {
    if ext_t^ < blendtime {
        ext_x^ += ext_v^ * dt
        ext_t^ += dt

        alpha := smoothstep(ext_t^ / max(blendtime, eps))
        out_x^ = math.lerp(ext_x^, in_x, alpha)
        out_v^ = math.lerp(ext_v^, in_v, alpha)
    } else {
        out_x^ = in_x
        out_v^ = in_v
        ext_t^ = math.F32_MAX
    }
}

inertialize_function :: proc(
    g: ^f32,
    gv: ^f32,
    t: f32,
    freq: f32,
    amp: f32,
    phase: f32,
    off: f32,
) {
    g^ = amp * math.sin(t * freq + phase) + off
    gv^ = amp * freq * math.cos(t * freq + phase)
}

inertialize_1 :: proc(g: ^f32, gv: ^f32, t: f32) {
    inertialize_function(g, gv, t, 2.0 * math.PI * 1.25, 74.0, 23.213123, 254)
}

inertialize_2 :: proc(g: ^f32, gv: ^f32, t: f32) {
    inertialize_function(g, gv, t, 2.0 * math.PI * 3.4, 28.0, 912.2381, 113)
}

main :: proc() {
    // Init Window
    screen_width :: 640
    screen_height :: 360
    
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - inertialization")
    
    // Init Variables
    t := f32(0.0)
    x := f32(screen_height) / 2.0
    v := f32(0.0)
    g := x
    goalOffset := f32(600)
    
    blendtime := f32(0.5)
    dt := f32(1.0 / 60.0)
    timescale := f32(240.0)
    
    ext_x := f32(0.0)
    ext_v := f32(0.0)
    ext_t:f32 = math.F32_MAX
    inertialize_toggle := false
    
    rl.SetTargetFPS(i32(1.0 / dt))
    
    // Initialize history arrays
    for i in 0..<HISTORY_MAX {
        x_prev[i] = x
        v_prev[i] = v
        t_prev[i] = t
        g_prev[i] = x
    }
    
    for !rl.WindowShouldClose() {
        // Shift History
        for i := HISTORY_MAX-1; i > 0; i -= 1 {
            x_prev[i] = x_prev[i-1]
            v_prev[i] = v_prev[i-1]
            t_prev[i] = t_prev[i-1]
            g_prev[i] = g_prev[i-1]
        }
        
        // GUI Button
        if rl.GuiButton(rl.Rectangle{100, 45, 120, 20}, "Transition") {
            inertialize_toggle = !inertialize_toggle
            
            src_x := x_prev[1]
            src_v := (x_prev[1] - x_prev[2]) / (t_prev[1] - t_prev[2])
            
            dead_blending_transition(&ext_x, &ext_v, &ext_t, src_x, src_v)
        }
        
        // GUI Slider
        rl.GuiSliderBar(
            rl.Rectangle{100, 20, 120, 20},
            "blendtime",
            rl.TextFormat("%5.3f", blendtime),
            &blendtime,
            0.0,
            1.0,
        )
        
        // Update Spring
        t += dt
        
        gv := f32(0.0)
        if inertialize_toggle {
            inertialize_1(&g, &gv, t)
        } else {
            inertialize_2(&g, &gv, t)
        }
        
        dead_blending_update(&x, &v, &ext_x, &ext_v, &ext_t, g, gv, blendtime, dt)
        
        x_prev[0] = x
        v_prev[0] = v
        t_prev[0] = t
        g_prev[0] = g
        
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        rl.DrawCircleV(rl.Vector2{goalOffset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goalOffset, x}, 5, rl.DARKBLUE)
        
        for i in 0..<HISTORY_MAX-1 {
            x_start := rl.Vector2{
                goalOffset - (t - t_prev[i]) * timescale,
                x_prev[i],
            }
            x_stop := rl.Vector2{
                goalOffset - (t - t_prev[i+1]) * timescale,
                x_prev[i+1],
            }
            
            rl.DrawLineV(x_start, x_stop, rl.BLUE)
            rl.DrawCircleV(x_start, 2, rl.BLUE)
            
            g_start := rl.Vector2{
                goalOffset - (t - t_prev[i]) * timescale,
                g_prev[i],
            }
            g_stop := rl.Vector2{
                goalOffset - (t - t_prev[i+1]) * timescale,
                g_prev[i+1],
            }
            
            rl.DrawLineV(g_start, g_stop, rl.MAROON)
            rl.DrawCircleV(g_start, 2, rl.MAROON)
        }
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}