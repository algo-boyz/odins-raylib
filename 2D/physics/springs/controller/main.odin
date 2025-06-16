package main

import "core:math"
import "../../../../rlutil/physics/springs"
import rl "vendor:raylib"

spring_character_update :: proc(
    x: ^f32,
    v: ^f32,
    a: ^f32,
    v_goal: f32,
    halflife: f32,
    dt: f32,
) {
    y := springs.halflife_to_damping(halflife) / 2.0
    j0 := v^ - v_goal
    j1 := a^ + j0 * y
    eydt := springs.fast_negexp(y * dt)

    x^ = eydt * (((-j1)/(y*y)) + ((-j0 - j1*dt)/y)) + 
         (j1/(y*y)) + j0/y + v_goal * dt + x^
    v^ = eydt * (j0 + j1*dt) + v_goal
    a^ = eydt * (a^ - j1*y*dt)
}

spring_character_predict :: proc(
    px: []f32,
    pv: []f32,
    pa: []f32,
    x: f32,
    v: f32,
    a: f32,
    v_goal: f32,
    halflife: f32,
    dt: f32,
) {
    for i := 0; i < len(px); i += 1 {
        px[i] = x
        pv[i] = v
        pa[i] = a
    }

    for i := 0; i < len(px); i += 1 {
        spring_character_update(&px[i], &pv[i], &pa[i], v_goal, halflife, f32(i) * dt)
    }
}

TRAJ_MAX :: 32
TRAJ_SUB :: 4
PRED_MAX :: 4
PRED_SUB :: 4

main :: proc() {
    // Initialize global arrays
    trajx_prev := make([]f32, TRAJ_MAX)
    trajy_prev := make([]f32, TRAJ_MAX)
    predx := make([]f32, PRED_MAX)
    predy := make([]f32, PRED_MAX)
    predxv := make([]f32, PRED_MAX)
    predyv := make([]f32, PRED_MAX)
    predxa := make([]f32, PRED_MAX)
    predya := make([]f32, PRED_MAX)
    defer {
        delete(trajx_prev)
        delete(trajy_prev)
        delete(predx)
        delete(predy)
        delete(predxv)
        delete(predyv)
        delete(predxa)
        delete(predya)
    }

    screen_width :: 640
    screen_height :: 360

    rl.InitWindow(screen_width, screen_height, "Odin [springs] example - controller")
    defer rl.CloseWindow()

    // Init Variables
    halflife := f32(0.1)
    dt := f32(1.0 / 60.0)
    timescale := f32(240.0)
    
    rl.SetTargetFPS(i32(1.0 / dt))

    // Trajectory
    trajx := f32(screen_width) / 2.0
    trajy := f32(screen_height) / 2.0
    trajxv := f32(0.0)
    trajyv := f32(0.0)
    trajxa := f32(0.0)
    trajya := f32(0.0)
    traj_xv_goal := f32(0.0)
    traj_yv_goal := f32(0.0)
    
    // Initialize trajectory history
    for i := 0; i < TRAJ_MAX; i += 1 {
        trajx_prev[i] = f32(screen_width) / 2.0
        trajy_prev[i] = f32(screen_height) / 2.0
    }
    
    for !rl.WindowShouldClose() {
        // Shift History
        for i := TRAJ_MAX - 1; i > 0; i -= 1 {
            trajx_prev[i] = trajx_prev[i - 1]
            trajy_prev[i] = trajy_prev[i - 1]
        }
        
        // Gamepad Controller
        // Note: Using a simplified GUI for now since raylib's GuiSliderBar isn't directly available
        halflife = math.clamp(halflife, 0.0, 1.0)

        // Update Spring
        gamepadx := rl.GetGamepadAxisMovement(0, .LEFT_X)
        gamepady := rl.GetGamepadAxisMovement(0, .LEFT_Y)
        gamepadmag := math.sqrt(gamepadx * gamepadx + gamepady * gamepady)
        
        if gamepadmag > 0.2 {
            gamepaddirx := gamepadx / gamepadmag
            gamepaddiry := gamepady / gamepadmag
            gamepadclippedmag := gamepadmag > 1.0 ? 1.0 : gamepadmag * gamepadmag
            gamepadx = gamepaddirx * gamepadclippedmag
            gamepady = gamepaddiry * gamepadclippedmag
        } else {
            gamepadx = 0.0
            gamepady = 0.0
        }
        
        traj_xv_goal = 250.0 * gamepadx
        traj_yv_goal = 250.0 * gamepady
        
        spring_character_update(&trajx, &trajxv, &trajxa, traj_xv_goal, halflife, dt)
        spring_character_update(&trajy, &trajyv, &trajya, traj_yv_goal, halflife, dt)
        
        spring_character_predict(predx, predxv, predxa, trajx, trajxv, trajxa, traj_xv_goal, halflife, dt * f32(PRED_SUB))
        spring_character_predict(predy, predyv, predya, trajy, trajyv, trajya, traj_yv_goal, halflife, dt * f32(PRED_SUB))
        
        trajx_prev[0] = trajx
        trajy_prev[0] = trajy

        rl.BeginDrawing()        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw trajectory history
        for i := 0; i < TRAJ_MAX - TRAJ_SUB; i += TRAJ_SUB {
            start := rl.Vector2{trajx_prev[i], trajy_prev[i]}
            stop := rl.Vector2{trajx_prev[i + TRAJ_SUB], trajy_prev[i + TRAJ_SUB]}
            
            rl.DrawLineV(start, stop, rl.BLUE)
            rl.DrawCircleV(start, 3, rl.BLUE)
        }
        
        // Draw prediction
        for i := 1; i < PRED_MAX; i += 1 {
            start := rl.Vector2{predx[i], predy[i]}
            stop := rl.Vector2{predx[i-1], predy[i-1]}
            
            rl.DrawLineV(start, stop, rl.MAROON)
            rl.DrawCircleV(start, 3, rl.MAROON)
        }
        
        rl.DrawCircleV(rl.Vector2{trajx, trajy}, 4, rl.DARKBLUE)
        
        // Draw gamepad visualization
        gamepad_pos := rl.Vector2{60, 300}
        gamepad_stick_pos := rl.Vector2{
            gamepad_pos.x + gamepadx * 25,
            gamepad_pos.y + gamepady * 25,
        }
        rl.DrawCircleLines(i32(gamepad_pos.x), i32(gamepad_pos.y), 25, rl.DARKPURPLE)
        rl.DrawCircleV(gamepad_pos, 3, rl.DARKPURPLE)
        rl.DrawCircleV(gamepad_stick_pos, 3, rl.DARKPURPLE)
        rl.DrawLineV(gamepad_pos, gamepad_stick_pos, rl.DARKPURPLE)
        rl.EndDrawing()
    }
}