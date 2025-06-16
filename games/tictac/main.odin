package main

import "core:math"
import rl "vendor:raylib"

Player :: enum {
    None,
    X,
    O,
}

Board :: [3][3]Player
SIZE :: 3
LINE_THICKNESS :: 2
WIDTH :: 800 + LINE_THICKNESS
HEIGHT :: 800 + LINE_THICKNESS
CELL_SIZE :: (WIDTH - LINE_THICKNESS * 2) / SIZE

Game :: struct {
    board: Board,
    current_player: Player,
    is_over: bool,
    starting_player: Player,
    winner: Player,
}

State :: struct {
    x: int,
    y: int,
    board: Board,
}

other_player :: proc(player: Player) -> Player {
    if player == .X do return .O
    if player == .O do return .X
    return .None
}

new_game :: proc(starting_player: Player) -> Game {
    game := Game {
        current_player = starting_player,
        starting_player = starting_player,
        is_over = false,
        winner = .None,
    }
    return game
}

reset :: proc(game: ^Game) {
    game.board = {}  // Zero initialize the board
    game.current_player = game.starting_player
    game.is_over = false
    game.winner = .None
}

is_winner :: proc(board: Board, player: Player) -> bool {
    // Check rows
    for i in 0..<3 {
        if board[i][0] == player && board[i][1] == player && board[i][2] == player {
            return true
        }
    }
    // Check columns
    for i in 0..<3 {
        if board[0][i] == player && board[1][i] == player && board[2][i] == player {
            return true
        }
    }
    // Check diagonals
    if board[0][0] == player && board[1][1] == player && board[2][2] == player {
        return true
    }
    if board[0][2] == player && board[1][1] == player && board[2][0] == player {
        return true
    }
    return false
}

empty_spots :: proc(board: Board) -> int {
    count := 0
    for i in 0..<3 {
        for j in 0..<3 {
            if board[i][j] == .None {
                count += 1
            }
        }
    }
    return count
}

place :: proc(game: ^Game, x, y: int) -> bool {
    if x < 0 || x >= 3 || y < 0 || y >= 3 {
        return false
    }
    
    if game.board[x][y] != .None {
        return false
    }
    
    game.board[x][y] = game.current_player
    
    if is_winner(game.board, game.current_player) {
        game.winner = game.current_player
        game.is_over = true
    } else if empty_spots(game.board) == 0 {
        game.is_over = true
    } else {
        game.current_player = other_player(game.current_player)
    }
    
    return true
}

copy_board :: proc(src: Board) -> Board {
    dst: Board
    for i in 0..<3 {
        for j in 0..<3 {
            dst[i][j] = src[i][j]
        }
    }
    return dst
}

next_boards :: proc(board: Board, player: Player) -> [dynamic]State {
    boards := make([dynamic]State)
    
    for i in 0..<3 {
        for j in 0..<3 {
            if board[i][j] != .None {
                continue
            }
            
            new_board := copy_board(board)
            new_board[i][j] = player
            
            append(&boards, State{
                x = i,
                y = j,
                board = new_board,
            })
        }
    }
    
    return boards
}

min_int :: proc(a, b: int) -> int {
    return a < b ? a : b
}

max_int :: proc(a, b: int) -> int {
    return a > b ? a : b
}

// Value should only be called at leaf / terminal nodes (game MUST be over)
value :: proc(board: Board, ai_won: bool) -> int {
    spots := empty_spots(board)
    if ai_won {
        return max_int(1, spots)
    }
    return min_int(-1, -spots)
}

