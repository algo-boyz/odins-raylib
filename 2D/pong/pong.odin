package game

import "core:fmt"

import rl "vendor:raylib"

GameState :: struct {
    screen_width, screen_height: i32,
    ball: ^Ball,
    player_paddle: ^Paddle,
    cpu_paddle: ^Paddle,
    player_score, cpu_score: i32,
}

init :: proc(screen_width, screen_height: i32) -> GameState {
    ball := new(Ball)
    player_paddle := new(Paddle)
    cpu_paddle := new(Paddle)

    ball^ = Ball{
        x = f32(screen_width / 2),
        y = f32(screen_height / 2),
        speed_x = 7,
        speed_y = 7,
        radius = 20,
    }

    player_paddle^ = Paddle{
        x = f32(screen_width) - 25 - 10, 
        y = f32(screen_height) / 2 - 60,
        width = 25,
        height = 120,
        speed = 6,
    }

    cpu_paddle^ = Paddle{
        x = 10,
        y = f32(screen_height) / 2 - 60,
        width = 25,
        height = 120,
        speed = 6,
    }

    return GameState{
        screen_width = screen_width,
        screen_height = screen_height,
        ball = ball,
        player_paddle = player_paddle,
        cpu_paddle = cpu_paddle,
        player_score = 0,
        cpu_score = 0,
    }
}

update :: proc(using game_state: ^GameState) {
    paddle_update(player_paddle, screen_height)
    cpu_paddle_update(cpu_paddle, ball.y, screen_height)
    
    if ball_update(ball, screen_width, screen_height, &player_score, &cpu_score, player_paddle, cpu_paddle) {
        ball_reset(ball, screen_width, screen_height)
    }
}

draw :: proc(using game_state: GameState) {
    // Draw white circle in the middle
    rl.DrawCircle(screen_width / 2, screen_height / 2, 150, Light_Green)
    
    // Draw center line
    rl.DrawLineEx(
        {f32(screen_width/2), 0}, 
        {f32(screen_width/2), f32(screen_height)}, 
        3,  // Thickness
        rl.BEIGE
    )

    // Draw scores
    rl.DrawText(fmt.ctprintf("%d", player_score), screen_width/4, 20, 40, rl.WHITE)
    rl.DrawText(fmt.ctprintf("%d", cpu_score), 3*screen_width/4, 20, 40, rl.WHITE)
    
    // Draw game objects
    ball_draw(ball)
    paddle_draw(player_paddle)
    paddle_draw(cpu_paddle)
}