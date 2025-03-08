package chess

import "dyn"
import "core:fmt"

MoveType :: enum {
    Walk,
    DoubleWalk,
    Attack,
    ShortCastling,
    LongCastling,
    EnPassant,
    Promotion,
    AttackAndPromote,
}

Position :: struct {
    x, y: int,
}

Move :: struct {
    type: MoveType,
    position: Position,
}

Board :: struct {
    white_pieces: dyn.Array(16, ^Piece),
    black_pieces: dyn.Array(16, ^Piece),
    last_moved_piece_pos: Position,
}

// Improved clone_board function to fully copy all piece state
clone_board :: proc(other: ^Board) -> ^Board {
    new_board := new(Board)
    
    // Copy last moved piece position
    new_board.last_moved_piece_pos = other.last_moved_piece_pos
    
    // Clone white pieces with complete state
    for piece in dyn.array_as_slice(&other.white_pieces) {
        // Create a new piece with the same type, position, and color
        new_piece := create_piece_by_type(piece.type, piece.position, piece.color)
        
        // Copy common piece state
        new_piece.has_moved = piece.has_moved
        new_piece.name = piece.name
        
        // Copy type-specific state based on piece type
        #partial switch piece.type {
        case .Peon:
            // For pawns, copy additional state
            src_peon := cast(^Peon)piece
            dst_peon := cast(^Peon)new_piece
            dst_peon.has_only_made_double_walk = src_peon.has_only_made_double_walk
        case .King, .Rook:
            // These already have has_moved which is copied above
        }
        
        // Add to the appropriate array
        dyn.array_push(&new_board.white_pieces, new_piece)
    }
    
    // Clone black pieces with complete state
    for piece in dyn.array_as_slice(&other.black_pieces) {
        // Create a new piece with the same type, position, and color
        new_piece := create_piece_by_type(piece.type, piece.position, piece.color)
        
        // Copy common piece state
        new_piece.has_moved = piece.has_moved
        new_piece.name = piece.name
        
        // Copy type-specific state based on piece type
        #partial switch piece.type {
        case .Peon:
            // For pawns, copy additional state
            src_peon := cast(^Peon)piece
            dst_peon := cast(^Peon)new_piece
            dst_peon.has_only_made_double_walk = src_peon.has_only_made_double_walk
        case .King, .Rook:
            // These already have has_moved which is copied above
        }
        
        // Add to the appropriate array
        dyn.array_push(&new_board.black_pieces, new_piece)
    }
    
    return new_board
}

// Improved destroy_board function to properly clean up all memory
destroy_board :: proc(board: ^Board) {
    if board == nil do return
    clear_board(board)
    // Free the board itself
    free(board)
}

// Helper function to properly clear a board without destroying it
clear_board :: proc(board: ^Board) {
    if board == nil do return
    
    // Free all white pieces first
    for piece in dyn.array_as_slice(&board.white_pieces) {
        if piece != nil {
            free(piece)
        }
    }
    dyn.array_clear(&board.white_pieces)
    
    // Free all black pieces
    for piece in dyn.array_as_slice(&board.black_pieces) {
        if piece != nil {
            free(piece)
        }
    }
    dyn.array_clear(&board.black_pieces)
}

init_board :: proc(board: ^Board) {
    // Init black pieces (computer)
    for j := 0; j < 8; j += 1 {
        add_piece(board, new_peon(Position{1, j}, .Black))
    }
    add_piece(board, new_rook(Position{0, 0}, .Black))
    add_piece(board, new_rook(Position{0, 7}, .Black))
    
    add_piece(board, new_knight(Position{0, 1}, .Black))
    add_piece(board, new_knight(Position{0, 6}, .Black))
    
    add_piece(board, new_bishop(Position{0, 2}, .Black))
    add_piece(board, new_bishop(Position{0, 5}, .Black))
    
    add_piece(board, new_queen(Position{0, 3}, .Black))
    add_piece(board, new_king(Position{0, 4}, .Black))
    
    // Init white pieces (player)
    for j := 0; j < 8; j += 1 {
        add_piece(board, new_peon(Position{6, j}, .White))
    }
    
    add_piece(board, new_rook(Position{7, 0}, .White))
    add_piece(board, new_rook(Position{7, 7}, .White))
    
    add_piece(board, new_knight(Position{7, 1}, .White))
    add_piece(board, new_knight(Position{7, 6}, .White))
    
    add_piece(board, new_bishop(Position{7, 2}, .White))
    add_piece(board, new_bishop(Position{7, 5}, .White))
    
    add_piece(board, new_queen(Position{7, 3}, .White))
    add_piece(board, new_king(Position{7, 4}, .White))
}

