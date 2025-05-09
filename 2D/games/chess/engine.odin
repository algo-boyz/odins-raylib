package chess

import "core:fmt"
import "core:math"
import "dyn"

// AI player structure
AI :: struct {
    engine: Engine,
    search_depth: int,
}

// Create a new AI player
new_ai :: proc(depth: int = SEARCH_DEPTH) -> ^AI {
    ai := new(AI)
    ai.search_depth = depth
    return ai
}

Engine :: struct {
    board: ^Board,
    empty_turns: int,
}

init_engine :: proc(engine: ^Engine, board: ^Board) {
    engine.board = board
    engine.empty_turns = 0
}

// Update engine state based on a move
update_engine :: proc(engine: ^Engine, move: ^Move) {
    // Check if this is a capture move
    captured_piece := piece_at(engine.board, move.position)
    
    // Get the piece that's moving
    piece := get_last_moved_piece(engine.board)
    
    // Update empty turns counter
    if captured_piece != nil || piece.type == .Peon {
        engine.empty_turns = 0
    } else {
        engine.empty_turns += 1
    }
}

// Evaluate the current position
evaluate :: proc(engine: ^Engine) -> int {
    score := 0

    // Evaluate all pieces
    white_pieces := get_pieces_by_color(engine.board, .White)
    black_pieces := get_pieces_by_color(engine.board, .Black)

    // Evaluate white pieces
    for piece in dyn.array_as_slice(&white_pieces) {
        if piece == nil { continue }
        pos_index := piece.position.x * 8 + piece.position.y

        // Material score & Positional Score
        #partial switch piece.type {
        case .Peon:
            score += 100 + pawn_score[pos_index]
        case .Knight:
            score += 300 + knight_score[pos_index]
        case .Bishop:
            score += 350 + bishop_score[pos_index]
        case .Rook:
            score += 500 + rook_score[pos_index]
        case .Queen:
            score += 1000 + queen_score[pos_index]
        case .King:
            score += 10000 + king_score[pos_index]
        }
    }
    for piece in dyn.array_as_slice(&black_pieces) {
        if piece == nil { continue }
        pos_index := piece.position.x * 8 + piece.position.y
        mirrored_index := mirror_score[pos_index] // <-- Use mirrored index for black

        // Material score & Positional Score
        #partial switch piece.type {
        case .Peon:
            score -= (100 + pawn_score[mirrored_index]) // <-- Subtract positional
        case .Knight:
            score -= (300 + knight_score[mirrored_index]) // <-- Subtract positional
        case .Bishop:
            score -= (350 + bishop_score[mirrored_index]) // <-- Subtract positional
        case .Rook:
            score -= (500 + rook_score[mirrored_index]) // <-- Subtract positional
        case .Queen:
            score -= (1000 + queen_score[mirrored_index]) // <-- Subtract positional
        case .King:
            score -= (10000 + king_score[mirrored_index]) // <-- Subtract positional
        }
    }

    // TODO: Add other evaluation factors like mobility, king safety, pawn structure etc. later

    return score
}


SEARCH_DEPTH :: 4 // Keep or adjust as needed

// Structure to hold a piece and its potential move
AIMoveInfo :: struct {
    piece: ^Piece,
    move: Move,
}

