package game

import "core:fmt"

import rl "vendor:raylib"

GameState :: struct {
    WIDTH, HEIGHT: i32,
    ball: ^Ball,
    player_paddle: ^Paddle,
    cpu_paddle: ^Paddle,
    player_score, cpu_score: i32,
}

init :: proc(WIDTH, HEIGHT: i32) -> GameState {
    ball := new(Ball)
    player_paddle := new(Paddle)
    cpu_paddle := new(Paddle)

    ball^ = Ball{
        x = f32(WIDTH / 2),
        y = f32(HEIGHT / 2),
        speed_x = 7,
        speed_y = 7,
        radius = 20,
    }

    player_paddle^ = Paddle{
        x = f32(WIDTH) - 25 - 10, 
        y = f32(HEIGHT) / 2 - 60,
        width = 25,
        height = 120,
        speed = 6,
    }

    cpu_paddle^ = Paddle{
        x = 10,
        y = f32(HEIGHT) / 2 - 60,
        width = 25,
        height = 120,
        speed = 6,
    }

    return GameState{
        WIDTH = WIDTH,
        HEIGHT = HEIGHT,
        ball = ball,
        player_paddle = player_paddle,
        cpu_paddle = cpu_paddle,
        player_score = 0,
        cpu_score = 0,
    }
}

update :: proc(using game_state: ^GameState) {
    paddle_update(player_paddle, HEIGHT)
    cpu_paddle_update(cpu_paddle, ball.y, HEIGHT)
    
    if ball_update(ball, WIDTH, HEIGHT, &player_score, &cpu_score, player_paddle, cpu_paddle) {
        ball_reset(ball, WIDTH, HEIGHT)
    }
}

draw :: proc(using game_state: GameState) {
    // Draw white circle in the middle
    rl.DrawCircle(WIDTH / 2, HEIGHT / 2, 150, Light_Green)
    
    // Draw center line
    rl.DrawLineEx(
        {f32(WIDTH/2), 0}, 
        {f32(WIDTH/2), f32(HEIGHT)}, 
        3,  // Thickness
        rl.BEIGE
    )

    // Draw scores
    rl.DrawText(fmt.ctprintf("%d", player_score), WIDTH/4, 20, 40, rl.WHITE)
    rl.DrawText(fmt.ctprintf("%d", cpu_score), 3*WIDTH/4, 20, 40, rl.WHITE)
    
    // Draw game objects
    ball_draw(ball)
    paddle_draw(player_paddle)
    paddle_draw(cpu_paddle)
}