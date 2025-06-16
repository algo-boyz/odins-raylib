package mcts

minimax :: proc(player: ^Player, board: ^Board, depth: int, alpha, beta: int, is_maximizing: bool, boards_searched: ^uint) -> AiMove {
    boards_searched^ += 1
    
    // Terminal conditions
    winner := check_winner(board)
    if winner == player.character {
        return AiMove{-1, -1, 100}
    } else if winner != ' ' {
        return AiMove{-1, -1, -100}
    } else if check_draw(board) || depth == 0 {
        return AiMove{-1, -1, evaluate_board(player, board)}
    }
    
    if is_maximizing {
        best_move := AiMove{-1, -1, -1000}
        
        for row in 0..<BOARD_DIM {
            for col in 0..<BOARD_DIM {
                if board.tiles[row][col].status == ' ' {
                    // Try move
                    board.tiles[row][col].status = player.character
                    // Evaluate
                    move := minimax(player, board, depth - 1, alpha, beta, false, boards_searched)
                    // Undo
                    board.tiles[row][col].status = ' '
                    
                    // Update best move
                    if move.score > best_move.score {
                        best_move = AiMove{row, col, move.score}
                    }
                    // Alpha-beta pruning
                    if beta <= max(alpha, best_move.score) {
                        break
                    }
                }
            }
        }
        return best_move
    } else {
        best_move := AiMove{-1, -1, 1000}
        opponent_char := rune(player.character == 'x' ? 'o' : 'x')
        
        for row in 0..<BOARD_DIM {
            for col in 0..<BOARD_DIM {
                if board.tiles[row][col].status == ' ' {
                    // Try move
                    board.tiles[row][col].status = opponent_char
                    // Evaluate
                    move := minimax(player, board, depth - 1, alpha, beta, true, boards_searched)
                    // Undo
                    board.tiles[row][col].status = ' '
                    
                    // Update best move
                    if move.score < best_move.score {
                        best_move = AiMove{row, col, move.score}
                    }
                    // Alpha-beta pruning
                    if min(beta, best_move.score) <= alpha {
                        break
                    }
                }
            }
        }
        return best_move
    }
}