
package main

import rl "vendor:raylib"
import "core:math"

// Definition of the Bézier trajectory
BezierCurve :: struct {
    p0, p1, p2, p3: rl.Vector2,
}

// Calc point on a Bézier curve
bezier_point :: proc(curve: BezierCurve, t: f32) -> rl.Vector2 {
    u := 1 - t
    tt := t * t
    uu := u * u
    uuu := uu * u
    ttt := tt * t

    return rl.Vector2{
        uuu * curve.p0.x + 3 * uu * t * curve.p1.x + 3 * u * tt * curve.p2.x + ttt * curve.p3.x,
        uuu * curve.p0.y + 3 * uu * t * curve.p1.y + 3 * u * tt * curve.p2.y + ttt * curve.p3.y,
    }
}

// Calc point on a sinusoidal curve
sinusoidal_point :: proc(t: f32, amplitude: f32, frequency: f32, center: rl.Vector2) -> rl.Vector2 {
    return  rl.Vector2{
        center.x + t,
        center.y + amplitude * math.sin(frequency * t),
    }
}

main :: proc() {
    rl.InitWindow(800, 450, "Text Animation")
    rl.SetTargetFPS(60)
    
    // Text params
    text :: "Raylib rocks!"
    text_position := rl.Vector2{0, 0}  // Initial position
    text_color := rl.WHITE
    font_size :: 20
    
    // Bézier trajectory
    bezier_curve := BezierCurve{
        p0 = {50, 50},    // Starting point
        p1 = {200, 300},  // Control point 1
        p2 = {600, 100},  // Control point 2
        p3 = {750, 400},  // End point
    }
    
    // Sinusoidal curve params
    sinusoidal_amplitude: f32 = 50
    sinusoidal_frequency: f32 = 0.1
    sinusoidal_center := rl.Vector2{50, 225}
    
    // Variable to track animation progress (0.0 to 1.0)
    animation_progress: f32
    // Trajectory type: 0 = Bézier, 1 = Sinusoidal
    trajectory_type: i32
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        animation_progress += 0.005  // Increase anim progress
        if animation_progress > 1 {
            animation_progress = 0  // Restart animation
        }
        
        // Calc text position based on chosen trajectory
        switch trajectory_type {
        case 0:
            text_position = bezier_point(bezier_curve, animation_progress)
        case 1:
            text_position = sinusoidal_point(
                animation_progress * 700, 
                sinusoidal_amplitude, 
                sinusoidal_frequency, 
                sinusoidal_center
            )
        }
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        // Draw Bézier curve (for debug)
        if trajectory_type == 0 {
            rl.DrawLineBezier(bezier_curve.p0, bezier_curve.p1, 5, rl.RED)
            rl.DrawLineBezier(bezier_curve.p1, bezier_curve.p2, 5, rl.RED)
            rl.DrawLineBezier(bezier_curve.p2, bezier_curve.p3, 5, rl.RED)
            rl.DrawCircleV(bezier_curve.p0, 5, rl.GREEN)
            rl.DrawCircleV(bezier_curve.p1, 5, rl.BLUE)
            rl.DrawCircleV(bezier_curve.p2, 5, rl.BLUE)
            rl.DrawCircleV(bezier_curve.p3, 5, rl.GREEN)
        }
        // Draw text at calculated position
        rl.DrawText(
            text, 
            cast(i32)text_position.x, 
            cast(i32)text_position.y, 
            font_size, 
            text_color
        )
        // Change trajectory by pressing space
        if rl.IsKeyPressed(.SPACE) {
            trajectory_type = (trajectory_type + 1) % 2
        }
        rl.DrawText("Press SPACE to change trajectory", 10, 10, 20, rl.GRAY)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}