package mcts

import "core:fmt"
import "core:math"
import "core:time"
import rl "vendor:raylib"

BOARD_DIM :: 5
TILE_SIZE :: 100
MAX_ITER :: 10000

Player :: struct {
    character: rune,
    ai_flag: bool,
    ai_type: AI_Type,
    maximizing_player: bool,
}

AiMove :: struct {
    row, column, score: int,
}

AI_Type :: enum {
    None,
    Minimax,
    MCTS,
}

Game_Mode :: enum {
    Human_vs_AI,
    AI_vs_AI,
}

Game_State :: enum {
    Menu,
    Player_Selection,
    AI_Selection,
    Playing,
    Win,
    Draw,
}

Game :: struct {
    player1, player2: Player,
    current_player: ^Player,
    board: Board,
    mode: Game_Mode,
    state: Game_State,
    time_since_last_move: f32,
    winner: ^Player,
    total_turns: int,
    boards_searched: uint,
    human_first: bool,
    mcts: MCTS,
}

init_game :: proc() -> Game {
    return Game{
        player1 = {character = 'x', ai_flag = false, ai_type = .None, maximizing_player = true},
        player2 = {character = 'o', ai_flag = true, ai_type = .Minimax, maximizing_player = false},
        current_player = nil,
        board = init_board(),
        state = .Menu,
        time_since_last_move = 0,
        winner = nil,
        total_turns = 0,
        boards_searched = 0,
        human_first = true,
        mcts = MCTS{
            max_iter = 1000,
            max_time = 1 * time.Second,
        },
    }
}

reset_game :: proc(g: ^Game) {
    for row in 0..<BOARD_DIM {
        for col in 0..<BOARD_DIM {
            g.board.tiles[row][col].status = ' '
        }
    }
    g.state = .Playing
    g.total_turns = 0
    g.winner = nil
    g.boards_searched = 0
    g.time_since_last_move = 0
    g.mcts.nodes_searched = 0
}

get_human_player :: proc(g: ^Game) -> ^Player {
    if !g.player1.ai_flag do return &g.player1
    return &g.player2
}

get_ai_player :: proc(g: ^Game) -> ^Player {
    if g.player1.ai_flag do return &g.player1
    return &g.player2
}

next_player :: proc(current: rune) -> rune {
    return current == 'x' ? 'o' : 'x'
}

