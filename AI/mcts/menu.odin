package mcts

import rl "vendor:raylib"

draw_menu :: proc(game: ^Game) {
    rl.DrawText("Tic Tac Toe - 5 in a Row!", 150, 50, 30, rl.BLACK)
    
    // Main menu - choose game mode
    if game.state == .Menu {
        // Draw buttons
        human_vs_ai_button := rl.Rectangle{200, 150, 300, 60}
        ai_vs_ai_button := rl.Rectangle{200, 250, 300, 60}
        
        // Human vs AI
        rl.DrawRectangleRec(human_vs_ai_button, rl.LIGHTGRAY)
        rl.DrawRectangleLinesEx(human_vs_ai_button, 2, rl.BLACK)
        rl.DrawText("Human vs AI", 270, 170, 25, rl.BLACK)
        
        // AI vs AI
        rl.DrawRectangleRec(ai_vs_ai_button, rl.LIGHTGRAY)
        rl.DrawRectangleLinesEx(ai_vs_ai_button, 2, rl.BLACK)
        rl.DrawText("AI vs AI", 300, 270, 25, rl.BLACK)
        
        mouse_pos := rl.GetMousePosition()
        
        if rl.IsMouseButtonPressed(.LEFT) {
            if rl.CheckCollisionPointRec(mouse_pos, human_vs_ai_button) {
                // Set up Human vs AI and move to player selection screen
                game.mode = .Human_vs_AI
                game.current_player = nil
                reset_game(game)
                game.state = .Player_Selection
            } else if rl.CheckCollisionPointRec(mouse_pos, ai_vs_ai_button) {
                // Set up AI vs AI and start the game immediately
                game.player1.ai_flag = true
                game.player2.ai_flag = true
                game.player1.ai_type = .Minimax
                game.player2.ai_type = .MCTS
                game.player1.maximizing_player = true
                game.player2.maximizing_player = false
                game.current_player = &game.player1
                game.mode = .AI_vs_AI
                reset_game(game)
                game.state = .Playing
            }
        }
    } else if game.state == .Player_Selection {
        // Draw player selection buttons
        human_first_button := rl.Rectangle{150, 150, 180, 60}
        ai_first_button := rl.Rectangle{370, 150, 180, 60}
        
        rl.DrawText("Who goes first?", 270, 120, 25, rl.BLACK)
        
        rl.DrawRectangleRec(human_first_button, rl.LIGHTGRAY)
        rl.DrawRectangleLinesEx(human_first_button, 2, rl.BLACK)
        rl.DrawText("Human (X)", 180, 170, 25, rl.BLACK)
        
        rl.DrawRectangleRec(ai_first_button, rl.LIGHTGRAY)
        rl.DrawRectangleLinesEx(ai_first_button, 2, rl.BLACK)
        rl.DrawText("AI (X)", 420, 170, 25, rl.BLACK)
        
        // Add back button
        back_button := rl.Rectangle{50, 550, 150, 50}
        rl.DrawRectangleRec(back_button, rl.LIGHTGRAY)
        rl.DrawRectangleLinesEx(back_button, 2, rl.BLACK)
        rl.DrawText("Back", 90, 565, 20, rl.BLACK)
        
        mouse_pos := rl.GetMousePosition()
        
        if rl.IsMouseButtonPressed(.LEFT) {
            if rl.CheckCollisionPointRec(mouse_pos, human_first_button) {
                // Human first
                game.player1.ai_flag = false
                game.player1.character = 'x'
                game.player1.ai_type = .None
                game.player2.ai_flag = true
                game.player2.character = 'o'
                game.player2.ai_type = .None
                game.player2.maximizing_player = false
                game.current_player = &game.player1
                game.human_first = true
                game.state = .AI_Selection  // Move to AI selection next
            } else if rl.CheckCollisionPointRec(mouse_pos, ai_first_button) {
                // AI first
                game.player1.ai_flag = true
                game.player1.character = 'x'
                game.player1.ai_type = .None
                game.player1.maximizing_player = true
                game.player2.ai_flag = false
                game.player2.character = 'o'
                game.player2.ai_type = .None
                game.current_player = &game.player1
                game.human_first = false
                game.state = .AI_Selection
            } else if rl.CheckCollisionPointRec(mouse_pos, back_button) {
                game.state = .Menu
            }
        }
    } else if game.state == .AI_Selection {
        // Get reference to AI player
        ai_player := game.human_first ? &game.player2 : &game.player1
        
        // Draw AI type selection buttons
        minimax_button := rl.Rectangle{150, 250, 180, 60}
        mcts_button := rl.Rectangle{370, 250, 180, 60}
        
        rl.DrawText("Choose AI Type:", 270, 220, 25, rl.BLACK)
        
        rl.DrawRectangleRec(minimax_button, rl.LIGHTGRAY)
        rl.DrawRectangleLinesEx(minimax_button, 2, rl.BLACK)
        rl.DrawText("Minimax", 180, 270, 25, rl.BLACK)
        
        rl.DrawRectangleRec(mcts_button, rl.LIGHTGRAY)
        rl.DrawRectangleLinesEx(mcts_button, 2, rl.BLACK)
        rl.DrawText("MCTS", 420, 270, 25, rl.BLACK)
        
        // Add back button
        back_button := rl.Rectangle{50, 550, 150, 50}
        rl.DrawRectangleRec(back_button, rl.LIGHTGRAY)
        rl.DrawRectangleLinesEx(back_button, 2, rl.BLACK)
        rl.DrawText("Back", 90, 565, 20, rl.BLACK)
        
        mouse_pos := rl.GetMousePosition()
        
        if rl.IsMouseButtonPressed(.LEFT) {
            if rl.CheckCollisionPointRec(mouse_pos, minimax_button) {
                // Use Minimax AI
                ai_player.ai_type = .Minimax
                game.state = .Playing  // Start the game directly
            } else if rl.CheckCollisionPointRec(mouse_pos, mcts_button) {
                // Use MCTS AI
                ai_player.ai_type = .MCTS
                game.state = .Playing
            } else if rl.CheckCollisionPointRec(mouse_pos, back_button) {
                // Go back to
                game.state = .Player_Selection
            }
        }
    }
}