piece_at :: proc(board: ^Board, pos: Position) -> ^Piece {
    if !is_position_within_boundaries(board, pos) do return nil
    // fmt.println("Checking for piece at position: ", pos)
    for piece, i in dyn.array_as_slice(&board.white_pieces) {
        if piece.position.x == pos.x && piece.position.y == pos.y do return piece
    }
    for piece, i in dyn.array_as_slice(&board.black_pieces) {
        if piece.position.x == pos.x && piece.position.y == pos.y do return piece
    }
    return nil
}

add_piece :: proc(board: ^Board, piece: ^Piece) {
    if piece.color == .White {
        dyn.array_push(&board.white_pieces, piece)
    } else {
        dyn.array_push(&board.black_pieces, piece)
    }
}

destroy_piece_at :: proc(board: ^Board, pos: Position) {
    for piece, i in dyn.array_as_slice(&board.white_pieces) {
        if piece.position.x == pos.x && piece.position.y == pos.y {
            free(piece)
            dyn.array_ordered_remove(&board.white_pieces, i)
            return
        }
    }
    for piece, i in dyn.array_as_slice(&board.black_pieces) {
        if piece.position.x == pos.x && piece.position.y == pos.y {
            free(piece)
            dyn.array_ordered_remove(&board.black_pieces, i)
            return
        }
    }
}

get_pieces_by_color :: proc(board: ^Board, color: PieceColor) -> dyn.Array(16, ^Piece) {
    if color == .White {
        return board.white_pieces
    }
    return board.black_pieces
}

get_last_moved_piece :: proc(board: ^Board) -> ^Piece {
    return piece_at(board, board.last_moved_piece_pos)
}

do_move_on_board :: proc(g: ^Game, move: ^Move) {
    do_move(g.board, g.selected_piece, move)

    if move.type == .Promotion || move.type == .AttackAndPromote {
        // Show promotion screen
        g.state = .Promotion
        handle_promotion_input(g)
    } else {
        // in case of castling, also move rook
        if move.type == .ShortCastling {
            do_short_castling(g.board, g.selected_piece, move)
        } else if move.type == .LongCastling {
            do_long_castling(g.board, g.selected_piece, move)
        }
        swap_turns(g)
    }
}

do_move :: proc(board: ^Board, piece: ^Piece, move: ^Move) {
    old_position := piece.position
    // delete piece, if attack or en passant
    if move.type == .Attack {
        destroy_piece_at(board, move.position)
    } else if move.type == .EnPassant {
        destroy_piece_at(board, old_position)
    }
    if piece.type == .Peon {
        move_peon(cast(^Peon)piece, move)
    } else {
        // regular move for other pieces
        piece.position = move.position
        if piece.type == .King || piece.type == .Rook {
            piece.has_moved = true  // For castling logic
        }
    }
    board.last_moved_piece_pos = piece.position
}

do_short_castling :: proc(board: ^Board, selected_piece: ^Piece, move: ^Move) {
    rook := piece_at(board, Position{selected_piece.position.x, 7})
    do_move(board, selected_piece, move)
    do_move(board, rook, &Move{.Walk, Position{rook.position.x, rook.position.y - 2}})
}

do_long_castling :: proc(board: ^Board, selected_piece: ^Piece, move: ^Move) {
    rook := piece_at(board, Position{selected_piece.position.x, 0})
    do_move(board, selected_piece, move)
    do_move(board, rook, &Move{.Walk, Position{rook.position.x, rook.position.y + 3}})
}

move_leads_to_check :: proc(board: ^Board, piece: ^Piece, move: ^Move) -> bool {
    // Copy current board and current selected piece
    board_copy := clone_board(board)
    piece_in_copied_board := piece_at(board_copy, piece.position)
    // Perform the move
    do_move(board_copy, piece_in_copied_board, move)
    
    is_in_check := is_board_in_check(board_copy, piece.color)
    destroy_board(board_copy)
    return is_in_check
}

is_board_in_check :: proc(board: ^Board, color: PieceColor) -> bool {
    enemy_pieces := get_pieces_by_color(board, get_inverse_color(color))
    
    for piece in dyn.array_as_slice(&enemy_pieces) {
        for move in get_possible_moves(piece, board) {
            piece_at_move_pos := piece_at(board, move.position)
            move_pos_contains_my_king := piece_at_move_pos != nil && piece_at_move_pos.color == color && piece_at_move_pos.type == .King
            move_is_attack := move.type == .Attack || move.type == .AttackAndPromote
            // If the enemy piece is attacking my king, the king is in check
            if move_pos_contains_my_king && move_is_attack {
                return true
            }
        }
    }
    return false
}