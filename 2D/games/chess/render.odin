package chess

import "core:fmt"
import "core:math"
import rl "vendor:raylib"


render_background :: proc() {
    for i := 0; i < 8; i += 1 {
        for j := 0; j < 8; j += 1 {
            x := j * CELL_SIZE
            y := i * CELL_SIZE + INFO_BAR_HEIGHT
            cell_color := get_shade_color(get_color_of_cell(Position{i, j}))
            rl.DrawRectangle(i32(x), i32(y), CELL_SIZE, CELL_SIZE, cell_color)
        }
    }
}

render_pieces :: proc(board: ^Board, textures: map[string]rl.Texture2D) {
    for i := 0; i < 8; i += 1 {
        for j := 0; j < 8; j += 1 {
            piece := piece_at(board, Position{i, j})
            if piece != nil {
                rl.DrawTexture(
                    textures[piece.name], 
                    i32(j * CELL_SIZE),  // j is the column (x-coordinate)
                    i32(i * CELL_SIZE + INFO_BAR_HEIGHT),  // i is the row (y-coordinate)
                    rl.WHITE
                )
            }
        }
    }
}

render_moves_selected_piece :: proc(textures: map[string]rl.Texture2D, possible_moves: []Move) {
    for move in possible_moves {
        texture_name := get_texture_name_from_move_type(move.type)
        rl.DrawTexture(
            textures[texture_name],
            i32(move.position.y * CELL_SIZE),
            i32(move.position.x * CELL_SIZE + INFO_BAR_HEIGHT),
            rl.WHITE,
        )
    }
}

render_guide_text :: proc() {
    padding := 3
    character_size := 10
    // Render 1-8 numbers (rows)
    for i := 0; i < 8; i += 1 {
        rl.DrawText(fmt.ctprintf("%d", i + 1), 
            i32(padding),
            i32(i * CELL_SIZE + padding + INFO_BAR_HEIGHT),
            20,
            get_shade_color(get_inverse_color(get_color_of_cell(Position{i, 0}))))
    }
    // Render h-a characters (columns)
    for j := 0; j < 8; j += 1 {
        text := fmt.ctprintf("%c", 'a' + (7 - j))
        rl.DrawText(text,
            i32((j + 1) * CELL_SIZE - character_size - padding),
            i32(WINDOW_HEIGHT - f32(character_size) * 1.75 - f32(padding)),
            20, 
            get_shade_color(get_inverse_color(get_color_of_cell(Position{7, j}))))
    }
}

render_promotion_screen :: proc(textures: map[string]rl.Texture2D, color_of_peon: PieceColor) {
    rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Color{0, 0, 0, 127})
    rl.DrawText("Promotion", WINDOW_WIDTH / 2 - 98, WINDOW_HEIGHT / 4, 40, rl.WHITE)
    texture_name: string
    defer delete(texture_name)
    x:i32
    // Draw promotion pieces
    for i := 0; i < 4; i += 1 {
        x = CELL_SIZE * i32(i + 2)
        texture_name = fmt.tprintf("%s%s", 
            color_of_peon == .White ? "w" : "b",
            piece_options[i].suffix)
        rl.DrawTexture(
            textures[texture_name],
            x,
            CELL_SIZE * 3 + INFO_BAR_HEIGHT,
            rl.WHITE)
        rl.DrawText(
            piece_options[i].name,
            x + piece_options[i].x_offset,
            CELL_SIZE * 4 + 5 + INFO_BAR_HEIGHT,
            20,
            rl.WHITE,
        )
    }
}

render_info_bar :: proc(round: int, time: f32) {
    rl.DrawRectangle(0, 0, WINDOW_WIDTH, INFO_BAR_HEIGHT, rl.BLACK)
    round_text := fmt.ctprintf("Round: %d", round)
    time_text := fmt.ctprintf("Time: %.0f", time)
    time_text_width := int(rl.MeasureText(time_text, 20))
    padding:i32 = 5
    rl.DrawText(round_text, padding, INFO_BAR_HEIGHT / 2 - 10, 20, rl.WHITE)
    rl.DrawText(time_text, i32(WINDOW_WIDTH - time_text_width) - padding, INFO_BAR_HEIGHT / 2 - 10, 20, rl.WHITE)
}

render_end_screen :: proc(g: ^Game) {
    rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Color{0, 0, 0, 127})
    text: cstring
    #partial switch g.state {
    case .WhiteWins:
        text = "White wins"
    case .BlackWins:
        text = "Black wins"
    case .Stalemate:
        text = "Stalemate"
    case:
        return
    }
    text_length := rl.MeasureText(text, 40)
    rl.DrawText(text, WINDOW_WIDTH / 2 - text_length / 2, WINDOW_HEIGHT / 2, 40, rl.WHITE)
}

change_mouse_cursor :: proc(board: ^Board, possible_moves: []Move, turn: PieceColor, in_promotion: bool) {
    mouse_position := rl.GetMousePosition()
    mouse_position.y -= INFO_BAR_HEIGHT
    hover_position := Position{
        x = int(mouse_position.y) / CELL_SIZE,
        y = int(mouse_position.x) / CELL_SIZE,
    }
    if !in_promotion {
        piece := piece_at(board, hover_position)
        is_hovering_over_piece := piece != nil && piece.color == turn
        is_hovering_over_move := false
        for move in possible_moves {
            if move.position == hover_position {
                is_hovering_over_move = true
                break
            }
        }
        if is_hovering_over_piece || is_hovering_over_move {
            rl.SetMouseCursor(.POINTING_HAND)
        } else {
            rl.SetMouseCursor(.DEFAULT)
        }
    } else {
        // If in promotion screen, set pointer if hovering over options
        if hover_position.x == 3 && hover_position.y >= 2 && hover_position.y <= 5 {
            rl.SetMouseCursor(.POINTING_HAND)
        }
    }
}