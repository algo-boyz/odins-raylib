package main

import "core:math"
import "../../../../rlutil/phys"
import rl "vendor:raylib"

// based on: https://theorangeduck.com/page/spring-roll-call#resonance

HISTORY_MAX :: 256

State :: struct {
    x_prev: [HISTORY_MAX]f32,
    v_prev: [HISTORY_MAX]f32,
    t_prev: [HISTORY_MAX]f32,
    g_prev: [HISTORY_MAX]f32,
}

spring_energy :: proc(
    x, v, frequency: f32,
    x_rest := f32(0.0),
    v_rest := f32(0.0),
    scale := f32(1.0),
) -> f32 {
    s := phys.frequency_to_stiffness(frequency)
    return (
        phys.square(scale * (v - v_rest)) + s * phys.square(scale * (x - x_rest))) / 2.0
}

resonant_frequency :: proc(goal_frequency, halflife: f32) -> f32 {
    d := phys.halflife_to_damping(halflife)
    goal_stiffness := phys.frequency_to_stiffness(goal_frequency)
    resonant_stiffness := goal_stiffness - (d * d) / 4.0
    return phys.stiffness_to_frequency(resonant_stiffness)
}

main :: proc() {
    // Window settings
    screen_width :: 640
    screen_height :: 360
    
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - resonance")
    defer rl.CloseWindow()
    
    // Initialize state
    state := State{}
    
    t := f32(0.0)
    x := f32(screen_height) / 2.0
    v := f32(0.0)
    g := x
    goal_offset := f32(600)
    
    frequency := f32(2.0)
    halflife := f32(2.0)
    dt := f32(1.0 / 60.0)
    timescale := f32(240.0)
    
    goal_frequency := f32(2.5)
    energy := f32(0.0)
    
    rl.SetTargetFPS(i32(1.0 / dt))
    
    // Initialize history arrays
    for i := 0; i < HISTORY_MAX; i += 1 {
        state.x_prev[i] = x
        state.v_prev[i] = v
        state.t_prev[i] = t
        state.g_prev[i] = x
    }
    
    for !rl.WindowShouldClose() {
        // Shift history
        for i := HISTORY_MAX - 1; i > 0; i -= 1 {
            state.x_prev[i] = state.x_prev[i - 1]
            state.v_prev[i] = state.v_prev[i - 1]
            state.t_prev[i] = state.t_prev[i - 1]
            state.g_prev[i] = state.g_prev[i - 1]
        }
        
        // Update goal position
        g = f32(screen_height) / 2.0 + 
            10.0 * math.sin_f32(t * 2.0 * math.PI * goal_frequency)
        
        // GUI Controls
        if rl.GuiButton(rl.Rectangle{125, 95, 120, 20}, "Resonant Frequency") {
            frequency = resonant_frequency(goal_frequency, halflife)
        }
        
        rl.GuiSliderBar(
            rl.Rectangle{125, 20, 120, 20},
            "halflife",
            rl.TextFormat("%5.3f", halflife),
            &halflife,
            0.0,
            4.0,
        )
        
        rl.GuiSliderBar(
            rl.Rectangle{125, 45, 120, 20},
            "frequency",
            rl.TextFormat("%5.3f", frequency),
            &frequency,
            0.0,
            5.0,
        )
        
        rl.GuiSliderBar(
            rl.Rectangle{125, 70, 120, 20},
            "goal frequency",
            rl.TextFormat("%5.3f", goal_frequency),
            &goal_frequency,
            0.0,
            5.0,
        )
        
        energy = spring_energy(
            x, v, frequency,
            f32(screen_height) / 2.0,
            0.0,
            0.01,
        )
        
        rl.GuiSliderBar(
            rl.Rectangle{400, 20, 120, 20},
            "energy",
            rl.TextFormat("%4.1f", energy),
            &energy,
            0.0,
            160.0,
        )
        
        // Update spring
        t += dt
        phys.spring_damper_exact(&x, &v, g, 0.0, frequency, halflife, dt)
        
        // Update history
        state.x_prev[0] = x
        state.v_prev[0] = v
        state.t_prev[0] = t
        state.g_prev[0] = g
        
        // Drawing
        rl.BeginDrawing()        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw current positions
        rl.DrawCircleV(rl.Vector2{goal_offset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goal_offset, x}, 5, rl.DARKBLUE)
        
        // Draw history trails
        for i := 0; i < HISTORY_MAX - 1; i += 1 {
            // Position history
            x_start := rl.Vector2{
                goal_offset - (t - state.t_prev[i]) * timescale,
                state.x_prev[i],
            }
            x_stop := rl.Vector2{
                goal_offset - (t - state.t_prev[i + 1]) * timescale,
                state.x_prev[i + 1],
            }
            
            rl.DrawLineV(x_start, x_stop, rl.BLUE)
            rl.DrawCircleV(x_start, 2, rl.BLUE)
            
            // Goal history
            g_start := rl.Vector2{
                goal_offset - (t - state.t_prev[i]) * timescale,
                state.g_prev[i],
            }
            g_stop := rl.Vector2{
                goal_offset - (t - state.t_prev[i + 1]) * timescale,
                state.g_prev[i + 1],
            }
            
            rl.DrawLineV(g_start, g_stop, rl.MAROON)
            rl.DrawCircleV(g_start, 2, rl.MAROON)
        }
        rl.EndDrawing()
    }
}