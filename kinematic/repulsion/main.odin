package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Simulation Constants
WIDTH :: 800
HEIGHT :: 600
BALL_COUNT   :: 300
MOUSE_RADIUS :: 50.0 
BALL_RADIUS  :: 10.0
BOUNCE_FACTOR :: 0.6 // How bouncy collisions are. 0.0 = no bounce, 1.0 = full bounce.

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Bouncy Ball Repulsion")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    balls_positions := make([dynamic]rl.Vector2)
    defer delete(balls_positions)

    view_center := rl.Vector2{f32(WIDTH) / 2, f32(HEIGHT) / 2}

    for i in 0..<BALL_COUNT {
        random_offset := rl.Vector2{
            (rand.float32() * 100) - 50,
            (rand.float32() * 100) - 50,
        }
        append(&balls_positions, view_center + random_offset)
    }

    for !rl.WindowShouldClose() {
        mouse_pos := rl.GetMousePosition()

        // 1. Separate the balls from the mouse
        separation_from_mouse := MOUSE_RADIUS + BALL_RADIUS
        
        for i in 0..<BALL_COUNT {
            to_mouse := mouse_pos - balls_positions[i]
            dist_sqr := rl.Vector2LengthSqr(to_mouse)

            if dist_sqr > 0 && dist_sqr < f32(separation_from_mouse * separation_from_mouse) {
                dist := math.sqrt(dist_sqr)
                
                // How much the ball has overlapped into the mouse's radius
                overlap := f32(separation_from_mouse) - dist
                
                // The direction to move is away from the mouse
                move_direction := to_mouse * (-1.0 / dist) // Normalized direction

                // Add the bounce factor to push it away with extra energy
                correction_amount := overlap * (1 + BOUNCE_FACTOR)
                balls_positions[i] += move_direction * correction_amount
            }
        }

        // 2. Separate the balls from each other
        min_separation_between_balls := BALL_RADIUS * 2
        
        for i in 0..<BALL_COUNT {
            for j in (i + 1)..<BALL_COUNT {
                ball_a := &balls_positions[i]
                ball_b := &balls_positions[j]
                
                to_next := ball_b^ - ball_a^
                dist_sqr := rl.Vector2LengthSqr(to_next)

                if dist_sqr > 0 && dist_sqr < f32(min_separation_between_balls * min_separation_between_balls) {
                    dist := math.sqrt(dist_sqr)

                    // The total distance they overlap
                    overlap := f32(min_separation_between_balls) - dist

                    // The direction of the collision
                    move_direction := to_next * (1.0 / dist)

                    // Calculate the correction for each ball, including the bounce
                    // We divide the total correction by 2 to apply to each ball
                    correction_per_ball := (overlap / 2) * (1 + BOUNCE_FACTOR)
                    
                    // Apply the correction to move the balls apart
                    balls_positions[i] -= move_direction * correction_per_ball
                    balls_positions[j] += move_direction * correction_per_ball
                }
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        rl.DrawCircleLines(i32(mouse_pos.x), i32(mouse_pos.y), MOUSE_RADIUS, rl.DARKGRAY)

        for ball_pos in balls_positions {
            rl.DrawCircleV(ball_pos, BALL_RADIUS, rl.BLACK)
        }
        
        rl.EndDrawing()
    }
}