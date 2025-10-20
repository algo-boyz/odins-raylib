package main

import rl "vendor:raylib"
import rec "../"

WIN_WIDTH: i32 = 300
WIN_HEIGHT: i32 = 300
CUT_SIZE: f32 = 30

main :: proc() {

	rl.SetTargetFPS(500)

	// toolbar is a long narrow rectangle
	toolbar := rl.Rectangle {
		x      = 0,
		y      = 0,
		width  = 300,
		height = 30,
	}

	// cut the toolbar thrice on the left and once on the right
	left_1 := rec.cut_left(&toolbar, CUT_SIZE)
	left_2 := rec.cut_left(&toolbar, CUT_SIZE)
	left_3 := rec.cut_left(&toolbar, CUT_SIZE,)
	right  := rec.cut_right(&toolbar, CUT_SIZE)

	rl.InitWindow(WIN_WIDTH, WIN_HEIGHT, "simple toolbar")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLUE)

		// draw toolbar with fill
		rl.DrawRectangleV({0, 0}, {f32(WIN_WIDTH), CUT_SIZE}, rl.PINK)

		// draw cut sections with fill
		rl.DrawRectangleV({left_1.x, left_1.y}, {left_1.width, left_1.height}, rl.RED)
		rl.DrawRectangleV({left_2.x, left_2.y}, {left_2.width, left_2.height}, rl.YELLOW)
		rl.DrawRectangleV({left_3.x, left_3.y}, {left_3.width, left_3.height}, rl.GREEN)
		rl.DrawRectangleV({right.x, right.y}, {right.width, right.height}, rl.GRAY)

		// draw separators between sections
		rl.DrawLine(
			i32(left_1.x + left_1.width),
			0,
			i32(left_1.x + left_1.width),
			i32(CUT_SIZE),
			rl.BLACK,
		)
		rl.DrawLine(
			i32(left_2.x + left_2.width),
			0,
			i32(left_2.x + left_2.width),
			i32(CUT_SIZE),
			rl.BLACK,
		)
		rl.DrawLine(
			i32(left_3.x + left_3.width),
			0,
			i32(left_3.x + left_3.width),
			i32(CUT_SIZE),
			rl.BLACK,
		)
		rl.DrawLine(i32(right.x), 0, i32(right.x), i32(CUT_SIZE), rl.BLACK)

		// draw outline
		rl.DrawRectangleLinesEx(rl.Rectangle{0, 0, 300, 30}, 1, rl.BLACK)
		rl.EndDrawing()
	}
}