update_game :: proc(g: ^Game, dt: f32) {
    draw_board(&g.board)
    current_player_text := fmt.ctprintf("Current Player: %c", g.current_player.character)
    rl.DrawText(current_player_text, 50, 600, 20, rl.BLACK)
    if g.state == .Playing {
        winner := check_winner(&g.board)
        if winner != ' ' {
            g.state = .Win
            g.winner = winner == 'x' ? &g.player1 : &g.player2
        } else if check_draw(&g.board) {
            g.state = .Draw
        }
    }
    // Display game over msg
    if g.state == .Win {
        winner_text := fmt.ctprintf("The winner is: Player %c", g.winner.character)
        rl.DrawText(winner_text, 50, 400, 30, rl.BLACK)
        rl.DrawText("Press ENTER to return to menu", 50, 450, 20, rl.BLACK)
        if rl.IsKeyPressed(.ENTER) {
            reset_game(g)
            g.state = .Menu
            g.current_player = nil
        }
        return
    } else if g.state == .Draw {
        rl.DrawText("Game ended in a tie!", 50, 400, 30, rl.BLACK)
        rl.DrawText("Press ENTER to return to menu", 50, 450, 20, rl.BLACK)
        if rl.IsKeyPressed(.ENTER) {
            reset_game(g)
            g.state = .Menu
            g.current_player = nil
        }
        return
    }
    if g.mode == .Human_vs_AI {
        human_player := get_human_player(g)
        ai_player := get_ai_player(g)
        if g.current_player == human_player {
            rl.DrawText("Your turn - Click on a tile to make your move", 50, 550, 20, rl.BLACK)
            mouse_pos := rl.GetMousePosition()
            if rl.IsMouseButtonPressed(.LEFT) {
                row, col, clicked := get_tile_from_mouse(&g.board, mouse_pos)
                if clicked && row >= 0 && col >= 0 && row < BOARD_DIM && col < BOARD_DIM {
                    if g.board.tiles[row][col].status == ' ' {
                        // Make move
                        g.board.tiles[row][col].status = human_player.character
                        // Switch to AI player
                        g.current_player = ai_player
                    }
                }
            }
            // Highlight hovered tile
            row, col, hovered := get_tile_from_mouse(&g.board, mouse_pos)
            if hovered && row >= 0 && col >= 0 && row < BOARD_DIM && col < BOARD_DIM {
                if g.board.tiles[row][col].status == ' ' {
                    x := i32(g.board.tiles[row][col].position.x + g.board.offset.x)
                    y := i32(g.board.tiles[row][col].position.y + g.board.offset.y)
                    highlight_color := rl.ColorAlpha(rl.GREEN, 0.3)
                    rl.DrawRectangle(x, y, TILE_SIZE, TILE_SIZE, highlight_color)
                }
            }
            // Display AI stats
            boards_searched_text := fmt.ctprintf("AI's Boards Searched: %d", g.boards_searched)
            rl.DrawText(boards_searched_text, 50, 650, 16, rl.BLACK)
        } else {
            rl.DrawText("AI is thinking...", 50, 550, 20, rl.BLACK)
            // Small delay before AI move
            g.time_since_last_move += dt
            if g.time_since_last_move > 0.5 {  // half second delay
                g.time_since_last_move = 0
                // Use minimax to find best move
                g.boards_searched = 0
                move: AiMove
                if g.total_turns < 2 {  
                    // first couple of moves do
                    move = ai_opening_move(&g.board)
                } else {
                    move = minimax(ai_player, &g.board, 3, -1000, 1000, true, &g.boards_searched)
                }
                if g.board.tiles[move.row][move.column].status == ' ' {
                    // Make move
                    g.board.tiles[move.row][move.column].status = ai_player.character
                    // Switch to human player
                    g.current_player = human_player
                }
            }
        }
    } else if g.mode == .AI_vs_AI {
        current_bot_text := fmt.ctprintf("Bot %c is thinking...", g.current_player.character)
        rl.DrawText(current_bot_text, 50, 550, 20, rl.BLACK)
        // Add some delay between AI moves
        g.time_since_last_move += dt
        if g.time_since_last_move > 1.0 {  // 1 second delay
            g.time_since_last_move = 0
            g.total_turns += 1
            g.boards_searched = 0
            move: AiMove
            if g.current_player.ai_type == .MCTS {
                move = mcts_find_move(g, g.current_player)
            } else {
                if g.total_turns < 2 {  // For the first couple of moves
                    move = ai_opening_move(&g.board)
                } else {
                    move = minimax(g.current_player, &g.board, 3, -1000, 1000, true, &g.boards_searched)
                }
            }
            if g.board.tiles[move.row][move.column].status == ' ' {
                // Make move
                g.board.tiles[move.row][move.column].status = g.current_player.character
                // Switch players
                g.current_player = g.current_player == &g.player1 ? &g.player2 : &g.player1
            }
        }
        // Display search stats
        boards_searched_text := fmt.ctprintf("Boards searched: %d", g.boards_searched)
        rl.DrawText(boards_searched_text, 50, 650, 16, rl.BLACK)
    }
}

ai_opening_move :: proc(board: ^Board) -> AiMove {
    // Create list of all empty positions
    valid_moves: [dynamic]AiMove
    defer delete(valid_moves)
    for row in 0..<BOARD_DIM {
        for col in 0..<BOARD_DIM {
            if board.tiles[row][col].status == ' ' {
                append(&valid_moves, AiMove{row = row, column = col})
            }
        }
    }
    // Select random move from valid moves
    if len(valid_moves) > 0 {
        random_index := int(rl.GetRandomValue(0, i32(len(valid_moves) - 1)))
        return valid_moves[random_index]
    }
    // Fallback (should never happen)
    return AiMove{row = 0, column = 0}
}