// Minimax search with alpha-beta pruning
// Returns the evaluation score and the *best move value* for the root call
minimax :: proc(
    board: ^Board,
    engine: ^Engine,
    depth: int,
    alpha: ^int,
    beta: ^int,
    is_maximizing: bool,
) -> (eval: int, best_root_move: Move) { // Return Move value

    // Base case: if depth is 0 or game over, evaluate the position
    if depth == 0 || engine.empty_turns >= 50 { // Added 50-move rule check here
        // No specific move to return from leaf/cutoff nodes
        return evaluate(engine), Move{}
    }

    best_eval: int = is_maximizing ? min(int) : max(int)
    best_move_for_this_node := Move{} // Best move found at this level
    move_from_root := Move{} // The actual move to return from the initial call

    turn_color := is_maximizing ? PieceColor.White : PieceColor.Black

    // --- Generate all legal moves for the current side ---
    valid_moves: [dynamic]AIMoveInfo // Store piece and move value
    defer delete(valid_moves) // Clean up the dynamic array header

    pieces := get_pieces_by_color(board, turn_color)
    for piece in dyn.array_as_slice(&pieces) {
        if piece == nil { continue }

        // Note: get_possible_moves allocates, we need to manage this if it becomes an issue,
        // but for now, assume it's handled or acceptable within the search.
        // A more optimized approach might use a pre-allocated buffer.
        possible_moves := get_possible_moves(piece, board)
        for move_val in possible_moves {
            // Create a temporary pointer for move_leads_to_check if needed
            move := move_val
            if !move_leads_to_check(board, piece, &move) {
                // Check if the move attacks the opponent's king (illegal)
                 is_attack_move := move_val.type == .Attack || move_val.type == .AttackAndPromote
                 attacked_piece_at_dest: ^Piece = nil
                 if is_attack_move {
                    attacked_piece_at_dest = piece_at(board, move_val.position)
                 }
                 if attacked_piece_at_dest == nil || attacked_piece_at_dest.type != .King {
                     append(&valid_moves, AIMoveInfo{piece = piece, move = move_val})
                 }
            }
        }
        // Make sure to delete/free the slice returned by get_possible_moves if it allocates dynamically
         delete(possible_moves) // Assuming get_possible_moves returns a dynamically allocated slice
    }
    // --- End Move Generation ---


    // Check for Checkmate or Stalemate
    if len(valid_moves) == 0 {
        king_in_check := is_board_in_check(board, turn_color)
        if king_in_check {
            // Checkmate: Assign a very high/low score penalized by depth (faster mates preferred)
            return (is_maximizing ? -(1000000 + depth) : (1000000 + depth)), Move{}
        } else {
            // Stalemate
            return 0, Move{}
        }
    }

    // Try each valid move
    for move_info in valid_moves {
        // Make a copy of the board and engine state
        board_copy := clone_board(board)
        // IMPORTANT: Find the corresponding piece *in the copied board*
        piece_in_copy := piece_at(board_copy, move_info.piece.position)
        if piece_in_copy == nil {
             // Should not happen if cloning and piece finding is correct
             fmt.eprintf("Error: Could not find piece %v at %v in copied board during AI search.\n", move_info.piece.name, move_info.piece.position)
             destroy_board(board_copy)
             continue // Skip this problematic move
        }

        engine_copy := Engine{board = board_copy, empty_turns = engine.empty_turns}

        // Apply the move (pass pointer to the move value)
        current_move := move_info.move
        do_move(board_copy, piece_in_copy, &current_move)
        update_engine(&engine_copy, &current_move) // Update engine *after* move

        // Recursively evaluate
        // Note: The second return value (best_root_move) from recursive calls is ignored here.
        // We only care about the evaluation score from children.
        eval, _ := minimax(board_copy, &engine_copy, depth - 1, alpha, beta, !is_maximizing)

        // Cleanup the copied board
        destroy_board(board_copy)

        // Update best evaluation based on turn
        if is_maximizing { // White's turn (maximizing)
            if eval > best_eval {
                best_eval = eval
                best_move_for_this_node = move_info.move // Store the best move value found so far *at this depth*
            }
            // Update alpha *after* potentially updating best_eval
             current_alpha := max(alpha^, best_eval)
             alpha^ = current_alpha // Correct way to update alpha reference
        } else { // Black's turn (minimizing)
            if eval < best_eval {
                best_eval = eval
                best_move_for_this_node = move_info.move // Store the best move value found so far *at this depth*
            }
            // Update beta *after* potentially updating best_eval
            current_beta := min(beta^, best_eval)
            beta^ = current_beta // Correct way to update beta reference
        }

        // Alpha-beta pruning
        // If beta <= alpha, prune the remaining branches
        if beta^ <= alpha^ { // Use dereferenced values for comparison
            break
        }
    }

    // If this is the root call (depth == SEARCH_DEPTH), set the move_from_root
    // Note: This check isn't strictly necessary if find_best_move calls with SEARCH_DEPTH
    // and uses the returned 'best_move_for_this_node'. Let's simplify.
    // We return the best move found *at this specific node*.
    // The caller (`find_best_move`) will receive the best move from the top-level call.

    return best_eval, best_move_for_this_node
}


// Find the best move for the current board position
// Returns the best Move value
find_best_move :: proc(board: ^Board, is_black_turn: bool) -> Move {
    engine: Engine
    init_engine(&engine, board) // Initialize engine with the current board

    // Define initial alpha-beta values
    alpha := min(int)
    beta := max(int)

    // Call minimax (white is maximizing, black is minimizing)
    is_maximizing := !is_black_turn
    _, best_move := minimax(board, &engine, SEARCH_DEPTH, &alpha, &beta, is_maximizing)

    // The second return value from the top-level minimax call is the best move found.
    return best_move
}