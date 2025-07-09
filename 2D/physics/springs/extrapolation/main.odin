package main

import "core:math"
import "../../../../rlutil/phys"
import rl "vendor:raylib"

// https://theorangeduck.com/page/spring-roll-call#extrapolation

HISTORY_MAX :: 256

x_prev: [HISTORY_MAX]f32
v_prev: [HISTORY_MAX]f32
t_prev: [HISTORY_MAX]f32
g_prev: [HISTORY_MAX]f32

extrapolate :: proc(x: ^f32, v: ^f32, dt: f32, halflife: f32, eps: f32 = 1e-5) {
    y := 0.69314718056 / (halflife + eps)
    x^ = x^ + (v^ / (y + eps)) * (1.0 - phys.fast_negexp(y * dt))
    v^ = v^ * phys.fast_negexp(y * dt)
}

extrapolate_function :: proc(g: ^f32, gv: ^f32, t: f32, freq: f32, amp: f32, phase: f32, off: f32) {
    g^ = amp * math.sin(t * freq + phase) + off
    gv^ = amp * freq * math.cos(t * freq + phase)
}

extrapolate_function1 :: proc(g: ^f32, gv: ^f32, t: f32) {
    g0, gv0, g1, gv1, g2, gv2: f32
    
    extrapolate_function(&g0, &gv0, t, 2.0 * math.PI * 1.5, 40.0, 23.213123, 0)
    extrapolate_function(&g1, &gv1, t, 2.0 * math.PI * 3.4, 14.0, 912.2381, 0)
    extrapolate_function(&g2, &gv2, t, 2.0 * math.PI * 0.4, 21.0, 452.2381, 0)
    
    g^ = 200 + g0 + g1 + g2
    gv^ = gv0 + gv1 + gv2
}

main :: proc() {
    screen_width :: 640
    screen_height :: 360
    
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - extrapolation")
    
    // Init Variables
    t := f32(0.0)
    x := f32(screen_height) / 2.0
    v := f32(0.0)
    g := x
    goalOffset := f32(600)
    
    halflife := f32(0.2)
    dt := f32(1.0 / 60.0)
    timescale := f32(240.0)
    
    extrapolation_toggle := false
    
    rl.SetTargetFPS(i32(1.0 / dt))
    
    // Initialize history arrays
    for i := 0; i < HISTORY_MAX; i += 1 {
        x_prev[i] = x
        v_prev[i] = v
        t_prev[i] = t
        g_prev[i] = x
    }
    
    for !rl.WindowShouldClose() {
        // Shift History
        for i := HISTORY_MAX - 1; i > 0; i -= 1 {
            x_prev[i] = x_prev[i - 1]
            v_prev[i] = v_prev[i - 1]
            t_prev[i] = t_prev[i - 1]
            g_prev[i] = g_prev[i - 1]
        }
        
        // GUI
        button_rect := rl.Rectangle{100, 45, 120, 20}
        if rl.GuiButton(button_rect, "Extrapolate") {
            extrapolation_toggle = !extrapolation_toggle
        }
        slider_rect := rl.Rectangle{100, 20, 120, 20}

        rl.GuiSliderBar(
            slider_rect,
            "halflife",
            rl.TextFormat("%5.3f", halflife),
            &halflife,
            0.0,
            0.5
        )
        // Update Spring
        t += dt
        gv: f32 = 0.0
        extrapolate_function1(&g, &gv, t)
        
        if extrapolation_toggle {
            extrapolate(&x, &v, dt, halflife)
        } else {
            x = g
            v = gv
        }
        
        x_prev[0] = x
        v_prev[0] = v      
        t_prev[0] = t
        g_prev[0] = g
        
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        rl.DrawCircleV(rl.Vector2{goalOffset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goalOffset, x}, 5, rl.DARKBLUE)
        
        for i := 0; i < HISTORY_MAX - 1; i += 1 {
            x_start := rl.Vector2{goalOffset - (t - t_prev[i + 0]) * timescale, x_prev[i + 0]}
            x_stop  := rl.Vector2{goalOffset - (t - t_prev[i + 1]) * timescale, x_prev[i + 1]}
            
            rl.DrawLineV(x_start, x_stop, rl.BLUE)
            rl.DrawCircleV(x_start, 2, rl.BLUE)
        }
        
        for i := 0; i < HISTORY_MAX - 1; i += 1 {
            g_start := rl.Vector2{goalOffset - (t - t_prev[i + 0]) * timescale, g_prev[i + 0]}
            g_stop  := rl.Vector2{goalOffset - (t - t_prev[i + 1]) * timescale, g_prev[i + 1]}
            
            rl.DrawLineV(g_start, g_stop, rl.MAROON)
            rl.DrawCircleV(g_start, 2, rl.MAROON)
        }
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}