package main

import "core:math/rand"
import rl "vendor:raylib"

/*
MORE RAYLIB GO EXAMPLES ARE AVAILABLE HERE:
https://github.com/unklnik/raylib-go-more-examples

Translated to Odin
*/

NUM_STARS :: 200 // NUMBER OF STARS TO DRAW

// Global variables
stars: [NUM_STARS]Blok
direc: int         // DIRECTION
timer: i32         // CHANGE DIRECTION TIMER
fps: i32 = 60      // FRAMES PER SECOND
colors_on: bool    // COLORS ON/OFF
scr_w, scr_h: i32
max_vel: f32 = 10  // MAX SPEED FOR DETERMINING X Y MOVEMENT
vel_x, vel_y: f32  // X Y SPEED

/*
direc = direction
numbers correspond to direction of stars movement
numbers start at 1 and move clockwise

for example 2 = UP, 7 = DOWN & LEFT, 3 = UP & RIGHT, 4 = RIGHT

	1 2 3
	8   4
	7 6 5
*/

// BLOK STRUCTS THAT CONTAIN THE COLOR & POSITION
Blok :: struct {
	col:  rl.Color,
	rec:  rl.Rectangle,
	fade: f32,
}

main :: proc() {
	rl.InitWindow(0, 0, "stars background - raylib odin - translated from go example")
	scr_w, scr_h = rl.GetScreenWidth(), rl.GetScreenHeight() // GET SCREEN SIZES
	rl.SetWindowSize(scr_w, scr_h)                           // SET WINDOW SIZE

	//rl.ToggleFullscreen() // UNCOMMENT IF YOU HAVE DISPLAY ISSUES WITH OVERLAPPING WINDOW BARS

	rl.HideCursor()          // HIDES MOUSE CURSOR
	make_stars()             // FUNCTION MAKE STARS SEE END OF CODE
	direc = r_int(1, 9)      // CHOOSE INITIAL MOVEMENT DIRECTION
	vel_x = r_f32(1, max_vel) // FIND RANDOM X SPEED
	vel_y = r_f32(1, max_vel) // FIND RANDOM Y SPEED
	timer = r_i32(2, 8) * fps // SET TIMER

	camera := rl.Camera2D{} // DEFINES THE CAMERA
	camera.zoom = 1.0       // SETS CAMERA ZOOM

	rl.SetTargetFPS(fps) // NUMBER OF FRAMES DRAWN IN A SECOND

	for !rl.WindowShouldClose() {
		up_stars() // FUNCTION TO UPDATE TIMER, MOVEMENT & FADE

		if rl.IsKeyPressed(.SPACE) {
			colors_on = !colors_on // TURN COLORS ON/OFF WITH SPACE BAR
		}

		rl.BeginDrawing()

		rl.ClearBackground(rl.BLACK)

		rl.BeginMode2D(camera)

		for i in 0..<NUM_STARS { // RANGE OVER SLICE OF STAR BLOKS & DRAW
			if colors_on { // DRAW COLOR STARS
				rl.DrawRectangleRec(stars[i].rec, rl.Fade(stars[i].col, stars[i].fade))
			} else { // DRAW WHITE STARS
				rl.DrawRectangleRec(stars[i].rec, rl.Fade(rl.WHITE, stars[i].fade))
			}
		}

		rl.EndMode2D()

		rl.DrawText("press space on/off colors", 8, 12, 20, ran_col())  // TEXT FLASHING COLOR EFFECT
		rl.DrawText("press space on/off colors", 9, 11, 20, rl.BLACK)   // TEXT BLACK SHADOW
		rl.DrawText("press space on/off colors", 10, 10, 20, rl.WHITE)  // TEXT

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

up_stars :: proc() {
	timer -= 1 // DECREASE TIMER
	if timer <= 0 {
		direc = r_int(1, 9)       // CHOOSE NEW DIRECTION
		vel_x = r_f32(2, max_vel) // CHOOSE NEW X SPEED
		vel_y = r_f32(2, max_vel) // CHOOSE NEW Y SPEED
		timer = r_i32(2, 8) * fps // SET NEW TIMER
	}

	for i in 0..<NUM_STARS { // RANGE OVER SLICE OF STAR BLOKS & UPDATE
		stars[i].fade -= 0.01   // FADE OUT
		if stars[i].fade <= 0 { // IF FADE LESS THAN OR EQUALS ZERO SET NEW FADE
			stars[i].fade = r_f32(0.5, 0.9)
		}

		switch direc { // MOVE STAR REC ACCORDING TO CHOSEN DIRECTION
		case 1: // UP LEFT
			stars[i].rec.x -= vel_x
			stars[i].rec.y -= vel_y
		case 2: // UP
			stars[i].rec.y -= vel_y
		case 3: // UP RIGHT
			stars[i].rec.x += vel_x
			stars[i].rec.y -= vel_y
		case 4: // RIGHT
			stars[i].rec.x += vel_x
		case 5: // DOWN RIGHT
			stars[i].rec.x += vel_x
			stars[i].rec.y += vel_y
		case 6: // DOWN
			stars[i].rec.y += vel_y
		case 7: // DOWN LEFT
			stars[i].rec.x -= vel_x
			stars[i].rec.y += vel_y
		case 8: // LEFT
			stars[i].rec.x -= vel_x
		}

		// IF STAR REC X IS OVER SCREEN BORDER LEFT MOVE TO SCREEN BORDER RIGHT
		if stars[i].rec.x < 0 {
			stars[i].rec.x = f32(scr_w)
		}
		// IF STAR REC IS OVER SCREEN BORDER RIGHT MOVE TO SCREEN BORDER LEFT
		if stars[i].rec.x > f32(scr_w) {
			stars[i].rec.x = 0
		}
		// IF STAR REC Y IS OVER SCREEN BORDER TOP MOVE TO SCREEN BORDER BOTTOM
		if stars[i].rec.y < 0 {
			stars[i].rec.y = f32(scr_h)
		}
		// IF STAR REC IS OVER SCREEN BORDER BOTTOM MOVE TO SCREEN BORDER TOP
		if stars[i].rec.y > f32(scr_h) {
			stars[i].rec.y = 0
		}
	}
}

make_stars :: proc() {
	max_size: f32 = 8 // MAXIMUM SIZE OF RECTANGLE WIDTHS

	for i in 0..<NUM_STARS { // FILLS THE STARS ARRAY
		// CHOOSE RANDOM COLOR SEE FUNCTION END OF CODE
		stars[i].col = ran_col()
		// SET RANDOM FADE/OPACITY
		stars[i].fade = r_f32(0.5, 0.9)
		// CHOOSE RANDOM SIZE OF RECTANGLE SIDES
		width := r_f32(1, max_size)
		// CREATE THE RECTANGLE
		stars[i].rec = rl.Rectangle{
			x = r_f32(0, f32(scr_w)),
			y = r_f32(0, f32(scr_h)),
			width = width,
			height = width,
		}
	}
}

// RETURNS A RANDOM INTEGER 32
r_i32 :: proc(min, max: int) -> i32 {
	return i32(min + rand.int_max(max - min))
}

// RETURNS A RANDOM FLOAT 32
r_f32 :: proc(min, max: f32) -> f32 {
	return min + rand.float32() * (max - min)
}

// RETURNS A RANDOM COLOR
ran_col :: proc() -> rl.Color {
	return rl.Color{
		u8(r_int(0, 256)),
		u8(r_int(0, 256)),
		u8(r_int(0, 256)),
		255,
	}
}

// RETURNS A RANDOM INTEGER FOR USE IN RANDOM COLOR ABOVE
r_int :: proc(min, max: int) -> int {
	return min + rand.int_max(max - min)
}