package chess

import "dyn"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"
import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 700

CELL_SIZE :: 80
INFO_BAR_HEIGHT :: 60

LIGHT_SHADE :: rl.Color{240, 217, 181, 255}
DARK_SHADE :: rl.Color{181, 136, 99, 255}

SOUND_PATH :: "../assets/sounds"
TEXTURE_PATH := "../assets/textures"

GameState :: enum {
    Running,
    Promotion,
    WhiteWins,
    BlackWins,
    Stalemate,
}

Game :: struct {
    board: ^Board,
    music: rl.Music,
    selected_piece: ^Piece,
    possible_moves_per_piece: map[^Piece][]Move,
    previewed_move: bool,
    textures: map[string]rl.Texture2D,
    sounds: map[string]rl.Sound,
    turn: PieceColor,
    state: GameState,
    round: int,
    time: f32,
    ai_player: ^AI,
}

init:: proc() -> ^Game {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Chess")
    rl.InitAudioDevice()
    rl.SetTargetFPS(60)
    g := new(Game)
    g.textures = make(map[string]rl.Texture2D)
    load_textures(g)
    g.sounds = make(map[string]rl.Sound)
    load_sounds(g)
    g.music = rl.LoadMusicStream("../assets/the-second-waltz.mp3")
    g.board = new(Board)
    init_board(g.board)
    g.turn = .White
    g.state = .Running
    calculate_all_possible_moves(g)
    g.previewed_move = true
    g.ai_player = new_ai() 
    return g
}

destroy :: proc(g: ^Game) {
    for _, texture in g.textures {
        rl.UnloadTexture(texture)
    }
    delete(g.textures)
    rl.UnloadMusicStream(g.music)
    for _, sound in g.sounds {
        rl.UnloadSound(sound)
    }
    delete(g.sounds)
    destroy_board(g.board)
    delete(g.possible_moves_per_piece)
    if g.ai_player != nil {
        free(g.ai_player)
    }
    free(g)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}

load_textures :: proc(g: ^Game) {
	f, err := os.open(TEXTURE_PATH)
	defer os.close(f)
	if err != os.ERROR_NONE {
		fmt.eprintln("Could not open textures", err)
		os.exit(1)
	}
    if entries, err := os.read_dir(f, -1); err == 0 {
        for entry in entries {
            if !entry.is_dir {
                image := rl.LoadImage(strings.clone_to_cstring(filepath.join({TEXTURE_PATH, entry.name})))
                rl.ImageResize(&image, CELL_SIZE, CELL_SIZE)
                texture := rl.LoadTextureFromImage(image)
                // Get filename without extension
                name := strings.trim_suffix(entry.name, filepath.ext(entry.name))
                g.textures[name] = texture
                rl.UnloadImage(image)
            }
        }
    }
}

load_sounds :: proc(g: ^Game) {
    f, err := os.open(SOUND_PATH)
	defer os.close(f)
	if err != os.ERROR_NONE {
		fmt.eprintln("Could not open sounds", err)
		os.exit(1)
	}
    if entries, err := os.read_dir(f, -1); err == 0 {
        for entry in entries {
            if !entry.is_dir {
                sound := rl.LoadSound(strings.clone_to_cstring(filepath.join({SOUND_PATH, entry.name})))
                // Get filename without extension
                name := strings.trim_suffix(entry.name, filepath.ext(entry.name))
                g.sounds[name] = sound
            }
        }
    }
}