minimax :: proc(board: Board, ai, current: Player, alpha, beta: f64) -> int {
    other := other_player(current)
    
    if is_winner(board, other) {
        return value(board, ai == other)
    }
    
    // Draw is 0
    if empty_spots(board) == 0 {
        return 0
    }
    
    if current == ai {
        // Maximizing
        max_val := -math.INF_F64
        states := next_boards(board, current)
        defer delete(states)
        
        for state in states {
            val := f64(minimax(state.board, ai, other, alpha, beta))
            max_val = math.max(max_val, val)
            alpha_new := math.max(alpha, val)
            
            if alpha_new >= beta {
                break
            }
        }
        
        return int(max_val)
    } else {
        // Minimizing
        min_val := math.INF_F64
        states := next_boards(board, current)
        defer delete(states)
        
        for state in states {
            val := f64(minimax(state.board, ai, other, alpha, beta))
            min_val = math.min(min_val, val)
            beta_new := math.min(beta, val)
            
            if alpha >= beta_new {
                break
            }
        }
        
        return int(min_val)
    }
}

minimax_ai :: proc(ai: Player, game: ^Game) {
    max_val := -math.INF_F64
    best_state: State
    other := other_player(ai)
    
    states := next_boards(game.board, ai)
    defer delete(states)
    
    for state in states {
        val := f64(minimax(state.board, ai, other, -math.INF_F64, math.INF_F64))
        if val > max_val {
            max_val = val
            best_state = state
        }
    }
    
    place(game, best_state.x, best_state.y)
}

draw :: proc(game: ^Game) {
    rl.ClearBackground(rl.WHITE)
    
    // Draw grid lines
    rl.DrawRectangle(CELL_SIZE, 0, LINE_THICKNESS, HEIGHT, rl.BLACK)
    rl.DrawRectangle(CELL_SIZE * 2 + LINE_THICKNESS, 0, LINE_THICKNESS, HEIGHT, rl.BLACK)
    rl.DrawRectangle(0, CELL_SIZE, WIDTH, LINE_THICKNESS, rl.BLACK)
    rl.DrawRectangle(0, CELL_SIZE * 2 + LINE_THICKNESS, WIDTH, LINE_THICKNESS, rl.BLACK)
    
    // Draw X's and O's
    for i in 0..<3 {
        for j in 0..<3 {
            x := j * CELL_SIZE + CELL_SIZE / 2
            y := i * CELL_SIZE + CELL_SIZE / 2
            
            if game.board[i][j] == .X {
                // Draw X
                thickness := 5
                length := CELL_SIZE / 4
                rl.DrawLineEx(
                    {f32(x - length), f32(y - length)}, 
                    {f32(x + length), f32(y + length)}, 
                    f32(thickness), 
                    rl.RED,
                )
                rl.DrawLineEx(
                    {f32(x + length), f32(y - length)}, 
                    {f32(x - length), f32(y + length)}, 
                    f32(thickness), 
                    rl.RED,
                )
            } else if game.board[i][j] == .O {
                // Draw O
                rl.DrawCircleLines(i32(x), i32(y), CELL_SIZE / 4, rl.BLUE)
            }
        }
    }
    
    // Draw game over message
    if game.is_over {
        text: cstring
        if game.winner == .X {
            text = "X Wins!"
        } else if game.winner == .O {
            text = "O Wins!"
        } else {
            text = "Draw!"
        }
        
        font_size:i32 = 40
        text_width := rl.MeasureText(text, font_size)
        rl.DrawText(text, WIDTH / 2 - text_width / 2, HEIGHT / 2 - font_size / 2, font_size, rl.BLACK)
    }
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Tic Tac Toe")
    rl.SetTargetFPS(60)
    defer rl.CloseWindow()
    
    user := Player.O
    ai := Player.X
    g := new_game(ai)
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()        
        draw(&g)

        if !g.is_over {
            if rl.IsMouseButtonReleased(.LEFT) && g.current_player == user {
                mouse_pos := rl.GetMousePosition()
                i := int(mouse_pos.y) / CELL_SIZE
                j := int(mouse_pos.x) / CELL_SIZE
                
                place(&g, i, j)
            } else if g.current_player == ai {
                minimax_ai(ai, &g)
            }
        }
        rl.EndDrawing()
    }
}