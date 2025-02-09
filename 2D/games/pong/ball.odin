package game

import "core:math/rand"
import rl "vendor:raylib"

Ball :: struct {
    x, y: f32,
    speed_x, speed_y: i32,
    radius: i32,
}

ball_draw :: proc(using ball: ^Ball) {
    rl.DrawCircle(i32(x), i32(y), f32(radius), Yellow)
}

ball_update :: proc(using ball: ^Ball, screen_width, screen_height: i32, player_score, cpu_score: ^i32, 
    player_paddle, cpu_paddle: ^Paddle) -> bool {
    x += f32(speed_x)
    y += f32(speed_y)

    reset_required := false

    // Wall collisions
    if y + f32(radius) >= f32(screen_height) || y - f32(radius) <= 0 {
        speed_y *= -1
    }

    // Paddle collisions
    player_rect := rl.Rectangle{
        player_paddle.x, 
        player_paddle.y, 
        player_paddle.width, 
        player_paddle.height
    }

    cpu_rect := rl.Rectangle{
        cpu_paddle.x, 
        cpu_paddle.y, 
        cpu_paddle.width, 
        cpu_paddle.height
    }

    // if rl.CheckCollisionCircleRec({x, y}, f32(radius), player_rect) ||
    // rl.CheckCollisionCircleRec({x, y}, f32(radius), cpu_rect) {
    //     speed_x *= -1
    // }

    if rl.CheckCollisionCircleRec({x, y}, f32(radius), player_rect) {
        speed_x = -abs(speed_x)  // Ensure it moves away from the paddle
        x = player_paddle.x - f32(radius) - 1  // Small offset to prevent sticking
    }
    
    if rl.CheckCollisionCircleRec({x, y}, f32(radius), cpu_rect) {
        speed_x = abs(speed_x)  // Ensure it moves away from the paddle
        x = cpu_paddle.x + cpu_paddle.width + f32(radius) + 1  // Small offset
    }

    // Scoring
    if x + f32(radius) >= f32(screen_width) {
        cpu_score^ += 1
        reset_required = true
    }

    if x - f32(radius) <= 0 {
        player_score^ += 1
        reset_required = true
    }

    return reset_required
}

ball_reset :: proc(using ball: ^Ball, screen_width, screen_height: i32) {
    x = f32(screen_width / 2)
    y = f32(screen_height / 2)
    speed_choices := []int{-1, 1}
    speed_x *= i32(speed_choices[rand.int_max(2)])
    speed_y *= i32(speed_choices[rand.int_max(2)])
}