run :: proc(g: ^Game) {
    rl.PlayMusicStream(g.music)

    for !rl.WindowShouldClose() {
        rl.UpdateMusicStream(g.music)

        // --- AI Turn Logic ---
        if g.state == .Running && g.turn == .Black && g.ai_player != nil {
            // It's AI's turn (Black)
            best_move := find_best_move(g.board, true) // Get the best move value

            // Find the piece that makes this move
            ai_piece: ^Piece = nil
            for piece, moves in g.possible_moves_per_piece { // Use pre-calculated moves for the turn
                 if piece.color == .Black { // Only check AI pieces
                     for &p_move in moves {
                         // Compare position and type (essential for distinguishing walk/attack etc.)
                         if p_move.position == best_move.position && p_move.type == best_move.type {
                             // Special check for castling start/end positions if needed, but type+pos is usually enough
                             ai_piece = piece
                             break
                         }
                     }
                 }
                 if ai_piece != nil {
                     break
                 }
            }


            if ai_piece != nil {
                // We found the piece and the move
                g.selected_piece = ai_piece // Set selected piece for consistency if needed
                rl.PlaySound(g.sounds["move"]) // Optional: AI move sound

                // Need a pointer to the move for do_move_on_board
                move_ptr := new(Move)
                move_ptr^ = best_move // Copy the value
                defer free(move_ptr) // Free the temporary pointer after use

                do_move_on_board(g, move_ptr) // Execute the move

                // Note: do_move_on_board now handles swap_turns internally,
                // including AI's automatic promotion.

                g.selected_piece = nil // Deselect after AI move

            } else {
                 // This case indicates an issue: AI suggested a move, but no piece can make it.
                 // Could happen if move generation/filtering differs between game and AI?
                 // Or if best_move returned was invalid (e.g., Move{} from mate/stalemate)
                 fmt.eprintf("AI Error: Could not find piece for best move: %v\n", best_move)
                 // Decide how to handle: skip turn, declare error state? For now, maybe just log.
                 // If best_move == Move{}, it likely means game should have ended, check state.
                 if best_move == (Move{}) {
                     check_for_end_of_game(g) // Re-check state
                 }
            }

        } else if g.state == .Running && g.turn == .White {
             // --- Human Turn Logic ---
             handle_input(g) // Only handle human input on White's turn
        } else if g.state == .Promotion && g.turn == .White { // Only handle human promotion for White
            handle_promotion_input(g)
        } // AI promotion is handled automatically in do_move_on_board

        // Update game time if running
        if g.state == .Running {
            g.time += rl.GetFrameTime()
        }

        // --- Rendering ---
        moves_of_selected_piece: []Move
        if g.selected_piece != nil && g.turn == .White { // Only show human moves
            // Check if the key exists before accessing
             if moves, ok := g.possible_moves_per_piece[g.selected_piece]; ok {
                 moves_of_selected_piece = moves
             }
        }

        rl.BeginDrawing()
        {
            // Only change cursor based on human interaction possibilities
            change_mouse_cursor(g.board, moves_of_selected_piece, g.turn, (g.state == .Promotion && g.turn == .White))

            rl.ClearBackground(rl.WHITE)
            render_background()
            render_pieces(g.board, g.textures)
            if g.selected_piece != nil && g.turn == .White { // Only render human moves
                render_moves_selected_piece(g.textures, moves_of_selected_piece)
            }

            // Render promotion/end screens
            if g.state == .Promotion && g.turn == .White { // Only show human promotion screen
                render_promotion_screen(g.textures, g.selected_piece.color)
            } else if g.state == .Running || g.turn == .Black { // Show info bar during AI turn too
                render_guide_text()
                render_info_bar(g.round, g.time)
            } else { // End screens (WhiteWins, BlackWins, Stalemate)
                render_end_screen(g)
            }
        }
        rl.EndDrawing()
    }
}

handle_input :: proc(g: ^Game) {
    if g.turn != .White || g.state != .Running {
        return // Only process input for White during Running state
    }
    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        mouse_pos := rl.GetMousePosition()
        mouse_pos.y -= INFO_BAR_HEIGHT
        // the x/y switch is intentional
        clicked_pos := Position{
            x = int(mouse_pos.y) / CELL_SIZE,
            y = int(mouse_pos.x) / CELL_SIZE,
        }
        clicked_piece := piece_at(g.board, clicked_pos)
        
        if clicked_piece != nil && clicked_piece.color == g.turn {
            rl.PlaySound(g.sounds["premove"])
            g.selected_piece = clicked_piece
        } else {
            desired_move := get_move_at_position(g, clicked_pos)
            if desired_move != nil && g.selected_piece != nil {
                rl.PlaySound(g.sounds["move"])
                do_move_on_board(g, desired_move)
            } else {
                rl.PlaySound(g.sounds["illegal"])
            }
            if desired_move == nil || 
               (desired_move.type != MoveType.Promotion && 
                desired_move.type != MoveType.AttackAndPromote) {
                g.selected_piece = nil
            }
        }
    }
}

handle_promotion_input :: proc(g: ^Game) {
    if g.turn != .White || g.state != .Promotion {
        return // Only process input for White during Promotion state
    }
    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        mouse_pos := rl.GetMousePosition()
        mouse_pos.y -= INFO_BAR_HEIGHT
        clicked_pos := Position{
            x = int(mouse_pos.y) / CELL_SIZE,
            y = int(mouse_pos.x) / CELL_SIZE,
        }
        if clicked_pos.x == 3 && clicked_pos.y >= 2 && clicked_pos.y <= 5 {
            new_piece: ^Piece
            pos := g.selected_piece.position
            color := g.selected_piece.color
            switch clicked_pos.y {
            case 2:
                new_piece = new_queen(pos, color)
            case 3:
                new_piece = new_rook(pos, color)
            case 4:
                new_piece = new_bishop(pos, color)
            case 5:
                new_piece = new_knight(pos, color)
            }
            rl.PlaySound(g.sounds["promote"])
            destroy_piece_at(g.board, g.selected_piece.position) // Use g.selected_piece
            add_piece(g.board, new_piece)
            g.state = .Running
            g.selected_piece = nil // Deselect piece after promotion
            swap_turns(g) // Swap turns AFTER promotion is complete
        }
    }
}

