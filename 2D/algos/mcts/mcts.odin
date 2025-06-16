package mcts

import "core:time"
import "core:math"
import "core:math/rand"

MCTSNode :: struct {
    boardstate: Board,
    player_char: rune,
    move: ^AiMove,
    parent: ^MCTSNode,
    children: Array(MAX_ITER, ^MCTSNode),
    available_moves: Array(BOARD_DIM*BOARD_DIM, ^AiMove),
    node_visits: int,
    wins: int,
}

MCTS :: struct {
    root_node: MCTSNode,
    max_iter: int,
    max_time: time.Duration,
    boards_per_sec: time.Duration,
    nodes_searched: uint,
}

// Initialize a new MCTS node
init_mcts_node :: proc(board: Board, player_char: rune, move: ^AiMove, parent: ^MCTSNode) -> ^MCTSNode {
    node := new(MCTSNode)
    node.boardstate = board
    node.player_char = player_char
    node.move = move
    node.parent = parent
    
    if parent != nil && move != nil {
        node.boardstate.tiles[move.row][move.column].status = parent.player_char
    }
    set_available_moves(node)
    return node
}

// Calculate UCT (Upper Confidence Bound for Trees)
calc_uct :: proc(node: ^MCTSNode) -> f32 {
    if node.node_visits == 0 do return math.F32_MAX
    
    parent_visits := node.parent == nil ? 1 : node.parent.node_visits
    exploitation := f32(node.wins) / f32(node.node_visits)
    exploration := 1.44 * math.sqrt_f32(math.log_f32(f32(parent_visits), 10) / f32(node.node_visits))
    
    return exploitation + exploration
}

// Set available moves for node
set_available_moves :: proc(node: ^MCTSNode) {
    array_clear(&node.available_moves)
    
    for row in 0..<BOARD_DIM {
        for column in 0..<BOARD_DIM {
            if node.boardstate.tiles[row][column].status == ' ' {
                move := new(AiMove)
                move^ = AiMove{row, column, 0}
                array_push(&node.available_moves, move)
            }
        }
    }
}

// Check if node is fully expanded
is_fully_expanded :: proc(node: ^MCTSNode) -> bool {
    return node.available_moves.len == 0 || 
           array_is_full(node.children) || 
           node.children.len >= node.available_moves.len
}

// Get best child based on UCT
get_best_child :: proc(node: ^MCTSNode) -> ^MCTSNode {
    if node.children.len == 0 do return node
    
    best_child: ^MCTSNode = nil
    best_uct:f32 = -math.F32_MAX
    
    for i in 0..<node.children.len {
        child := node.children.data[i]
        child_uct := calc_uct(child)
        
        if child_uct > best_uct {
            best_uct = child_uct
            best_child = child
        }
    }
    
    return best_child == nil ? node : best_child
}

// Get child with highest visit count
get_best_visited_child :: proc(node: ^MCTSNode) -> ^MCTSNode {
    if node.children.len == 0 do return nil
    
    best_child: ^MCTSNode = nil
    most_visits := -1
    
    for i in 0..<node.children.len {
        child := node.children.data[i]
        if child.node_visits > most_visits {
            most_visits = child.node_visits
            best_child = child
        }
    }
    return best_child
}

// MCTS selection phase
selection :: proc(root: ^MCTSNode) -> ^MCTSNode {
    current := root
    
    for current.children.len > 0 && is_fully_expanded(current) {
        current = get_best_child(current)
        if current == nil do break
    }
    return current
}

// MCTS expansion phase
expansion :: proc(node: ^MCTSNode) -> ^MCTSNode {
    // If terminal node or no available moves, return node
    if check_winner(&node.boardstate) != ' ' || check_draw(&node.boardstate) {
        return node
    }
    
    if node.available_moves.len == 0 do return node
    
    // Pick random available move
    move_idx := rand.int_max(node.available_moves.len)
    random_move := node.available_moves.data[move_idx]
    
    // Remove move from available moves
    node.available_moves.data[move_idx] = node.available_moves.data[node.available_moves.len - 1]
    node.available_moves.len -= 1
    
    // Create new child with this move
    next_char := next_player(node.player_char)
    board_copy := clone_board(&node.boardstate)
    new_child := init_mcts_node(board_copy, next_char, random_move, node)
    
    array_push(&node.children, new_child)
    
    return new_child
}

// Simulation phase
simulation :: proc(node: ^MCTSNode) -> rune {
    // Check if game is over already
    if winner := check_winner(&node.boardstate); winner != ' ' {
        return winner
    }
    if check_draw(&node.boardstate) do return 'd'  // d for draw
    
    // Create a copy of it for the simulator
    board_copy := clone_board(&node.boardstate)
    current_player := next_player(node.player_char)
    
    // Play random moves until game ends
    for {
        available_moves: [BOARD_DIM * BOARD_DIM]AiMove
        move_count := 0
        for row in 0..<BOARD_DIM {
            for col in 0..<BOARD_DIM {
                if board_copy.tiles[row][col].status == ' ' {
                    available_moves[move_count] = AiMove{row, col, 0}
                    move_count += 1
                }
            }
        }
        if move_count == 0 do return 'd'  // No moves, it's a draw
        
        // Pick random move
        move_idx := rand.int_max(move_count)
        move := available_moves[move_idx]
        
        // Make move
        board_copy.tiles[move.row][move.column].status = current_player
        
        // Check if game ended
        if winner := check_winner(&board_copy); winner != ' ' {
            return winner
        }
        // Switch player
        current_player = next_player(current_player)
    }
    return ' ' // should never happen
}

// Backpropagation phase
backpropagation :: proc(node: ^MCTSNode, winner: rune) {
    current := node
    for current != nil {
        current.node_visits += 1
        
        if winner == current.player_char {
            current.wins += 1
        } else if winner == 'd' {  // Draw
            current.wins += 0
        }
        current = current.parent
    }
}

// Find the best next move
mcts_find_move :: proc(game: ^Game, player: ^Player) -> AiMove {
    // Init root node
    game.mcts.nodes_searched = 0
    
    // Assign root node with current board state
    root := MCTSNode{
        boardstate = clone_board(&game.board),
        player_char = player.character,
    }
    set_available_moves(&root)
    
    game.mcts.root_node = root
    
    // Run MCTS algorithm
    start_time := time.now()
    iterations := 0
    for {
        // Check if time or iteration limit was reached
        if iterations >= game.mcts.max_iter || 
           time.since(start_time) >= game.mcts.max_time {
            break
        }
        // Phase 1:
        selected := selection(&game.mcts.root_node)
        // Phase 2:
        expanded := expansion(selected)
        // Phase 3:
        result := simulation(expanded)
        // Phase 4:
        backpropagation(expanded, result)
        
        iterations += 1
        game.mcts.nodes_searched += 1
    }
    // Select the best move
    best_child := get_best_visited_child(&game.mcts.root_node)

    if best_child == nil || best_child.move == nil {
        // Fallback to random move
        for row in 0..<BOARD_DIM {
            for col in 0..<BOARD_DIM {
                if game.board.tiles[row][col].status == ' ' {
                    return AiMove{row, col, 0}
                }
            }
        }
        return AiMove{0, 0, 0}  // Should never reach here unless board is full
    }
    return AiMove{best_child.move.row, best_child.move.column, best_child.node_visits}
}