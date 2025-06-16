package mcts

import rl "vendor:raylib"

Tile :: struct {
    position: rl.Vector2,
    status: rune,          // ' ', 'x', or 'o'
}

Board :: struct {
    tiles: [BOARD_DIM][BOARD_DIM]Tile,
    offset: rl.Vector2, // board position offset
}

// Initialize a new board
init_board :: proc() -> Board {
    board := Board{
        offset = {100, 100},
    }
    // Init tiles
    for row in 0..<BOARD_DIM {
        for col in 0..<BOARD_DIM {
            board.tiles[row][col] = {
                position = {f32(row * TILE_SIZE), f32(col * TILE_SIZE)},
                status = ' ',
            }
        }
    }
    return board
}

// Clone a board
clone_board :: proc(board: ^Board) -> Board {
    new_board := Board{
        offset = board.offset,
    }
    for row in 0..<BOARD_DIM {
        for col in 0..<BOARD_DIM {
            new_board.tiles[row][col] = board.tiles[row][col]
        }
    }
    return new_board
}

// Draw the board
draw_board :: proc(board: ^Board) {
    for row in 0..<BOARD_DIM {
        for col in 0..<BOARD_DIM {
            tile := &board.tiles[row][col]
            x := i32(tile.position.x + board.offset.x)
            y := i32(tile.position.y + board.offset.y)
            // Draw tile
            rl.DrawRectangle(x, y, TILE_SIZE, TILE_SIZE, rl.WHITE)
            rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.BLACK)
            // Draw X or O
            if tile.status == 'x' {
                rl.DrawText("X", x + TILE_SIZE/3, y + TILE_SIZE/4, 50, rl.RED)
            } else if tile.status == 'o' {
                rl.DrawText("O", x + TILE_SIZE/3, y + TILE_SIZE/4, 50, rl.BLUE)
            }
        }
    }
}

evaluate_board :: proc(player: ^Player, board: ^Board) -> int {
    // Check for win/loss
    winner := check_winner(board)
    if winner == player.character {
        return 100
    } else if winner != ' ' {
        return -100
    } else if check_draw(board) {
        return 0
    }
    score := 0
    player_char := player.character
    opponent_char := rune(player_char == 'x' ? 'o' : 'x')
    
    // Check for potential wins
    for row in 0..<BOARD_DIM {
        player_count, opponent_count := 0, 0
        for col in 0..<BOARD_DIM {
            if board.tiles[row][col].status == player_char {
                player_count += 1
            } else if board.tiles[row][col].status == opponent_char {
                opponent_count += 1
            }
        }
        if opponent_count == 0 {
            score += player_count * 2
        } else if player_count == 0 {
            score -= opponent_count * 2
        }
    }
    // Columns
    for col in 0..<BOARD_DIM {
        player_count, opponent_count := 0, 0
        for row in 0..<BOARD_DIM {
            if board.tiles[row][col].status == player_char {
                player_count += 1
            } else if board.tiles[row][col].status == opponent_char {
                opponent_count += 1
            }
        }
        if opponent_count == 0 {
            score += player_count * 2
        } else if player_count == 0 {
            score -= opponent_count * 2
        }
    }
    return score
}

// Check if a player has won
check_winner :: proc(board: ^Board) -> rune {
    // Check rows
    for row in 0..<BOARD_DIM {
        first := board.tiles[row][0].status
        if first == ' ' do continue
        match := true
        for col in 1..<BOARD_DIM {
            if board.tiles[row][col].status != first {
                match = false
                break
            }
        }
        if match do return first
    }
    
    // Check columns
    for col in 0..<BOARD_DIM {
        first := board.tiles[0][col].status
        if first == ' ' do continue
        match := true
        for row in 1..<BOARD_DIM {
            if board.tiles[row][col].status != first {
                match = false
                break
            }
        }
        if match do return first
    }
    
    // Check diagonal (top-left to bottom-right)
    {
        first := board.tiles[0][0].status
        if first != ' ' {
            match := true
            for i in 1..<BOARD_DIM {
                if board.tiles[i][i].status != first {
                    match = false
                    break
                }
            }
            if match do return first
        }
    }
    
    // Check diagonal (bottom-left to top-right)
    {
        first := board.tiles[BOARD_DIM-1][0].status
        if first != ' ' {
            match := true
            for i in 1..<BOARD_DIM {
                if board.tiles[BOARD_DIM-1-i][i].status != first {
                    match = false
                    break
                }
            }
            if match do return first
        }
    }
    
    return ' '
}

// Check if the game is a draw
check_draw :: proc(board: ^Board) -> bool {
    for row in 0..<BOARD_DIM {
        for col in 0..<BOARD_DIM {
            if board.tiles[row][col].status == ' ' {
                return false
            }
        }
    }
    return true
}

// Get tile from mouse position
get_tile_from_mouse :: proc(board: ^Board, mouse_pos: rl.Vector2) -> (row, col: int, clicked: bool) {
    for r in 0..<BOARD_DIM {
        for c in 0..<BOARD_DIM {
            tile := &board.tiles[r][c]
            rect := rl.Rectangle{
                tile.position.x + board.offset.x,
                tile.position.y + board.offset.y,
                f32(TILE_SIZE),
                f32(TILE_SIZE),
            }
            if rl.CheckCollisionPointRec(mouse_pos, rect) {
                return r, c, true
            }
        }
    }
    return -1, -1, false
}