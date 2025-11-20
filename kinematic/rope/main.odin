package main

import rl "vendor:raylib"
import geom "../../rlutil/geom"

WIDTH :: 800
HEIGHT :: 600
POINTS :: 10
ROPE_LENGTH :: 25.0
GRAVITY :: 0.5
CONSTRAINT_ITERATIONS :: 10
SMOOTH_SEGMENTS_PER_CONTROL :: 8  // How many smooth segments between each control point
TOTAL_SMOOTH_POINTS :: (POINTS - 1) * SMOOTH_SEGMENTS_PER_CONTROL + 1

// Catmull-Rom spline interpolation
catmull_rom :: proc(p0, p1, p2, p3: rl.Vector2, t: f32) -> rl.Vector2 {
    t2 := t * t
    t3 := t2 * t
    
    x := 0.5 * ((2.0 * p1.x) +
        (-p0.x + p2.x) * t +
        (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 +
        (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3)
    
    y := 0.5 * ((2.0 * p1.y) +
        (-p0.y + p2.y) * t +
        (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 +
        (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3)
    
    return {x, y}
}

// Generate smooth curve points using Catmull-Rom splines
generate_smooth_rope :: proc(control_points: []rl.Vector2, smooth_points: []rl.Vector2, segments_per_control: int) {
    if len(control_points) < 2 do return
    
    smooth_index := 0
    
    for i in 0..<len(control_points)-1 {
        // Get control points for Catmull-Rom (need 4 points)
        p0 := control_points[max(0, i-1)]
        p1 := control_points[i]
        p2 := control_points[min(len(control_points)-1, i+1)]
        p3 := control_points[min(len(control_points)-1, i+2)]
        
        // Generate interpolated points
        for j in 0..<segments_per_control {
            if smooth_index >= len(smooth_points) do break
            
            t := f32(j) / f32(segments_per_control)
            smooth_points[smooth_index] = catmull_rom(p0, p1, p2, p3, t)
            smooth_index += 1
        }
    }
    
    // Add the last point
    if smooth_index < len(smooth_points) {
        smooth_points[smooth_index] = control_points[len(control_points)-1]
    }
}

main :: proc() {    
    rl.InitWindow(WIDTH, HEIGHT, "Rope Physics")
    rl.SetTargetFPS(60)
    
    // Init rope points
    rope_points: [POINTS]rl.Vector2
    rope_old_points: [POINTS]rl.Vector2
    smooth_rope_points: [TOTAL_SMOOTH_POINTS]rl.Vector2
    
    // Starting position (left side of screen)
    start_pos := rl.Vector2{f32(WIDTH) / 5.0, f32(HEIGHT) / 2.0}
    
    // Init rope segments
    for i in 0..<POINTS {
        rope_points[i] = start_pos + {f32(i) * ROPE_LENGTH, 0}
        rope_old_points[i] = rope_points[i]
    }
    
    // Circle properties
    circle_center := rl.Vector2{f32(WIDTH) / 2.0, f32(HEIGHT) / 2.0}
    circle_radius: f32 = 50.0
    
    // Ball properties
    ball_radius: f32 = 5.0
    
    // Mouse position
    mouse_pos := circle_center
    mouse_pressed := false
    
    for !rl.WindowShouldClose() {
        // Update mouse position and handle circle collision
        raw_mouse_pos := rl.GetMousePosition()
        mouse_pos = raw_mouse_pos
        // Keep mouse outside the circle
        if rl.Vector2Distance(mouse_pos, circle_center) <= circle_radius + 5 {
            mouse_pos = geom.vec2_set_distance(mouse_pos, circle_center, circle_radius + 5)
        }
        
        // Handle mouse input
        if rl.IsMouseButtonPressed(.LEFT) {
            mouse_pressed = true
        }
        if rl.IsMouseButtonReleased(.LEFT) {
            mouse_pressed = false
        }
        
        // Physics update
        
        // Verlet integration for all points except the first one
        for i in 1..<POINTS {
            geom.vec2_verlet_integrate(&rope_points[i], &rope_old_points[i])
            // Add gravity
            rope_points[i].y += GRAVITY
        }
        
        // Constraint solving (multiple iterations for stability)
        for iteration in 0..<CONSTRAINT_ITERATIONS {
            for i in 0..<POINTS-1 {
                segment := &rope_points[i]
                next_segment := &rope_points[i + 1]
                
                // Distance constraint between segments
                to_next := segment^ - next_segment^
                distance := rl.Vector2Length(to_next)
                
                if distance > ROPE_LENGTH {
                    to_next = geom.vec2_set_length(to_next, ROPE_LENGTH)
                    offset := (segment^ - next_segment^) - to_next
                    next_segment^ += offset * 0.5
                    segment^ -= offset * 0.5
                }
                
                // Set first segment to mouse position
                if i == 0 {
                    rope_points[0] = mouse_pos
                }
                
                // Long-distance constraint (optimization)
                max_distance := f32(i + 1) * ROPE_LENGTH
                if rl.Vector2Distance(next_segment^, mouse_pos) > max_distance {
                    next_segment^ = geom.vec2_set_distance(next_segment^, mouse_pos, max_distance)
                }
            }
        }
        
        // Handle collision with center circle
        for i in 1..<POINTS {
            segment := &rope_points[i]
            
            // Different radius for the last segment (ball)
            collision_radius := circle_radius + 5
            if i == POINTS - 1 {
                collision_radius = circle_radius + ball_radius + 7.5
            }
            
            if rl.Vector2Distance(segment^, circle_center) < collision_radius {
                segment^ = geom.vec2_set_distance(segment^, circle_center, collision_radius)
            }
        }
        
        // Generate smooth rope curve
        generate_smooth_rope(rope_points[:], smooth_rope_points[:], SMOOTH_SEGMENTS_PER_CONTROL)
        
        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw center circle
        rl.DrawCircleLines(i32(circle_center.x), i32(circle_center.y), circle_radius, rl.BLACK)
        
        // Draw smooth rope using the interpolated points
        rope_color := mouse_pressed ? rl.RED : rl.Color{228, 20, 27, 255}
        
        // Draw the smooth rope curve
        for i in 0..<TOTAL_SMOOTH_POINTS-1 {
            if rl.Vector2Distance(smooth_rope_points[i], {0, 0}) > 0 && 
               rl.Vector2Distance(smooth_rope_points[i+1], {0, 0}) > 0 {
                rl.DrawLineEx(smooth_rope_points[i], smooth_rope_points[i+1], 5.0, rope_color)
            }
        }
        
        // Draw control points (smaller, for reference)
        for i in 0..<POINTS {
            rl.DrawCircleV(rope_points[i], 2.0, rl.MAROON)
        }
        
        // Draw ball at the end of rope (use the actual physics point, not smooth)
        ball_pos := rope_points[POINTS - 1]
        rl.DrawCircleV(ball_pos, ball_radius, rl.BLACK)
        rl.DrawCircleLines(i32(ball_pos.x), i32(ball_pos.y), ball_radius + 5, rl.BLACK)
        
        // Draw mouse position (for debugging)
        rl.DrawCircleV(mouse_pos, 3.0, rl.BLUE)
        
        // Draw instructions
        rl.DrawText("Smooth Catmull-Rom spline rope", 10, 35, 16, rl.GRAY)
        
        rl.EndDrawing()
    }
    rl.CloseWindow()
}