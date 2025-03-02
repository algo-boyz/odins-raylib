package simon

import "core:math"
import "core:math/rand"
import "core:fmt"
import rl "vendor:raylib"

BoardTile :: struct {
	using rect:     rl.Rectangle,
	is_highlighted: bool,
}

BoardPosition :: struct {
	x, y: int,
}

GameState :: enum {
    SHOWING_SEQUENCE,
    ENTERING_ANSWER,
    WRONG_ANSWER,
    CORRECT_ANSWER
}

current_game_state : GameState = GameState.SHOWING_SEQUENCE

SCREEN_X_DIM :: 1280
SCREEN_Y_DIM :: 720
sequence_to_show: [dynamic]BoardPosition
player_entered_sequence : [dynamic]BoardPosition

should_game_run := true
BOARD_DIM :: 3
board: [BOARD_DIM][BOARD_DIM]BoardTile
game_clock : f32 = 0
sequence_started_showing_time : f32
AMOUNT_OF_TIME_TO_SHOW_SINGLE_TILE :f32 : .8
TIME_GAP_BETWEEN_TILES : f32 : .25
delay_remaining_before_next_state : f32 = 0

add_to_tile_sequence :: proc() {
	append(&sequence_to_show, BoardPosition{
        rand.int_max(BOARD_DIM), 
        rand.int_max(BOARD_DIM)
    })
}

setup_board :: proc() {
	spacing := 10
	tile_width := SCREEN_X_DIM / BOARD_DIM - spacing
	tile_height := SCREEN_Y_DIM / BOARD_DIM - spacing
	for &row, y in board {
		for &tile, x in row {
			tile.x = f32(x * tile_width + spacing)
			tile.y = f32(y * tile_height + spacing)
			tile.width = f32(tile_width - spacing)
			tile.height = f32(tile_height - spacing)
		}
	}
}

clear_tile_highlighting :: proc() {
    for &row, y in board {
		for &tile, x in row {
			tile.is_highlighted = false
		}
	}
}

main :: proc() {
	using rl

	SetConfigFlags({.VSYNC_HINT})
	InitWindow(SCREEN_X_DIM, SCREEN_Y_DIM, "Simon Game")
	SetTargetFPS(60)
	setup_board()
    add_to_tile_sequence()
    add_to_tile_sequence()
    fmt.println(sequence_to_show)
    sequence_started_showing_time = game_clock
	for should_game_run {
		if WindowShouldClose() {
			should_game_run = false
		}
        /* 
            0 to .8
            that is less than .8
            so show the first tile

            .8 to 1.6
            show the second one

            1.6 to 2.4
            show the third one
        
        */
		//update
        switch current_game_state {
        case .SHOWING_SEQUENCE:
            position_to_show := int(
                (game_clock - sequence_started_showing_time) /
                AMOUNT_OF_TIME_TO_SHOW_SINGLE_TILE
            )
            time_into_current_tile := math.mod_f32(
                (game_clock - sequence_started_showing_time),
                AMOUNT_OF_TIME_TO_SHOW_SINGLE_TILE
            )

            clear_tile_highlighting()
            if position_to_show < len(sequence_to_show) {
                if time_into_current_tile > TIME_GAP_BETWEEN_TILES {
                    tile_to_show := sequence_to_show[position_to_show]
                    board[tile_to_show.y][tile_to_show.x].is_highlighted = true
                }
            } else {
                current_game_state = .ENTERING_ANSWER
            }


        case .ENTERING_ANSWER:
            outer: for &row, y in board {
                for &tile, x in row {
                    if CheckCollisionPointRec(GetMousePosition(), tile.rect) &&
                    IsMouseButtonPressed(.LEFT) {
                        tile.is_highlighted = true
                        append(&player_entered_sequence, BoardPosition{x, y})
                        break outer
                    }
                }
            }

            if len(player_entered_sequence) > 0 && 
            player_entered_sequence[len(player_entered_sequence) - 1] !=
            sequence_to_show[len(player_entered_sequence) - 1] {
                current_game_state = .WRONG_ANSWER
                delay_remaining_before_next_state = AMOUNT_OF_TIME_TO_SHOW_SINGLE_TILE
            } else if len(player_entered_sequence) == len(sequence_to_show) {
                current_game_state = .CORRECT_ANSWER
                delay_remaining_before_next_state = AMOUNT_OF_TIME_TO_SHOW_SINGLE_TILE
            }
        case .CORRECT_ANSWER, .WRONG_ANSWER:
            delay_remaining_before_next_state -= GetFrameTime()
            if delay_remaining_before_next_state <= 0 {
                if current_game_state == .CORRECT_ANSWER {
                    add_to_tile_sequence()
                }
                current_game_state = .SHOWING_SEQUENCE
                sequence_started_showing_time = f32(GetTime())
                clear(&player_entered_sequence)
            }
        }


		//drawing
		BeginDrawing()
		ClearBackground(SKYBLUE)
		for &row, y in board {
			for &tile, x in row {
				color_to_use := RAYWHITE
                if current_game_state == .WRONG_ANSWER {
                    color_to_use = RED
                } else if current_game_state == .CORRECT_ANSWER {
                    color_to_use = GREEN
                } else if tile.is_highlighted {
                    current_tile_position := BoardPosition{x, y}
                    if current_game_state == .SHOWING_SEQUENCE ||
                    (
                        current_tile_position == 
                    player_entered_sequence[len(player_entered_sequence) - 1] &&
                     IsMouseButtonDown(.LEFT)) {
                        color_to_use = BLUE
                    }
                }
				DrawRectangleRounded(tile.rect, .3, 4, color_to_use)
				DrawRectangleRoundedLinesEx(tile.rect, .3, 4, 6, BLACK)
			}
		}

        if current_game_state == .CORRECT_ANSWER {
            text_to_show := fmt.ctprint(len(sequence_to_show))
            font_size :f32 = 40
            text_dim := MeasureTextEx(GetFontDefault(), text_to_show, font_size, 40)
            DrawText(
                text_to_show,
                i32(SCREEN_X_DIM / 2 - text_dim.x / 2),
                i32(SCREEN_Y_DIM / 2 - text_dim.y / 2),
                i32(font_size),
                BLACK
            )

        }

		EndDrawing()
        game_clock += GetFrameTime()
        free_all(context.temp_allocator)

	}
}