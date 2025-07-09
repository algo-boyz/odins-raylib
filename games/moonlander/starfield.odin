package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

// --- Starfield Simulation Constants and Structs ---
NUM_STARS :: 200     // NUMBER OF STARS TO DRAW
BASE_MAX_VEL :: 1.8 
VELOCITY_LEVEL_MULTIPLIER :: 0.10 // Each level increases speed by 10%
MAX_VELOCITY_MULTIPLIER :: 4.0 // Caps the speed at 4x the base for high levels
fps :: 60 // FRAMES PER SECOND

// Blok struct contains the color & position for a single star
Blok :: struct {
	col:  rl.Color,
	rec:  rl.Rectangle,
	fade: f32,
}

/*
direc = direction
numbers correspond to direction of stars movement, starting at 1 and moving clockwise.
    1 2 3
    8   4
    7 6 5
*/
Starfield :: struct {
	stars:     [NUM_STARS]Blok,
	direc:     int,
	vel_x:     f32,
	vel_y:     f32,
	colors_on: bool,
}

// Returns a random integer
r_int :: proc(min, max: int) -> int {
	return min + rand.int_max(max - min)
}

// Returns a random float32
r_f32 :: proc(min, max: f32) -> f32 {
	return min + rand.float32() * (max - min)
}

// Returns a random color
ran_col :: proc() -> rl.Color {
	return rl.Color{u8(r_int(0, 256)), u8(r_int(0, 256)), u8(r_int(0, 256)), 255}
}

randomize_starfield_movement :: proc(sf: ^Starfield, level: int) {
	sf.direc = r_int(1, 9)

	// Velocity now increases with each level.
	level_multiplier := 1.0 + f32(level - 1) * VELOCITY_LEVEL_MULTIPLIER
    // Cap the multiplier to prevent excessive speed at high levels.
    if level_multiplier > MAX_VELOCITY_MULTIPLIER {
        level_multiplier = MAX_VELOCITY_MULTIPLIER
    }

	base_min_vel: f32 = 0.2
	
	// Apply the multiplier to the base velocity range
	sf.vel_x = r_f32(base_min_vel * level_multiplier, BASE_MAX_VEL * level_multiplier)
	sf.vel_y = r_f32(base_min_vel * level_multiplier, BASE_MAX_VEL * level_multiplier)
}

init_starfield :: proc(width, height: int) -> ^Starfield {
	sf := new(Starfield)
	sf.colors_on = true
	max_size: f32 = 3.0

	for i in 0 ..< NUM_STARS {
		sf.stars[i].col = ran_col()
		sf.stars[i].fade = r_f32(0.5, 0.9)
		w := r_f32(1, max_size)
		sf.stars[i].rec = rl.Rectangle{
			x      = r_f32(0, f32(width)),
			y      = r_f32(0, f32(height)),
			width  = w,
			height = w,
		}
	}
	return sf
}

update_starfield :: proc(g: ^Game) {
	sf := g.starfield
	scr_w, scr_h := screen_width, screen_height

    // Timer logic removed. Direction and velocity are constant for the level.
	for i in 0 ..< NUM_STARS {
		sf.stars[i].fade -= 0.005 // Slower fade for a more persistent look
		if sf.stars[i].fade <= 0 {
			sf.stars[i].fade = r_f32(0.5, 0.9)
		}

		switch sf.direc {
		case 1: sf.stars[i].rec.x -= sf.vel_x; sf.stars[i].rec.y -= sf.vel_y
		case 2: sf.stars[i].rec.y -= sf.vel_y
		case 3: sf.stars[i].rec.x += sf.vel_x; sf.stars[i].rec.y -= sf.vel_y
		case 4: sf.stars[i].rec.x += sf.vel_x
		case 5: sf.stars[i].rec.x += sf.vel_x; sf.stars[i].rec.y += sf.vel_y
		case 6: sf.stars[i].rec.y += sf.vel_y
		case 7: sf.stars[i].rec.x -= sf.vel_x; sf.stars[i].rec.y += sf.vel_y
		case 8: sf.stars[i].rec.x -= sf.vel_x
		}

		if sf.stars[i].rec.x < 0 { sf.stars[i].rec.x = f32(scr_w) }
		if sf.stars[i].rec.x > f32(scr_w) { sf.stars[i].rec.x = 0 }
		if sf.stars[i].rec.y < 0 { sf.stars[i].rec.y = f32(scr_h) }
		if sf.stars[i].rec.y > f32(scr_h) { sf.stars[i].rec.y = 0 }
	}
}

draw_starfield :: proc(g: ^Game) {
	sf := g.starfield
	for i in 0 ..< NUM_STARS {
		if sf.colors_on {
			rl.DrawRectangleRec(sf.stars[i].rec, rl.Fade(sf.stars[i].col, sf.stars[i].fade))
		} else {
			rl.DrawRectangleRec(sf.stars[i].rec, rl.Fade(rl.WHITE, sf.stars[i].fade))
		}
	}
}



