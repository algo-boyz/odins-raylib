package blockmath

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

DEBUG_UI_SIZE :: 100
WINDOW_WIDTH :: 1000
WINDOW_HEIGHT :: 1000

BLOCK_SIZE :: 10 * 20
CELLS_IN_ROW :: WINDOW_WIDTH / BLOCK_SIZE
CELLS_IN_COL :: WINDOW_HEIGHT / BLOCK_SIZE

blocks: [CELLS_IN_ROW * CELLS_IN_COL]u8
player_px_pos := rl.Vector2{WINDOW_WIDTH / 2 - BLOCK_SIZE / 2, WINDOW_HEIGHT / 2 - BLOCK_SIZE / 2}
player_pos := rl.Vector2 {
	math.floor(player_px_pos.x / BLOCK_SIZE),
	math.floor(player_px_pos.x / BLOCK_SIZE),
}
player_vel := rl.Vector2{0, 0}

btn_pressed: bool
mouse_pos: rl.Vector2
mouse_px_pos: rl.Vector2

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}
		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track)
	}

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT + DEBUG_UI_SIZE, "Block math")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)

	setup()

	for !rl.WindowShouldClose() {
		process_input()
		update()
		render()
	}
}

setup :: proc() {
	for _, i in blocks {
		blocks[i] = 1
	}
	// for b, i in blocks {
	// 	fmt.printf("%d [%d] ", i, b)
	// }
}

process_input :: proc() {
	btn_pressed = rl.IsMouseButtonPressed(.LEFT)
	mouse_px_pos = rl.GetMousePosition()
}

update :: proc() {
	// Calculate the mouse's grid location
	mouse_pos.x = math.floor(mouse_px_pos.x / BLOCK_SIZE)
	mouse_pos.y = math.floor(mouse_px_pos.y / BLOCK_SIZE)

	if btn_pressed {
		player_px_pos = mouse_px_pos
	}
}

render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	for y in i32(0) ..< CELLS_IN_COL {
		for x in i32(0) ..< CELLS_IN_ROW {
			// Calculate block pixel position
			px: i32 = x * BLOCK_SIZE
			py: i32 = y * BLOCK_SIZE

			// Calculate player grid location
			player_pos.x = math.floor(player_px_pos.x / BLOCK_SIZE)
			player_pos.y = math.floor(player_px_pos.y / BLOCK_SIZE)

			// Calculate player centre grid location
			player_px_centre := player_px_pos.x + BLOCK_SIZE / 2
			player_py_centre := player_px_pos.y + BLOCK_SIZE / 2

			// Draw a line from the centre of the player in pixel position 
			start_px_pos := rl.Vector2{player_px_centre, player_py_centre}

			// Calculate starting point's grid location
			// Note: Only used for debug label
			start_pos := rl.Vector2 {
				math.floor(start_px_pos.x / BLOCK_SIZE),
				math.floor(start_px_pos.y / BLOCK_SIZE),
			}

			/*
			 *   mouse_px_pos (b)
			 *                \          |
			 *                  \        |
			 *        end_pos (c) \______|
			 *                      \    |
			 *                        \ .θ.,
			 *                          \|__.
			 *   a-c = line_len          start_px_pos (a)
			 */
			line_len: f32 = 200
			theta := math.atan2(mouse_px_pos.y - start_px_pos.y, mouse_px_pos.x - start_px_pos.x)

			end_pos := rl.Vector2 {
				// Ax + cos(θ) * line_len
				start_px_pos.x + math.cos(theta) * line_len,
				// Ay + sin(θ) * line_len
				start_px_pos.y + math.sin(theta) * line_len,
			}

			// Calculate the target/end position's grid location
			target_pos := rl.Vector2 {
				math.floor(end_pos.x / BLOCK_SIZE),
				math.floor(end_pos.y / BLOCK_SIZE),
			}

			// Draw blocks
			if i32(target_pos.x) == x && i32(target_pos.y) == y {
				rl.DrawRectangleV({f32(px), f32(py)}, {BLOCK_SIZE, BLOCK_SIZE}, rl.PINK)
				rl.DrawRectangleLines(px, py, BLOCK_SIZE, BLOCK_SIZE, rl.DARKPURPLE)
			} else {
				rl.DrawRectangleV({f32(px), f32(py)}, {BLOCK_SIZE, BLOCK_SIZE}, rl.LIGHTGRAY)
				rl.DrawRectangleLines(px, py, BLOCK_SIZE, BLOCK_SIZE, rl.DARKGRAY)
			}

			// Calculate the current block's index in array
			i := y * CELLS_IN_ROW + x

			// Draw block labels
			rl.DrawText(
				fmt.ctprint(i),
				i32(px) + BLOCK_SIZE / 2 - (BLOCK_SIZE / 3 / 3),
				i32(py) + BLOCK_SIZE / 2 - (BLOCK_SIZE / 3 / 3),
				BLOCK_SIZE / 3,
				rl.BLACK,
			)
			rl.DrawText(fmt.ctprintf("%d:%d", x, y), px + 5, py + 5, BLOCK_SIZE / 5, rl.DARKGRAY)

			// Draw player
			rl.DrawRectangleV(player_px_pos, {BLOCK_SIZE, BLOCK_SIZE}, {200, 122, 255, 15})

			// Draw look line
			rl.DrawLineEx(start_px_pos, end_pos, 5, rl.DARKPURPLE)

			// Draw debug UI
			font_size := i32(15)

			rl.DrawText(
				fmt.ctprintf(
					"player_px_pos: %v\nplayer-px_pos_CEN: %v\nplayer_pos-xy: %v",
					player_px_pos,
					rl.Vector2{player_px_centre, player_py_centre},
					player_pos,
				),
				10,
				WINDOW_HEIGHT + 10,
				font_size,
				rl.RAYWHITE,
			)

			rl.DrawText(
				fmt.ctprintf(
					"start_pos-pxy: %v\nstart_pos-xy: %v\nend_pos pxy: %v",
					start_px_pos,
					start_pos,
					end_pos,
				),
				240,
				WINDOW_HEIGHT + 10,
				font_size,
				rl.RAYWHITE,
			)

			rl.DrawText(
				fmt.ctprintf(
					"CELLS_IN_ROW: %v\nCELLS_IN_COL: %v\nBLOCK_SIZE: %v",
					CELLS_IN_ROW,
					CELLS_IN_COL,
					BLOCK_SIZE,
				),
				440,
				WINDOW_HEIGHT + 10,
				font_size,
				rl.RAYWHITE,
			)

			rl.DrawText(
				fmt.ctprintf("mouse_px_pos: %v\nmouse_pos: %v", mouse_px_pos, mouse_pos),
				590,
				WINDOW_HEIGHT + 10,
				font_size,
				rl.RAYWHITE,
			)
		}
	}

	rl.EndDrawing()
}