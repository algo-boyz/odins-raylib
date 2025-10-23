package main

import "core:math"
import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 450

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Tanks")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    box_a := rl.Rectangle{10, f32(HEIGHT) / 2 + 30, 200, 100}
    box_a_speed_x := 4

    mouse_pos, ball_pos, center_a, center_b, subtract,
    half_width_a, half_width_b: rl.Vector2
    center_v := rl.Vector2{f32(WIDTH) / 2, 100}
    ball_speed_x, ball_speed_y, min_dist_x, min_dist_y, angle_rad, angle_deg: f32
    cannon_length: f32 = 60
    turret_radius: f32 = 40
    ball_radius:   f32 =  8
    pause: bool

    for !rl.WindowShouldClose() {
        // Move box if unpaused
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
        min_dist_x = half_width_a.x + half_width_b.x - abs(subtract.x)
        min_dist_y = half_width_a.y + half_width_b.y - abs(subtract.y)

        // Check if collision occurs between ball & box
        if rl.CheckCollisionCircleRec(ball_pos, ball_radius, box_a) {
            if min_dist_x < min_dist_y { // Horizontal collision (left-right)
                ball_speed_x *= -1  // Reverse horizontal speed
                // Adjust ball position to prevent it getting stuck
                if subtract.x > 0 {
                    ball_pos.x += min_dist_x  // Ball is to the left of the box, move right
                } else {
                    ball_pos.x -= min_dist_x  // Ball is to the right of the box, move left
                }
            } else { // Vertical collision (top-bottom)
                ball_speed_y *= -1  // Reverse vertical speed
                if subtract.y > 0 {
                    ball_pos.y += min_dist_y  // Ball is below the box, move up
                } else {
                    ball_pos.y -= min_dist_y  // Ball is above the box, move down
                }
            }
        }
        // Bounce off wall
        if ball_pos.x >= f32(rl.GetScreenWidth()) - ball_radius || ball_pos.x <= ball_radius {
            ball_speed_x *= -1
        }
        if ball_pos.y >= f32(rl.GetScreenHeight()) - ball_radius || ball_pos.y <= ball_radius {
            ball_speed_y *= -1
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
            speed: f32 = 5
            ball_speed_x = math.cos(angle_rad) * speed
            ball_speed_y = math.sin(angle_rad) * speed
        }
        if ball_speed_x != 0 || ball_speed_y != 0 {
            ball_pos.x += ball_speed_x
            ball_pos.y += ball_speed_y
            rl.DrawCircleV(ball_pos, ball_radius, rl.RED)
        }
        // Draw cannon
        rl.DrawRectanglePro(
            rl.Rectangle{center_v.x, center_v.y, cannon_length, 20},
            rl.Vector2{0, 10},
            angle_deg,
            rl.GRAY,
        )
        rl.DrawRectangleRec(box_a, rl.GOLD)
        rl.DrawCircleV(center_v, turret_radius, rl.BLUE)

        rl.DrawText("Press SPACE to PAUSE/RESUME", 20, HEIGHT - 35, 20, rl.LIGHTGRAY)
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
}