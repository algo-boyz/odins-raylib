package chess

King :: struct {
    using piece: Piece,
}

new_king :: proc(position: Position, color: PieceColor) -> ^King {
    king := new(King)
    king.position = position
    king.color = color
    king.type = .King
    king.has_moved = false
    king.name = color == .White ? "wk" : "bk"
    return king
}

get_moves_king :: proc(using king: ^King, board: ^Board) -> []Move {
    possible_positions := [8]Position{
        // Up
        {position.x - 1, position.y},
        // Down
        {position.x + 1, position.y},
        // Right
        {position.x, position.y + 1},
        // Left
        {position.x, position.y - 1},
        // Up-left
        {position.x - 1, position.y - 1},
        // Up-right
        {position.x - 1, position.y + 1},
        // Down-left
        {position.x + 1, position.y - 1},
        // Down-right
        {position.x + 1, position.y + 1},
    }

    moves := make([dynamic]Move)

    for pos in possible_positions {
        if is_position_within_boundaries(board, pos) {
            piece_at_pos := piece_at(board, pos)
            if piece_at_pos == nil {
                append(&moves, Move{.Walk, pos})
            } else if piece_at_pos.color != color {
                append(&moves, Move{.Attack, pos})
            }
        }
    }

    // Check for long castling (left rook)
    if check_castling(king, board, Position{position.x, 0}, 
                     []Position{{position.x, 1}, {position.x, 2}, {position.x, 3}}) {
        append(&moves, Move{.LongCastling, Position{position.x, 2}})
    }

    // Check for short castling (right rook)
    if check_castling(king, board, Position{position.x, 7}, 
                     []Position{{position.x, 5}, {position.x, 6}}) {
        append(&moves, Move{.ShortCastling, Position{position.x, 6}})
    }

    return moves[:]
}

Queen :: struct {
    using piece: Piece,
}

new_queen :: proc(position: Position, color: PieceColor) -> ^Queen {
    queen := new(Queen)
    queen.position = position
    queen.color = color
    queen.type = .Queen
    queen.has_moved = false
    queen.name = color == .White ? "wq" : "bq"
    return queen
}

get_moves_queen :: proc(using queen: ^Queen, board: ^Board) -> []Move {
    moves := make([dynamic]Move)
    
    // Horizontal and vertical moves (like Rook)
    add_valid_moves(queen, board, &moves, Position{position.x, position.y - 1}, 0, -1)  // Left
    add_valid_moves(queen, board, &moves, Position{position.x, position.y + 1}, 0, 1)   // Right
    add_valid_moves(queen, board, &moves, Position{position.x - 1, position.y}, -1, 0)  // Up
    add_valid_moves(queen, board, &moves, Position{position.x + 1, position.y}, 1, 0)   // Down
    
    // Diagonal moves (like Bishop)
    add_valid_moves(queen, board, &moves, Position{position.x - 1, position.y - 1}, -1, -1)  // Up-left
    add_valid_moves(queen, board, &moves, Position{position.x - 1, position.y + 1}, -1, 1)   // Up-right
    add_valid_moves(queen, board, &moves, Position{position.x + 1, position.y + 1}, 1, 1)    // Down-right
    add_valid_moves(queen, board, &moves, Position{position.x + 1, position.y - 1}, 1, -1)   // Down-left
    
    return moves[:]
}

Knight :: struct {
    using piece: Piece,
}

new_knight :: proc(position: Position, color: PieceColor) -> ^Knight {
    knight := new(Knight)
    knight.position = position
    knight.color = color
    knight.type = .Knight
    knight.has_moved = false
    knight.name = color == .White ? "wn" : "bn"
    return knight
}

get_moves_knight :: proc(using knight: ^Knight, board: ^Board) -> []Move {
    possible_positions := [8]Position{
        // Up
        {position.x - 2, position.y - 1},
        {position.x - 2, position.y + 1},
        // Right
        {position.x - 1, position.y + 2},
        {position.x + 1, position.y + 2},
        // Down
        {position.x + 2, position.y - 1},
        {position.x + 2, position.y + 1},
        // Left
        {position.x - 1, position.y - 2},
        {position.x + 1, position.y - 2},
    }

    moves := make([dynamic]Move)

    for pos in possible_positions {
        if is_position_within_boundaries(board, pos) {
            piece_at_pos :=piece_at(board, pos)
            if piece_at_pos == nil {
                append(&moves, Move{.Walk, pos})
            } else if piece_at_pos.color != color {
                append(&moves, Move{.Attack, pos})
            }
        }
    }

    return moves[:]
}

