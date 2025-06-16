package main

import "core:math"
import "../../../../rlutil/physics/springs"
import rl "vendor:raylib"

// https://theorangeduck.com/page/spring-roll-call#inertialization

HISTORY_MAX :: 256

inertialize_transition :: proc(
    off_x, off_v: ^f32,
    src_x, src_v: f32,
    dst_x, dst_v: f32,
) {
    off_x^ = (src_x + off_x^) - dst_x
    off_v^ = (src_v + off_v^) - dst_v
}

inertialize_update :: proc(
    out_x, out_v: ^f32,
    off_x, off_v: ^f32,
    in_x, in_v: f32,
    halflife, dt: f32,
) {
    springs.decay_spring_damper_exact(off_x, off_v, halflife, dt)
    out_x^ = in_x + off_x^
    out_v^ = in_v + off_v^
}

inertialize_function :: proc(g, gv: ^f32, t, freq, amp, phase, off: f32) {
    g^ = amp * math.sin(t * freq + phase) + off
    gv^ = amp * freq * math.cos(t * freq + phase)
}

inertialize_function1 :: proc(g, gv: ^f32, t: f32) {
    inertialize_function(g, gv, t, 2.0 * math.PI * 1.25, 74.0, 23.213123, 254)
}

inertialize_function2 :: proc(g, gv: ^f32, t: f32) {
    inertialize_function(g, gv, t, 2.0 * math.PI * 3.4, 28.0, 912.2381, 113)
}

main :: proc() {
    // Initialize history arrays
    x_prev := make([]f32, HISTORY_MAX)
    v_prev := make([]f32, HISTORY_MAX)
    t_prev := make([]f32, HISTORY_MAX)
    g_prev := make([]f32, HISTORY_MAX)
    defer delete(x_prev)
    defer delete(v_prev)
    defer delete(t_prev)
    defer delete(g_prev)

    screen_width  :: 640
    screen_height :: 360

    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - inertialization")
    defer rl.CloseWindow()

    // Init Variables
    t := f32(0.0)
    x := f32(screen_height) / 2.0
    v := f32(0.0)
    g := x
    goal_offset := f32(600)

    halflife := f32(0.1)
    dt := f32(1.0 / 60.0)
    timescale := f32(240.0)
    
    off_x := f32(0.0)
    off_v := f32(0.0)
    inertialize_toggle := false

    // Initialize history arrays
    for i := 0; i < HISTORY_MAX; i += 1 {
        x_prev[i] = x
        v_prev[i] = v
        t_prev[i] = t
        g_prev[i] = x
    }

    rl.SetTargetFPS(i32(1.0 / dt))

    for !rl.WindowShouldClose() {
        // Shift History
        for i := HISTORY_MAX - 1; i > 0; i -= 1 {
            x_prev[i] = x_prev[i - 1]
            v_prev[i] = v_prev[i - 1]
            t_prev[i] = t_prev[i - 1]
            g_prev[i] = g_prev[i - 1]
        }

        // GUI Controls
        if rl.GuiButton(rl.Rectangle{100, 75, 120, 20}, "Transition") {
            inertialize_toggle = !inertialize_toggle
            
            src_x := g_prev[1]
            src_v := (g_prev[1] - g_prev[2]) / (t_prev[1] - t_prev[2])
            dst_x, dst_v: f32

            if inertialize_toggle {
                inertialize_function1(&dst_x, &dst_v, t)
            } else {
                inertialize_function2(&dst_x, &dst_v, t)
            }

            inertialize_transition(
                &off_x, &off_v,
                src_x, src_v,
                dst_x, dst_v)
        }

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
            "dt",
            rl.TextFormat("%5.3f", dt),
            &dt,
            1.0 / 60.0,
            0.1,
        )

        // Update Spring
        rl.SetTargetFPS(i32(1.0 / dt))
        t += dt

        gv := f32(0.0)
        if inertialize_toggle {
            inertialize_function1(&g, &gv, t)
        } else {
            inertialize_function2(&g, &gv, t)
        }

        inertialize_update(&x, &v, &off_x, &off_v, g, gv, halflife, dt)

        x_prev[0] = x
        v_prev[0] = v
        t_prev[0] = t
        g_prev[0] = g

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        // Draw current positions
        rl.DrawCircleV(rl.Vector2{goal_offset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goal_offset, x}, 5, rl.DARKBLUE)

        // Draw history
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

            g_start := rl.Vector2{
                goal_offset - (t - t_prev[i]) * timescale,
                g_prev[i],
            }
            g_stop := rl.Vector2{
                goal_offset - (t - t_prev[i + 1]) * timescale,
                g_prev[i + 1],
            }

            rl.DrawLineV(g_start, g_stop, rl.MAROON)
            rl.DrawCircleV(g_start, 2, rl.MAROON)
        }
        rl.EndDrawing()
    }
}