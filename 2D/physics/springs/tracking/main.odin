package main

import "core:math"
import "../../../../rlutil/phys"
import rl "vendor:raylib"

// based on: https://theorangeduck.com/page/spring-roll-call#trackingspring

tracking_function :: proc(g, gv: ^f32, t, freq, amp, phase, off: f32) {
    g^ = amp * math.sin(t * freq + phase) + off
    gv^ = amp * freq * math.cos(t * freq + phase)
}

tracking_function1 :: proc(g, gv: ^f32, t: f32) {
    tracking_function(g, gv, t, 2.0 * math.PI * 1.25, 74.0, 23.213123, 254)
}

tracking_function2 :: proc(g, gv: ^f32, t: f32) {
    tracking_function(g, gv, t, 2.0 * math.PI * 3.4, 28.0, 912.2381, 113)
}

tracking_spring_update :: proc(
    x, v: ^f32,
    x_goal, v_goal, a_goal: f32,
    x_gain, v_gain, a_gain: f32,
    dt: f32,
) {
    v^ = math.lerp(v^, v^ + a_goal * dt, a_gain)
    v^ = math.lerp(v^, v_goal, v_gain)
    v^ = math.lerp(v^, (x_goal - x^) / dt, x_gain)
    x^ = x^ + dt * v^
}

tracking_spring_update_no_acceleration :: proc(
    x, v: ^f32,
    x_goal, v_goal: f32,
    x_gain, v_gain: f32,
    dt: f32,
) {
    v^ = math.lerp(v^, v_goal, v_gain)
    v^ = math.lerp(v^, (x_goal - x^) / dt, x_gain)
    x^ = x^ + dt * v^
}

tracking_spring_update_no_velocity_acceleration :: proc(
    x, v: ^f32,
    x_goal: f32,
    x_gain: f32,
    dt: f32,
) {
    v^ = math.lerp(v^, (x_goal - x^) / dt, x_gain)
    x^ = x^ + dt * v^
}

tracking_spring_update_improved :: proc(
    x, v: ^f32,
    x_goal, v_goal, a_goal: f32,
    x_halflife, v_halflife, a_halflife: f32,
    dt: f32,
) {
    v^ = phys.damper_exact(v^, v^ + a_goal * dt, a_halflife, dt)
    v^ = phys.damper_exact(v^, v_goal, v_halflife, dt)
    v^ = phys.damper_exact(v^, (x_goal - x^) / dt, x_halflife, dt)
    x^ = x^ + dt * v^
}

tracking_spring_update_no_acceleration_improved :: proc(
    x, v: ^f32,
    x_goal, v_goal: f32,
    x_halflife, v_halflife: f32,
    dt: f32,
) {
    v^ = phys.damper_exact(v^, v_goal, v_halflife, dt)
    v^ = phys.damper_exact(v^, (x_goal - x^) / dt, x_halflife, dt)
    x^ = x^ + dt * v^
}

tracking_spring_update_no_velocity_acceleration_improved :: proc(
    x, v: ^f32,
    x_goal: f32,
    x_halflife: f32,
    dt: f32,
) {
    v^ = phys.damper_exact(v^, (x_goal - x^) / dt, x_halflife, dt)
    x^ = x^ + dt * v^
}

tracking_spring_update_exact :: proc(
    x, v: ^f32,
    x_goal, v_goal, a_goal: f32,
    x_gain, v_gain, a_gain: f32,
    dt, gain_dt: f32,
) {
    t0 := (1.0 - v_gain) * (1.0 - x_gain)
    t1 := a_gain * (1.0 - v_gain) * (1.0 - x_gain)
    t2 := (v_gain * (1.0 - x_gain)) / gain_dt
    t3 := x_gain / (gain_dt * gain_dt)
    
    stiffness := t3
    damping := (1.0 - t0) / gain_dt
    spring_x_goal := x_goal
    spring_v_goal := (t2 * v_goal + t1 * a_goal) / ((1.0 - t0) / gain_dt)
    
    phys.spring_damper_exact_stiffness_damping(
        x, v,
        spring_x_goal,
        spring_v_goal,
        stiffness,
        damping,
        dt,
    )
}

tracking_spring_update_no_acceleration_exact :: proc(
    x, v: ^f32,
    x_goal, v_goal: f32,
    x_gain, v_gain: f32,
    dt, gain_dt: f32,
) {
    t0 := (1.0 - v_gain) * (1.0 - x_gain)
    t2 := (v_gain * (1.0 - x_gain)) / gain_dt
    t3 := x_gain / (gain_dt * gain_dt)
    
    stiffness := t3
    damping := (1.0 - t0) / gain_dt
    spring_x_goal := x_goal
    spring_v_goal := t2 * v_goal / ((1.0 - t0) / gain_dt)

    phys.spring_damper_exact_stiffness_damping(
        x, v,
        spring_x_goal,
        spring_v_goal,
        stiffness,
        damping,
        dt,
    )
}

tracking_spring_update_no_velocity_acceleration_exact :: proc(
    x, v: ^f32,
    x_goal: f32,
    x_gain: f32,
    dt, gain_dt: f32,
) {
    t0 := 1.0 - x_gain
    t3 := x_gain / (gain_dt * gain_dt)
    
    stiffness := t3
    damping := (1.0 - t0) / gain_dt
    spring_x_goal := x_goal
    spring_v_goal:f32
  
    phys.spring_damper_exact_stiffness_damping(
        x, v,
        spring_x_goal,
        spring_v_goal,
        stiffness,
        damping,
        dt,
    )
}