Bishop :: struct {
    using piece: Piece,
}

new_bishop :: proc(position: Position, color: PieceColor) -> ^Bishop {
    bishop := new(Bishop)
    bishop.position = position
    bishop.color = color
    bishop.type = .Bishop
    bishop.has_moved = false
    bishop.name = color == .White ? "wb" : "bb"
    return bishop
}

get_moves_bishop :: proc(using bishop: ^Bishop, board: ^Board) -> []Move {
    moves := make([dynamic]Move)
    
    // Checking up-left
    add_valid_moves(bishop, board, &moves, Position{position.x - 1, position.y - 1}, -1, -1)
    
    // Checking up-right
    add_valid_moves(bishop, board, &moves, Position{position.x - 1, position.y + 1}, -1, 1)
    
    // Checking down-right
    add_valid_moves(bishop, board, &moves, Position{position.x + 1, position.y + 1}, 1, 1)
    
    // Checking down-left
    add_valid_moves(bishop, board, &moves, Position{position.x + 1, position.y - 1}, 1, -1)
    
    return moves[:]
}

Rook :: struct {
    using piece: Piece,
}

new_rook :: proc(position: Position, color: PieceColor) -> ^Rook {
    rook := new(Rook)
    rook.position = position
    rook.color = color
    rook.type = .Rook
    rook.has_moved = false
    rook.name = color == .White ? "wr" : "br"
    return rook
}

get_moves_rook :: proc(using rook: ^Rook, board: ^Board) -> []Move {
    moves := make([dynamic]Move)
    
    // Left
    add_valid_moves(rook, board, &moves, Position{position.x, position.y - 1}, 0, -1)
    // Right
    add_valid_moves(rook, board, &moves, Position{position.x, position.y + 1}, 0, 1)
    // Up
    add_valid_moves(rook, board, &moves, Position{position.x - 1, position.y}, -1, 0)
    // Down
    add_valid_moves(rook, board, &moves, Position{position.x + 1, position.y}, 1, 0)
    
    return moves[:]
}

Peon :: struct {
    using piece: Piece,
    has_only_made_double_walk: bool,
}

new_peon :: proc(position: Position, color: PieceColor) -> ^Peon {
    peon := new(Peon)
    peon.position = position
    peon.color = color
    peon.type = .Peon
    peon.has_moved = false
    peon.has_only_made_double_walk = false
    peon.name = color == .White ? "wp" : "bp"
    return peon
}

move_peon :: proc(using peon: ^Peon, move: ^Move) {
    peon.has_only_made_double_walk = move.type == .DoubleWalk
    peon.has_moved = true
    peon.position = move.position
}

get_moves_peon :: proc(using peon: ^Peon, board: ^Board) -> []Move {
    moves := make([dynamic]Move)
    
    // Direction depends on color
    direction := color == .White ? -1 : 1
    
    // Forward move
    walk_pos := Position{position.x + direction, position.y}
    if is_position_within_boundaries(board, walk_pos) && piece_at(board, walk_pos) == nil {
        append(&moves, Move{.Walk, walk_pos})
        
        // Double walk from starting position
        double_walk_pos := Position{position.x + (2 * direction), position.y}
        if !has_moved && piece_at(board, double_walk_pos) == nil {
            append(&moves, Move{.DoubleWalk, double_walk_pos})
        }
    }
    states := [2]int{-1, 1}
    // Attack positions
    attack_row := position.x + direction
    for offset in states {
        attack_pos := Position{attack_row, position.y + offset}
        if is_position_within_boundaries(board, attack_pos) {
            piece_at_pos := piece_at(board, attack_pos)
            if piece_at_pos != nil && piece_at_pos.color != color {
                append(&moves, Move{.Attack, attack_pos})
            }
        }
    }
    
    // En passant check
    for offset in states{
        adjacent_pos := Position{position.x, position.y + offset}
        attack_pos := Position{attack_row, position.y + offset}
        
        if check_en_passant(peon, board, adjacent_pos, attack_pos) {
            append(&moves, Move{.EnPassant, attack_pos})
        }
    }
    
    // Check for promotion
    final_moves := make([dynamic]Move)
    for move in moves {
        if is_promote_position(peon, move.position) {
            new_type := move.type == .Attack ? MoveType.AttackAndPromote : MoveType.Promotion
            append(&final_moves, Move{new_type, move.position})
        } else {
            append(&final_moves, move)
        }
    }
    
    defer delete(moves)
    return final_moves[:]
}