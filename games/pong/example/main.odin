package main

import "core:fmt"
import rl "vendor:raylib"

import "../"

main :: proc() {
    screen_width  :: 800
    screen_height :: 600
    
    rl.InitWindow(screen_width, screen_height, "Pong")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    
    game_state := pong.init(screen_width, screen_height)
    
    for !rl.WindowShouldClose() {
        pong.update(&game_state)
rl.EndDrawing()
        rl.BeginDrawing()        
        rl.ClearBackground(pong.Dark_Green)
        
        pong.draw(game_state)

        rl.EndDrawing()
    }
}
