package main

import "core:fmt"
import rl "vendor:raylib"

import "../"

main :: proc() {
    WIDTH  :: 800
    HEIGHT :: 600
    
    rl.InitWindow(WIDTH, HEIGHT, "Pong")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    
    game_state := pong.init(WIDTH, HEIGHT)
    
    for !rl.WindowShouldClose() {
        pong.update(&game_state)
rl.EndDrawing()
        rl.BeginDrawing()        
        rl.ClearBackground(pong.Dark_Green)
        
        pong.draw(game_state)

        rl.EndDrawing()
    }
}