tracking_target_acceleration :: proc(
    x_next, x_curr, x_prev: f32,
    dt: f32,
) -> f32 {
    return (((x_next - x_curr) / dt) - ((x_curr - x_prev) / dt)) / dt
}

tracking_target_velocity :: proc(
    x_next, x_curr: f32,
    dt: f32,
) -> f32 {
    return (x_next - x_curr) / dt
}

HISTORY_MAX :: 256

main :: proc() {
    // Init Window
    screen_width :: 640
    screen_height :: 360
    
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - tracking")
    defer rl.CloseWindow()

    // Init Variables
    t: f32 = 0.0
    x: f32 = f32(screen_height) / 2.0
    v: f32 = 0.0
    g: f32 = x
    goal_offset: f32 = 600

    halflife: f32 = 0.1
    dt: f32 = 1.0 / 60.0
    timescale: f32 = 240.0
    
    x_gain: f32 = 0.01
    v_gain: f32 = 0.2
    a_gain: f32 = 1.0
    
    x_halflife: f32 = 1.0
    v_halflife: f32 = 0.05
    a_halflife: f32 = 0.0
    
    v_max: f32 = 750.0
    a_max: f32 = 12500.0
    
    tracking_toggle := true
    time_since_switch := 0
    clamping := false
    improved := true
    exact := true

    x_prev: [HISTORY_MAX]f32
    v_prev: [HISTORY_MAX]f32
    t_prev: [HISTORY_MAX]f32
    g_prev: [HISTORY_MAX]f32

    for i in 0..<HISTORY_MAX {
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

        // Note: GUI elements are omitted for now as they require additional implementation
        
        t += dt
        
        gv: f32 = 0.0
        if tracking_toggle {
            tracking_function1(&g, &gv, t)
        } else {
            tracking_function2(&g, &gv, t)
        }
        
        if clamping || time_since_switch > 1 {
            x_goal := g
            v_goal := tracking_target_velocity(g, g_prev[1], dt)
            a_goal := tracking_target_acceleration(g, g_prev[1], g_prev[2], dt)
          
            if clamping {
                v_goal = clamp(v_goal, -v_max, v_max)
                a_goal = clamp(a_goal, -a_max, a_max)
            }
            
            if exact {
                tracking_spring_update_exact(
                    &x, &v,
                    x_goal, v_goal, a_goal,
                    x_gain, v_gain, a_gain,
                    dt, 1.0 / 60.0,
                )
            } else if improved {
                tracking_spring_update_improved(
                    &x, &v,
                    x_goal, v_goal, a_goal,
                    x_halflife, v_halflife, a_halflife,
                    dt,
                )
            } else {
                tracking_spring_update(
                    &x, &v,
                    x_goal, v_goal, a_goal,
                    x_gain, v_gain, a_gain,
                    dt,
                )
            }
        } else if time_since_switch > 0 {
            x_goal := g
            v_goal := tracking_target_velocity(g, g_prev[1], dt)
            
            if exact {
                tracking_spring_update_no_acceleration_exact(
                    &x, &v,
                    x_goal, v_goal,
                    x_gain, v_gain,
                    dt, 1.0 / 60.0,
                )
            } else if improved {
                tracking_spring_update_no_acceleration_improved(
                    &x, &v,
                    x_goal, v_goal,
                    x_halflife, v_halflife,
                    dt,
                )
            } else {
                tracking_spring_update_no_acceleration(
                    &x, &v,
                    x_goal, v_goal,
                    x_gain, v_gain,
                    dt,
                )
            }
        } else {
            x_goal := g
            
            if exact {
                tracking_spring_update_no_velocity_acceleration_exact(
                    &x, &v,
                    x_goal,
                    x_gain,
                    dt, 1.0 / 60.0,
                )
            } else if improved {
                tracking_spring_update_no_velocity_acceleration_improved(
                    &x, &v,
                    x_goal,
                    x_halflife,
                    dt,
                )
            } else {
                tracking_spring_update_no_velocity_acceleration(
                    &x, &v,
                    x_goal,
                    x_gain,
                    dt,
                )
            }
        }
        
        x_prev[0] = x
        v_prev[0] = v      
        t_prev[0] = t
        g_prev[0] = g
        
        rl.BeginDrawing()        
        rl.ClearBackground(rl.RAYWHITE)
        
        rl.DrawCircleV(rl.Vector2{goal_offset, g}, 5, rl.MAROON)
        rl.DrawCircleV(rl.Vector2{goal_offset, x}, 5, rl.DARKBLUE)
        
        for i in 0..<HISTORY_MAX-1 {
            x_start := rl.Vector2{goal_offset - (t - t_prev[i]) * timescale, x_prev[i]}
            x_stop := rl.Vector2{goal_offset - (t - t_prev[i + 1]) * timescale, x_prev[i + 1]}
            
            rl.DrawLineV(x_start, x_stop, rl.BLUE)
            rl.DrawCircleV(x_start, 2, rl.BLUE)
        }
        
        for i in 0..<HISTORY_MAX-1 {
            g_start := rl.Vector2{goal_offset - (t - t_prev[i]) * timescale, g_prev[i]}
            g_stop := rl.Vector2{goal_offset - (t - t_prev[i + 1]) * timescale, g_prev[i + 1]}
            
            rl.DrawLineV(g_start, g_stop, rl.MAROON)
            rl.DrawCircleV(g_start, 2, rl.MAROON)
        }
        rl.EndDrawing()
    }
}