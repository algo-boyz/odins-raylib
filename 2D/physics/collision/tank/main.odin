package main

import "core:math"
import rl "vendor:raylib"

main :: proc() {
    screen_width :: 800
    screen_height :: 450
    rl.InitWindow(screen_width, screen_height, "Tanks")

    // Moving box
    box_a := rl.Rectangle{10, f32(screen_height) / 2.0 + 30, 200, 100}
    box_a_speed_x := 4

    turret_radius: f32 = 40
    ball_speed_x: f32 = 0.0
    ball_speed_y: f32 = 0.0
    ball_pos := rl.Vector2{0.0, 0.0}
    ball_radius: f32 = 8
    center_v := rl.Vector2{f32(screen_width) / 2, 100}
    angle_rad: f32
    angle_deg: f32
    cannon_length: f32 = 60.0
    pause := false

    center_a, center_b: rl.Vector2
    subtract: rl.Vector2
    half_width_a, half_width_b: rl.Vector2
    min_dist_x, min_dist_y: f32
    mouse_pos: rl.Vector2

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Move box if not paused
        if !pause {
            box_a.x += f32(box_a_speed_x)
        }
        // Bounce box on x screen limits
        if (box_a.x + box_a.width >= f32(rl.GetScreenWidth()) || box_a.x <= 0) {
            box_a_speed_x *= -1
        }

        center_a = rl.Vector2{box_a.x + box_a.width / 2, box_a.y + box_a.height / 2}
        center_b = rl.Vector2{ball_pos.x, ball_pos.y}
        subtract = center_a - center_b
        half_width_a = rl.Vector2{box_a.width * 0.5, box_a.height * 0.5}
        half_width_b = rl.Vector2{ball_radius * 0.5, ball_radius * 0.5}
        min_dist_x = half_width_a.x + half_width_b.x - math.abs(subtract.x)
        min_dist_y = half_width_a.y + half_width_b.y - math.abs(subtract.y)

        // Check if collision occurs between ball and box
        if rl.CheckCollisionCircleRec(ball_pos, ball_radius, box_a) {
            // If horizontal collision (left-right)
            if min_dist_x < min_dist_y {
                ball_speed_x *= -1.0  // Reverse horizontal speed
                // Adjust ball position to prevent it from getting stuck
                if subtract.x > 0 {
                    ball_pos.x += min_dist_x  // Ball is to the left of the box, move right
                } else {
                    ball_pos.x -= min_dist_x  // Ball is to the right of the box, move left
                }
            } else {
                // If vertical collision (top-bottom)
                ball_speed_y *= -1.0  // Reverse vertical speed
                // Adjust ball position to prevent it from getting stuck
                if subtract.y > 0 {
                    ball_pos.y += min_dist_y  // Ball is below the box, move up
                } else {
                    ball_pos.y -= min_dist_y  // Ball is above the box, move down
                }
            }
        }
        // Bounce off walls
        if ball_pos.x >= f32(rl.GetScreenWidth()) - ball_radius || ball_pos.x <= ball_radius {
            ball_speed_x *= -1.0
        }
        if ball_pos.y >= f32(rl.GetScreenHeight()) - ball_radius || ball_pos.y <= ball_radius {
            ball_speed_y *= -1.0
        }
        // Pause Box A movement
        if rl.IsKeyPressed(.SPACE) {
            pause = !pause
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        mouse_pos = rl.GetMousePosition()
        angle_rad = math.atan2(mouse_pos.y - center_v.y, mouse_pos.x - center_v.x)
        angle_deg = angle_rad * (180 / math.PI)  // Convert to degrees

        if rl.IsMouseButtonDown(.LEFT) {
            // Fire cannon
            ball_pos = center_v
            speed: f32 = 5.0
            ball_speed_x = math.cos(angle_rad) * speed
            ball_speed_y = math.sin(angle_rad) * speed
        }
        if ball_speed_x != 0 || ball_speed_y != 0 {
            ball_pos.x += ball_speed_x
            ball_pos.y += ball_speed_y
            rl.DrawCircleV(ball_pos, ball_radius, rl.RED)
        }
        // Draw the cannon
        rl.DrawRectanglePro(
            rl.Rectangle{center_v.x, center_v.y, cannon_length, 20},
            rl.Vector2{0, 10},
            angle_deg,
            rl.GRAY,
        )
        rl.DrawRectangleRec(box_a, rl.GOLD)
        rl.DrawCircleV(center_v, turret_radius, rl.BLUE)

        rl.DrawText("Press SPACE to PAUSE/RESUME", 20, screen_height - 35, 20, rl.LIGHTGRAY)
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}