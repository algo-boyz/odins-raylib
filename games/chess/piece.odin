package chess

import "base:runtime"
import "core:slice"
import rl "vendor:raylib"

PieceType :: enum {
    Peon,
    Rook,
    Knight,
    Bishop,
    Queen,
    King,
}

PieceColor :: enum {
    White,
    Black,
}

Piece :: struct {
    position: Position,
    color: PieceColor,
    type: PieceType,
    has_moved: bool,
    name: string,
}

piece_options := [4]struct {
    suffix: string,
    name: cstring,
    x_offset: i32,
}{
    {"q", "Queen", 9},
    {"r", "Rook", 14},
    {"b", "Bishop", 7},
    {"n", "Knight", 9},
}

create_piece_by_type :: proc(type: PieceType, position: Position, color: PieceColor) -> ^Piece {
    switch type {
    case .Peon:
        return new_peon(position, color)
    case .Rook:
        return new_rook(position, color)
    case .Knight:
        return new_knight(position, color)
    case .Bishop:
        return new_bishop(position, color)
    case .Queen:
        return new_queen(position, color)
    case .King:
        return new_king(position, color)
    }
    return nil // This should never be reached
}

get_inverse_color :: proc(color: PieceColor) -> PieceColor {
    return color == .White ? .Black : .White
}

get_texture_name_from_move_type :: proc(move_type: MoveType) -> string {
    #partial switch move_type {
    case .Walk, .DoubleWalk, .Attack:
        return "move"
    case .ShortCastling, .LongCastling:
        return "castling"
    case .EnPassant:
        return "enpassant"
    case .Promotion, .AttackAndPromote:
        return "promotion"
    }
    return ""
}

get_piece_character_by_type :: proc(type: PieceType) -> string {
    switch type {
    case .Peon:
        return "p"
    case .Rook:
        return "r"
    case .Knight:
        return "n"
    case .Bishop:
        return "b"
    case .Queen:
        return "q"
    case .King:
    }
    return "k"
}

get_shade_color :: proc(color: PieceColor) -> rl.Color {
    return color == .White ? LIGHT_SHADE : DARK_SHADE
}

get_color_of_cell :: proc(cell_position: Position) -> PieceColor {
    starting_color_in_row := cell_position.x % 2 == 0 ? 0 : 1
    color_index := (starting_color_in_row + cell_position.y) % 2

    return color_index == 0 ? .White : .Black
}

get_possible_moves:: proc(piece: ^Piece, board: ^Board) -> []Move {
    moves := []Move{}
    switch piece.type {
    case PieceType.King:
        moves = get_moves_king(cast(^King)piece, board)
    case PieceType.Queen:
        moves = get_moves_queen(cast(^Queen)piece, board)
    case PieceType.Rook:
        moves = get_moves_rook(cast(^Rook)piece, board)
    case PieceType.Bishop:
        moves = get_moves_bishop(cast(^Bishop)piece, board)
    case PieceType.Knight:
        moves = get_moves_knight(cast(^Knight)piece, board)
    case PieceType.Peon:
        moves = get_moves_peon(cast(^Peon)piece, board)
    }
    return moves
}

add_valid_moves :: proc(piece: ^Piece, board: ^Board, moves: ^[dynamic]Move, pos: Position, x_increment: int, y_increment: int) {
    current_pos := pos
    for is_position_within_boundaries(board, current_pos) {
        piece_at_pos := piece_at(board, current_pos)
        if piece_at_pos == nil {
            append(moves, Move{.Walk, current_pos})
            current_pos.x += x_increment
            current_pos.y += y_increment
        } else if piece_at_pos.color != piece.color {
            append(moves, Move{.Attack, current_pos})
            break
        } else {
            break
        }
    }
}

is_position_within_boundaries :: proc(board: ^Board, pos: Position) -> bool {
    return pos.x >= 0 && pos.x < 8 && pos.y >= 0 && pos.y < 8
}

is_promote_position :: proc(peon: ^Peon, pos: Position) -> bool {
    return (pos.x == 0 && peon.color == .White) || (pos.x== 7 && peon.color == .Black)
}

check_en_passant :: proc(peon: ^Peon, board: ^Board, piece_pos: Position, attack_pos: Position) -> bool {
    if !is_position_within_boundaries(board, attack_pos) || piece_at(board, attack_pos) != nil {
        return false
    }
    piece := piece_at(board, piece_pos)
    if piece == nil || piece.color == peon.color || piece.type != .Peon {
        return false
    }
    target_peon := cast(^Peon)piece
    return target_peon.has_only_made_double_walk && get_last_moved_piece(board) == piece
}

check_castling :: proc(king: ^King, board: ^Board, rook_position: Position, intermediate_positions: []Position) -> bool {
    piece :=piece_at(board, rook_position)
    if piece == nil || piece.color != king.color || piece.type != .Rook || piece.has_moved || king.has_moved {
        return false
    }

    // Check positions between the king and the rook
    for pos in intermediate_positions {
        if piece_at(board, pos) != nil {
            return false
        }
    }

    return true
}