package main

import rl "vendor:raylib"
import "../"


main :: proc() {
    rl.InitWindow(700, 700, "Tic Tac Toe")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    game := mcts.init_game()
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        if game.state == .Menu || game.state == .Player_Selection || game.state == .AI_Selection {
            mcts.draw_menu(&game)
        } else {
            mcts.update_game(&game, rl.GetFrameTime())
        }
        rl.EndDrawing()
    }
}