clear_map :: proc(m: ^map[^Piece][]Move) {
    for _, moves in m^ {
        delete(moves)
    }
    free(m)
}

swap_turns :: proc(g: ^Game) {
    g.turn = get_inverse_color(g.turn)
    if g.turn == .White {
        g.round += 1
    }
    calculate_all_possible_moves(g)
    check_for_end_of_game(g)
}

calculate_all_possible_moves :: proc(g: ^Game) {
    // Clear existing moves to avoid dangling pointers
    for _, moves in g.possible_moves_per_piece {
        delete(moves)
    }
    clear(&g.possible_moves_per_piece)
    
    // Calculate new moves
    pieces := get_pieces_by_color(g.board, g.turn)
    for piece in dyn.array_slice(&pieces) {
        g.possible_moves_per_piece[piece] = get_possible_moves(piece, g.board)
    }
    filter_moves_that_attack_opposite_king(g)
    filter_moves_that_lead_to_check(g)
}

// Remove moves that would capture the opponent's king (which shouldn't be possible in chess)
filter_moves_that_attack_opposite_king :: proc(using g: ^Game) {
    for piece, &moves_ptr in &possible_moves_per_piece {
        if len(moves_ptr) == 0 do continue
        // We need to iterate backwards when removing elements
        i := len(moves_ptr)-1
        for i >= 0 {
            move := moves_ptr[i]
            // Check if this is an attack move
            is_attack_move := move.type == .Attack || move.type == .AttackAndPromote
            if is_attack_move {
                attacked_piece := piece_at(board, move.position)
                if attacked_piece != nil && 
                   attacked_piece.type == PieceType.King && 
                   attacked_piece.color != turn {
                    // Remove this move using ordered remove
                    if i < len(moves_ptr)-1 {
                        copy(moves_ptr[i:], moves_ptr[i+1:])
                    }
                    moves_ptr = moves_ptr[:len(moves_ptr)-1]
                    possible_moves_per_piece[piece] = moves_ptr
                }
            }
            i -= 1
        }
    }
}

// Removes moves that would put the moving player's king in check
filter_moves_that_lead_to_check :: proc(using g: ^Game) {
    for piece, &moves_ptr in &possible_moves_per_piece {
        if len(moves_ptr) == 0 do continue
        i := len(moves_ptr)-1
        for i >= 0 {
            move := moves_ptr[i]
            // Handle castling moves specially
            if move.type == .ShortCastling || move.type == .LongCastling {
                intermediary_positions: []Position
                if move.type == .ShortCastling {
                    intermediary_positions = []Position{
                        {piece.position.x, 5},
                        {piece.position.x, 6},
                    }
                } else {
                    intermediary_positions = []Position{
                        {piece.position.x, 3},
                        {piece.position.x, 2},
                    }
                }
                // Check each intermediary position
                should_remove := false
                for pos in intermediary_positions {
                    if move_leads_to_check(board, piece, &Move{.Walk, pos}) {
                        should_remove = true
                        break
                    }
                }
                if should_remove {
                    if i < len(moves_ptr)-1 {
                        copy(moves_ptr[i:], moves_ptr[i+1:])
                    }
                    moves_ptr = moves_ptr[:len(moves_ptr)-1]
                    possible_moves_per_piece[piece] = moves_ptr
                }
            // Handle normal moves
            } else if move_leads_to_check(board, piece, &moves_ptr[i]) {
                if i < len(moves_ptr)-1 {
                    copy(moves_ptr[i:], moves_ptr[i+1:])
                }
                moves_ptr = moves_ptr[:len(moves_ptr)-1]
                possible_moves_per_piece[piece] = moves_ptr
            }
            i -= 1
        }
    }
}

get_move_at_position :: proc(g: ^Game, position: Position) -> ^Move {
    if g.selected_piece == nil {
        return nil
    }
    // Look up moves for the selected piece
    if moves, ok := g.possible_moves_per_piece[g.selected_piece]; ok {
        for &move in moves {
            if move.position == position {
                return &move
            }
        }
    }
    return nil
}

check_for_end_of_game :: proc(g: ^Game) {
    pieces_of_current_turn := get_pieces_by_color(g.board, g.turn)
    if is_board_in_check(g.board, g.turn) {
        if !is_any_move_possible(g) {
            rl.PlaySound(g.sounds["end"])
            g.state = (g.turn == .White ? .BlackWins : .WhiteWins)
        }
    } else if !is_any_move_possible(g) {
        rl.PlaySound(g.sounds["boom"])
        g.state = .Stalemate
    }
}

is_any_move_possible :: proc(g: ^Game) -> bool {
    for piece, moves in g.possible_moves_per_piece {
        if len(moves) > 0 {
            return true
        }
    }
    return false
}
