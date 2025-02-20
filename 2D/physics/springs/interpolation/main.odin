package main

import "core:math"
import "../../../../rlutil/physics/springs"
import rl "vendor:raylib"

// https://theorangeduck.com/page/spring-roll-call#interpolation

CTRL_MAX :: 8

piecewise_interpolation :: proc(t: f32, pnts: []f32) -> (x: f32, v: f32) {
    t_scaled := t * f32(len(pnts) - 1)
    i0 := int(math.floor(t_scaled))
    i1 := i0 + 1
    
    i0 = min(i0, len(pnts) - 1)
    i1 = min(i1, len(pnts) - 1)
    alpha := math.mod(t_scaled, 1.0)
    
    x = math.lerp(pnts[i0], pnts[i1], alpha)
    v = (pnts[i0] - pnts[i1]) / f32(len(pnts))
    return
}

main :: proc() {
    screen_width :: 640
    screen_height :: 360
    
    ctrlx: [CTRL_MAX]f32
    ctrly: [CTRL_MAX]f32
    
    rl.InitWindow(screen_width, screen_height, "raylib [springs] example - interpolation")
    defer rl.CloseWindow()
    
    // Init variables
    halflife := f32(0.5)
    frequency := f32(1.5)
    ctrl_selected := -1
    
    // Initialize control points
    for i in 0..<CTRL_MAX {
        ctrlx[i] = (f32(i) / f32(CTRL_MAX)) * 600 + 20
        ctrly[i] = math.sin(f32(i)) * 100 + 100
    }
    
    for !rl.WindowShouldClose() {
        mouse_pos := rl.GetMousePosition()
        
        if rl.IsMouseButtonPressed(.RIGHT) {
            best_dist := f32(math.F32_MAX)
            for i in 0..<CTRL_MAX {
                dist := springs.square(ctrlx[i] - mouse_pos.x) + springs.square(ctrly[i] - mouse_pos.y)
                if dist < best_dist {
                    best_dist = dist
                    ctrl_selected = i
                }
            }
        }
        
        if rl.IsMouseButtonDown(.RIGHT) {
            ctrlx[ctrl_selected] = mouse_pos.x
            ctrly[ctrl_selected] = mouse_pos.y
        }
        
        // GUI Controls
        frequency_rect := rl.Rectangle{100, 20, 120, 20}
        halflife_rect := rl.Rectangle{100, 45, 120, 20}
        
        rl.GuiSliderBar(frequency_rect, "frequency", rl.TextFormat("%5.3f", frequency), &frequency, 0.0, 3.0)
        rl.GuiSliderBar(halflife_rect, "halflife", rl.TextFormat("%5.3f", halflife), &halflife, 0.0, 1.0)
        
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw control points and lines
        for i in 0..<CTRL_MAX {
            rl.DrawCircleV({ctrlx[i], ctrly[i]}, 4, rl.MAROON)
            if i < CTRL_MAX - 1 {
                rl.DrawLineV(
                    {ctrlx[i], ctrly[i]},
                    {ctrlx[i + 1], ctrly[i + 1]},
                    rl.RED,
                )
            }
        }
        
        // Interpolation visualization
        sx := ctrlx[0]
        sy := ctrly[0]
        svx := (ctrlx[1] - ctrlx[0]) / f32(CTRL_MAX)
        svy := (ctrly[1] - ctrly[0]) / f32(CTRL_MAX)
        
        rl.DrawCircleV({sx, sy}, 2, rl.BLUE)
        
        subsamples :: 100
        for i in 0..<subsamples {
            start := rl.Vector2{sx, sy}
            
            t := f32(i) / f32(subsamples - 1)
            goalx, goalvx := piecewise_interpolation(t, ctrlx[:])
            goaly, goalvy := piecewise_interpolation(t, ctrly[:])
            
            dt := f32(CTRL_MAX) / f32(subsamples)
            springs.spring_damper_exact(&sx, &svx, goalx, goalvx, halflife, frequency, dt)
            springs.spring_damper_exact(&sy, &svy, goaly, goalvy, halflife, frequency, dt)
            
            stop := rl.Vector2{sx, sy}
            
            rl.DrawLineV(start, stop, rl.DARKBLUE)
            rl.DrawCircleV(stop, 2, rl.BLUE)
        }
    }
}