package game

import rl "vendor:raylib"

Paddle :: struct {
    x, y: f32,
    width, height: f32,
    speed: f32,
}

paddle_limit_movement :: proc(using paddle: ^Paddle, screen_height: i32) {
    if y <= 0 {
        y = 0
    }
    if y + height >= f32(screen_height) {
        y = f32(screen_height) - height
    }
}

paddle_draw :: proc(using paddle: ^Paddle) {
    rl.DrawRectangleRounded({x, y, width, height}, 0.8, 0, rl.WHITE)
}

paddle_update :: proc(using paddle: ^Paddle, screen_height: i32) {
    if rl.IsKeyDown(.UP) {
        y -= f32(speed)
    }
    if rl.IsKeyDown(.DOWN) {
        y += f32(speed)
    }
    paddle_limit_movement(paddle, screen_height)
}

cpu_paddle_update :: proc(using paddle: ^Paddle, ball_y: f32, screen_height: i32) {
    if y + height / 2 > ball_y {
        y -= f32(speed)
    }
    if y + height / 2 <= ball_y {
        y += f32(speed)
    }
    paddle_limit_movement(paddle, screen_height)
}
