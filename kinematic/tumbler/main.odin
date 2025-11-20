package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

import geom "../../rlutil/geom"

NUM_BALLS :: 30
MOUSE_REPEL_DISTANCE :: 50.0
BALL_SEPARATION_DISTANCE :: 20.0
DOMAIN_RADIUS :: 150.0
BALL_RADIUS :: 5.0
MOUSE_CIRCLE_RADIUS :: 50.0
CONSTRAINT_ITERATIONS :: 5
GRAVITY_STRENGTH :: 1.0

// Ball structure
Ball :: struct {
    position:     rl.Vector2,
    prev_position: rl.Vector2,
}

// Verlet integration
verlet_integrate :: proc(ball: ^Ball, delta_time: f32) {
    temp := ball.position
    ball.position = ball.position + (ball.position - ball.prev_position)
    ball.prev_position = temp
}

// Init a ball at random position within a range
init_ball :: proc(center: rl.Vector2) -> Ball {
    random_offset := rl.Vector2{
        (rand.float32() * 100.0) - 50.0,
        (rand.float32() * 100.0) - 50.0,
    }
    pos := center + random_offset
    return Ball{
        position = pos,
        prev_position = pos,
    }
}

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 600
    
    rl.InitWindow(WIDTH, HEIGHT, "Particle Physics System")
    rl.SetTargetFPS(60)
    
    // Init center point
    center := rl.Vector2{f32(WIDTH) / 2.0, f32(HEIGHT) / 2.0}
    
    // Init balls
    balls: [NUM_BALLS]Ball
    for i in 0..<NUM_BALLS {
        balls[i] = init_ball(center)
    }
    
    // Mouse position
    mouse_pos := center
    for !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        
        // Update mouse position
        mouse_pos = rl.GetMousePosition()
        
        // Physics update
        
        // Verlet integration and gravity
        for i in 0..<NUM_BALLS {
            ball := &balls[i]
            verlet_integrate(ball, delta_time)
            
            // Add gravity (clamped to reasonable value)
            gravity := min(GRAVITY_STRENGTH, delta_time * 30.0)
            ball.position.y += gravity
        }
        
        // Constraint solving
        for iteration in 0..<CONSTRAINT_ITERATIONS {
            
            // Separate balls from mouse cursor
            for i in 0..<NUM_BALLS {
                ball := &balls[i]
                to_ball := ball.position - mouse_pos
                distance := rl.Vector2Length(to_ball)
                
                min_distance :: MOUSE_REPEL_DISTANCE + BALL_RADIUS
                if distance < min_distance && distance > 0.0 {
                    to_ball = geom.vec2_set_length(to_ball, min_distance)
                    offset := (ball.position - mouse_pos) - to_ball
                    ball.position -= offset
                }
            }
            
            // Separate balls from each other
            for i in 0..<NUM_BALLS {
                for j in i+1..<NUM_BALLS {
                    ball_a := &balls[i]
                    ball_b := &balls[j]
                    
                    to_b := ball_b.position - ball_a.position
                    distance := rl.Vector2Length(to_b)
                    
                    if distance < BALL_SEPARATION_DISTANCE && distance > 0 {
                        to_b = geom.vec2_set_length(to_b, BALL_SEPARATION_DISTANCE)
                        offset := (ball_b.position - ball_a.position) - to_b
                        ball_a.position += offset * 0.5
                        ball_b.position -= offset * 0.5
                    }
                }
            }
            
            // Keep balls inside the domain
            for i in 0..<NUM_BALLS {
                ball := &balls[i]
                to_center := ball.position - center
                distance := rl.Vector2Length(to_center)
                
                max_distance :: DOMAIN_RADIUS - BALL_RADIUS
                if distance > max_distance {
                    to_center = geom.vec2_set_length(to_center, max_distance)
                    ball.position = center + to_center
                }
            }
        }
        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw domain circle (outer boundary)
        rl.DrawCircleLines(i32(center.x), i32(center.y), DOMAIN_RADIUS, rl.BLACK)
        
        // Draw mouse repulsion circle
        rl.DrawCircleV(mouse_pos, MOUSE_REPEL_DISTANCE, rl.Color{200, 200, 200, 100})
        rl.DrawCircleLines(i32(mouse_pos.x), i32(mouse_pos.y), MOUSE_REPEL_DISTANCE, rl.DARKGRAY)
        
        // Draw balls
        for i in 0..<NUM_BALLS {
            ball := balls[i]
            
            // Draw ball body
            rl.DrawCircleV(ball.position, BALL_RADIUS, rl.BLACK)
            
            // Draw ball outline
            rl.DrawCircleLines(i32(ball.position.x), i32(ball.position.y), BALL_RADIUS + 5, rl.BLACK)
        }
        // Draw mouse cursor
        rl.DrawCircleV(mouse_pos, 3.0, rl.RED)
        
        // Draw instructions
        rl.DrawText("Move mouse to repel particles", 10, 10, 20, rl.DARKGRAY)
        rl.DrawText("Particles separate from each other and stay in domain", 10, 35, 16, rl.GRAY)
        rl.DrawText(fmt.ctprintf("Particles: %d", NUM_BALLS), 10, 55, 16, rl.GRAY)
        
        // Draw performance info
        rl.DrawText(fmt.ctprintf("FPS: %d", rl.GetFPS()), WIDTH - 100, 10, 16, rl.DARKGRAY)
        
        rl.EndDrawing()
    }
    rl.CloseWindow()
}