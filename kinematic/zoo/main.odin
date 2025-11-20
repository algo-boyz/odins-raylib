// main.odin
package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

import geom "../../rlutil/geom"
import "../../rlutil/gif"

PI :: math.PI
TWO_PI :: 2 * PI
FISH_BODY_COLOR :: rl.Color{58, 124, 165, 255}
FISH_FIN_COLOR  :: rl.Color{129, 195, 215, 255}

// Simplify the angle to be in the range [0, 2pi)
simplify_angle :: proc(angle: f32) -> f32 {
	a := angle
	for a >= TWO_PI {
		a -= TWO_PI
	}
	for a < 0 {
		a += TWO_PI
	}
	return a
}

// How many radians you need to turn the angle to match the anchor
relative_angle_diff :: proc(angle, anchor: f32) -> f32 {
	a := simplify_angle(angle + PI - anchor)
	return PI - a
}

// Constrain the angle to be within a certain range of the anchor
constrain_angle :: proc(angle, anchor, constraint: f32) -> f32 {
	diff := relative_angle_diff(angle, anchor)
	if abs(diff) <= constraint {
		return simplify_angle(angle)
	}

	// Reverted to match original Java source to fix oscillation
	if diff > constraint {
		return simplify_angle(anchor - constraint)
	}

	// Reverted to match original Java source
	return simplify_angle(anchor + constraint)
}

// Constrain the vector to be at a certain range of the anchor
constrain_distance :: proc(pos, anchor: rl.Vector2, constraint: f32) -> rl.Vector2 {
	return anchor + geom.vec2_set_magnitude(pos - anchor, constraint)
}


// Data Structures (Structs)

Chain :: struct {
	joints:          [dynamic]rl.Vector2,
	angles:          [dynamic]f32, // Only used for FK-style resolution
	link_size:       f32,
	angle_constraint: f32,
}

Snake :: struct {
	spine: Chain,
}

Lizard :: struct {
	spine:       Chain,
	arms:        [4]Chain,
	arm_desired: [4]rl.Vector2,
	body_width:  [14]f32,
}

Fish :: struct {
	spine:     Chain,
	body_width: [10]f32,
}

// Initialization Procedures

init_chain :: proc(origin: rl.Vector2, joint_count: int, link_size: f32, angle_constraint: f32 = f32(TWO_PI)) -> (c: Chain) {
	c.link_size = link_size
	c.angle_constraint = angle_constraint

	append(&c.joints, origin)
	append(&c.angles, 0)

	for i in 1 ..< joint_count {
		new_joint := c.joints[i-1] + rl.Vector2{0, link_size}
		append(&c.joints, new_joint)
		append(&c.angles, 0)
	}
	return c
}

init_snake :: proc(origin: rl.Vector2) -> (s: Snake) {
	s.spine = init_chain(origin, 48, 12, PI/8) // Note: Adjusted link_size for screen density
	return s
}

init_lizard :: proc(origin: rl.Vector2) -> (l: Lizard) {
	l.spine = init_chain(origin, 14, 24, PI/8) // Note: Adjusted link_size
	l.body_width = {52, 58, 40, 60, 68, 71, 65, 50, 28, 15, 11, 9, 7, 7}

	for i in 0 ..< 4 {
		link_size: f32 = 36
		if i < 2 {
			link_size = 52
		}
		l.arms[i] = init_chain(origin, 3, link_size / 2) // Adjusted link size
		l.arm_desired[i] = {0,0}
	}
	return l
}

init_fish :: proc(origin: rl.Vector2) -> (f: Fish) {
	// 12 segments for body + tail, link size 64, angle constraint PI/8
	f.spine = init_chain(origin, 12, 64, PI/8)
	f.body_width = {68, 81, 84, 83, 77, 64, 51, 38, 32, 19}
	return f
}

// Logic / Resolution Procedures

// FK-style resolver
resolve :: proc(c: ^Chain, pos: rl.Vector2) {
	c.angles[0] = geom.vec2_heading(pos - c.joints[0])
	c.joints[0] = pos

	for i in 1 ..< len(c.joints) {
		cur_angle := geom.vec2_heading(c.joints[i-1] - c.joints[i])
		c.angles[i] = constrain_angle(cur_angle, c.angles[i-1], c.angle_constraint)
		
		offset := geom.vec2_from_angle(c.angles[i])
		c.joints[i] = c.joints[i-1] - geom.vec2_set_magnitude(offset, c.link_size)
	}
}

// FABRIK resolver
fabrik_resolve :: proc(c: ^Chain, pos, anchor: rl.Vector2) {
	// Forward pass
	c.joints[0] = pos
	for i in 1 ..< len(c.joints) {
		c.joints[i] = constrain_distance(c.joints[i], c.joints[i-1], c.link_size)
	}

	// Backward pass
	c.joints[len(c.joints)-1] = anchor
	for i := len(c.joints) - 2; i >= 0; i -= 1 {
		c.joints[i] = constrain_distance(c.joints[i], c.joints[i+1], c.link_size)
	}
}

resolve_snake :: proc(s: ^Snake) {
	head_pos := s.spine.joints[0]
	mouse_pos := rl.GetMousePosition()
	target_pos := head_pos + geom.vec2_set_magnitude(mouse_pos - head_pos, 8)
	resolve(&s.spine, target_pos)
}

resolve_fish :: proc(f: ^Fish) {
	head_pos := f.spine.joints[0]
	mouse_pos := rl.GetMousePosition()
	target_pos := head_pos + geom.vec2_set_magnitude(mouse_pos - head_pos, 16)
	resolve(&f.spine, target_pos)
}

get_lizard_pos :: proc(l: ^Lizard, i: int, angle_offset, length_offset: f32) -> rl.Vector2 {
	x := l.spine.joints[i].x + math.cos(l.spine.angles[i] + angle_offset) * (l.body_width[i] + length_offset)
	y := l.spine.joints[i].y + math.sin(l.spine.angles[i] + angle_offset) * (l.body_width[i] + length_offset)
	return {x, y}
}

resolve_lizard :: proc(l: ^Lizard) {
	head_pos := l.spine.joints[0]
	mouse_pos := rl.GetMousePosition()
	target_pos := head_pos + geom.vec2_set_magnitude(mouse_pos - head_pos, 12)
	resolve(&l.spine, target_pos)

	for i in 0 ..< 4 {
		side: f32 = 1
		if i % 2 != 0 { side = -1 }
		
		body_index: int = 3
		if i >= 2 { body_index = 7 }

		angle: f32 = PI/4
		if i >= 2 { angle = PI/3 }

		desired_pos := get_lizard_pos(l, body_index, angle * side, 80)
		if rl.Vector2Distance(desired_pos, l.arm_desired[i]) > 200 {
			l.arm_desired[i] = desired_pos
		}

		foot_target := linalg.lerp(l.arms[i].joints[0], l.arm_desired[i], 0.4)
		shoulder_anchor := get_lizard_pos(l, body_index, PI/2 * side, -20)
		
		fabrik_resolve(&l.arms[i], foot_target, shoulder_anchor)
	}
}

body_width_snake :: proc(i: int) -> f32 {
	switch i {
	case 0: return 38
	case 1: return 40
	}
	return 32 - f32(i)/2
}

get_snake_pos :: proc(s: ^Snake, i: int, angle_offset, length_offset: f32) -> rl.Vector2 {
	width := body_width_snake(i)
	x := s.spine.joints[i].x + math.cos(s.spine.angles[i] + angle_offset) * (width + length_offset)
	y := s.spine.joints[i].y + math.sin(s.spine.angles[i] + angle_offset) * (width + length_offset)
	return {x, y}
}

display_snake :: proc(s: ^Snake) {
	all_points: [dynamic]rl.Vector2
	defer delete(all_points)

	// Build Body Points
	// Right half
	for i in 0 ..< len(s.spine.joints) {
		append(&all_points, get_snake_pos(s, i, PI/2, 0))
	}
	// Tail tip
	append(&all_points, get_snake_pos(s, 47, PI, 0))
	// Left half
	for i := len(s.spine.joints) - 1; i >= 0; i -= 1 {
		append(&all_points, get_snake_pos(s, i, -PI/2, 0))
	}
	// Head shaping points to close the loop (from original source)
	append(&all_points, get_snake_pos(s, 0, -PI/6, 0))
	append(&all_points, get_snake_pos(s, 0, 0, 0))
	append(&all_points, get_snake_pos(s, 0, PI/6, 0))

	// Repeat first few points to make the spline close smoothly
	if len(all_points) > 2 {
		append(&all_points, all_points[0], all_points[1], all_points[2])
	}
	
	// Draw Body
	if len(all_points) > 1 {
		// 1. Draw the outline as a thick spline
		rl.DrawSplineCatmullRom(&all_points[0], i32(len(all_points)), 24.0, rl.WHITE)
		// 2. Draw the fill as a slightly thinner spline on top
		rl.DrawSplineCatmullRom(&all_points[0], i32(len(all_points)), 20.0, {172, 57, 49, 255})
	}

	// Draw Eyes
	eye1_pos := get_snake_pos(s, 0, PI/2, -9)
	eye2_pos := get_snake_pos(s, 0, -PI/2, -9)
	rl.DrawCircleV(eye1_pos, 12, rl.WHITE)
	rl.DrawCircleV(eye2_pos, 12, rl.WHITE)
}

display_lizard :: proc(l: ^Lizard) {
	// Draw Arms
	for i in 0 ..< 4 {
		shoulder := l.arms[i].joints[2]
		foot := l.arms[i].joints[0]
		elbow := l.arms[i].joints[1]

		// Hacky correction from original code
		para := foot - shoulder
		perp := geom.vec2_set_magnitude({-para.y, para.x}, 30)
		if i == 2 {
			elbow -= perp
		} else if i == 3 {
			elbow += perp
		}

		// Draw outline
		rl.DrawLineBezier(shoulder, elbow, 20, rl.WHITE)
		rl.DrawLineBezier(elbow, foot, 20, rl.WHITE)
		// Draw fill
		rl.DrawLineBezier(shoulder, elbow, 16, {82, 121, 111, 255})
		rl.DrawLineBezier(elbow, foot, 16, {82, 121, 111, 255})
	}
	
	// Build Body Points
	body_points: [dynamic]rl.Vector2
	defer delete(body_points)

	// Right half
	for i in 0 ..< len(l.spine.joints) {
		append(&body_points, get_lizard_pos(l, i, PI/2, 0))
	}
	// Tail tip (improves shape)
	append(&body_points, get_lizard_pos(l, len(l.spine.joints)-1, PI, 0))
	// Left half
	for i := len(l.spine.joints) - 1; i >= 0; i -= 1 {
		append(&body_points, get_lizard_pos(l, i, -PI/2, 0))
	}
	// Head shaping points to close the loop (from original source)
	append(&body_points, get_lizard_pos(l, 0, -PI/6, -8))
	append(&body_points, get_lizard_pos(l, 0, 0, -6))
	append(&body_points, get_lizard_pos(l, 0, PI/6, -8))

	// Repeat first few points to make the spline close smoothly
	if len(body_points) > 2 {
		append(&body_points, body_points[0], body_points[1], body_points[2])
	}

	// Draw Body
	if len(body_points) > 1 {
		// 1. Draw the outline as a thick spline
		rl.DrawSplineCatmullRom(&body_points[0], i32(len(body_points)), 24.0, rl.WHITE)
		// 2. Draw the fill as a slightly thinner spline on top
		rl.DrawSplineCatmullRom(&body_points[0], i32(len(body_points)), 20.0, {82, 121, 111, 255})
	}

	// Draw Eyes
	eye1_pos := get_lizard_pos(l, 0, 3*PI/5, -7)
	eye2_pos := get_lizard_pos(l, 0, -3*PI/5, -7)
	rl.DrawCircleV(eye1_pos, 12, rl.WHITE)
	rl.DrawCircleV(eye2_pos, 12, rl.WHITE)
}

// Converts radians to degrees for Raylib's rotation functions
to_degrees :: proc(radians: f32) -> f32 {
	return radians * (180.0 / PI)
}

// Draw a rotated ellipse, as rl.DrawEllipsePro doesn't exist
draw_ellipse_rotated :: proc(center: rl.Vector2, radiusH, radiusV, rotation_radians: f32, color: rl.Color) {
	rlgl.PushMatrix()
	rlgl.Translatef(center.x, center.y, 0)
	rlgl.Rotatef(to_degrees(rotation_radians), 0, 0, 1)
	rlgl.Translatef(-center.x, -center.y, 0)
	rl.DrawEllipse(i32(center.x), i32(center.y), radiusH, radiusV, color)
	rlgl.PopMatrix()
}

// Draw rotated ellipse lines
draw_ellipse_lines_rotated :: proc(center: rl.Vector2, radiusH, radiusV, rotation_radians: f32, color: rl.Color) {
	rlgl.PushMatrix()
	rlgl.Translatef(center.x, center.y, 0)
	rlgl.Rotatef(to_degrees(rotation_radians), 0, 0, 1)
	rlgl.Translatef(-center.x, -center.y, 0)
	rl.DrawEllipseLines(i32(center.x), i32(center.y), radiusH, radiusV, color)
	rlgl.PopMatrix()
}

get_fish_pos :: proc(f: ^Fish, i: int, angle_offset, length_offset: f32) -> rl.Vector2 {
	// Note: body_width array only has 10 elements.
	width: f32 = 0
	if i < len(f.body_width) {
		width = f.body_width[i]
	}
	x := f.spine.joints[i].x + math.cos(f.spine.angles[i] + angle_offset) * (width + length_offset)
	y := f.spine.joints[i].y + math.sin(f.spine.angles[i] + angle_offset) * (width + length_offset)
	return {x, y}
}

display_fish :: proc(f: ^Fish) {
	// Calculations
	// Quick workaround to handle fish curving tightly.
	head_to_mid1 := relative_angle_diff(f.spine.angles[0], f.spine.angles[6])
	head_to_mid2 := relative_angle_diff(f.spine.angles[0], f.spine.angles[7])
	head_to_tail := head_to_mid1 + relative_angle_diff(f.spine.angles[6], f.spine.angles[11])

	// Draw Fins (under the body)
	// Pectoral Fins (Right & Left)
	pectoral_r_pos := get_fish_pos(f, 3, PI/3, 0)
	pectoral_l_pos := get_fish_pos(f, 3, -PI/3, 0)
	draw_ellipse_rotated(pectoral_r_pos, 80, 32, f.spine.angles[2] - PI/4, rl.WHITE)
	draw_ellipse_rotated(pectoral_l_pos, 80, 32, f.spine.angles[2] + PI/4, rl.WHITE)
	draw_ellipse_rotated(pectoral_r_pos, 76, 28, f.spine.angles[2] - PI/4, FISH_FIN_COLOR)
	draw_ellipse_rotated(pectoral_l_pos, 76, 28, f.spine.angles[2] + PI/4, FISH_FIN_COLOR)
	
	// Ventral Fins (Right & Left)
	ventral_r_pos := get_fish_pos(f, 7, PI/2, 0)
	ventral_l_pos := get_fish_pos(f, 7, -PI/2, 0)
	draw_ellipse_rotated(ventral_r_pos, 48, 16, f.spine.angles[6] - PI/4, rl.WHITE)
	draw_ellipse_lines_rotated(ventral_l_pos, 48, 16, f.spine.angles[6] + PI/4, rl.WHITE) // Using lines helper
	draw_ellipse_rotated(ventral_r_pos, 44, 12, f.spine.angles[6] - PI/4, FISH_FIN_COLOR)
	draw_ellipse_rotated(ventral_l_pos, 44, 12, f.spine.angles[6] + PI/4, FISH_FIN_COLOR)
	
	// Caudal Fin (Tail)
	caudal_points: [dynamic]rl.Vector2
	defer delete(caudal_points)
	// "Bottom" side of tail fin
	for i in 8..<12 {
		tail_width := 1.5 * head_to_tail * (f32(i) - 8) * (f32(i) - 8)
		pos := f.spine.joints[i] + geom.vec2_from_angle(f.spine.angles[i] - PI/2) * tail_width
		append(&caudal_points, pos)
	}
	// "Top" side of tail fin
	for i := 11; i >= 8; i -= 1 {
		tail_width := max(-13, min(13, head_to_tail * 6))
		pos := f.spine.joints[i] + geom.vec2_from_angle(f.spine.angles[i] + PI/2) * tail_width
		append(&caudal_points, pos)
	}
	// Close the loop and add extra points for smooth spline
	if len(caudal_points) > 2 {
		append(&caudal_points, caudal_points[0], caudal_points[1], caudal_points[2])
	}
	if len(caudal_points) > 1 {
		rl.DrawSplineCatmullRom(&caudal_points[0], i32(len(caudal_points)), 8.0, rl.WHITE)
		rl.DrawSplineCatmullRom(&caudal_points[0], i32(len(caudal_points)), 4.0, FISH_FIN_COLOR)
	}
	
	// Draw Main Body
	body_points: [dynamic]rl.Vector2
	defer delete(body_points)
	// Right half
	for i in 0..<10 {
		append(&body_points, get_fish_pos(f, i, PI/2, 0))
	}
	// Tail connector
	append(&body_points, get_fish_pos(f, 9, PI, 0))
	// Left half
	for i := 9; i >= 0; i -= 1 {
		append(&body_points, get_fish_pos(f, i, -PI/2, 0))
	}
	// Head shape
	append(&body_points, get_fish_pos(f, 0, -PI/6, 0))
	append(&body_points, get_fish_pos(f, 0, 0, 4))
	append(&body_points, get_fish_pos(f, 0, PI/6, 0))
	// Add extra points for smooth Catmull-Rom spline closure
	if len(body_points) > 2 {
		append(&body_points, body_points[0], body_points[1], body_points[2])
	}
	if len(body_points) > 1 {
		rl.DrawSplineCatmullRom(&body_points[0], i32(len(body_points)), 24.0, rl.WHITE)
		rl.DrawSplineCatmullRom(&body_points[0], i32(len(body_points)), 20.0, FISH_BODY_COLOR)
	}

	// Draw Dorsal Fin (on top of the body)
	start_pos := f.spine.joints[4]
	p1        := f.spine.joints[5]
	p2        := f.spine.joints[6]
	end_pos   := f.spine.joints[7]
	p3        := p2 + geom.vec2_from_angle(f.spine.angles[6] + PI/2) * head_to_mid2 * 16
	p4        := p1 + geom.vec2_from_angle(f.spine.angles[5] + PI/2) * head_to_mid1 * 16
	
	// Use DrawLineBezierCubic to draw the fin outline.
	// rl.DrawSplineBezierCubic(start_pos, p1, p2, 4.0, rl.WHITE) //todo wrong func signature
	// rl.DrawSplineBezierCubic(end_pos, p3, p4, 4.0, rl.WHITE)

    // Fill the shape with triangles
	rl.DrawTriangle(start_pos, end_pos, p3, FISH_FIN_COLOR)
	rl.DrawTriangle(start_pos, p4, p3, FISH_FIN_COLOR)


	// Draw Eyes
	eye1_pos := get_fish_pos(f, 0, PI/2, -18)
	eye2_pos := get_fish_pos(f, 0, -PI/2, -18)
	rl.DrawCircleV(eye1_pos, 16, rl.WHITE)
	rl.DrawCircleV(eye2_pos, 16, rl.WHITE)
	rl.DrawCircleV(eye1_pos, 8, rl.BLACK)
	rl.DrawCircleV(eye2_pos, 8, rl.BLACK)
}

Animal_Type :: enum { Snake, Lizard, Fish }

main :: proc() {
	WIDTH, HEIGHT: i32 = 1280, 720
	
	// Use HIGH_DPI for sharper rendering on supported displays
	rl.SetConfigFlags({.WINDOW_HIGHDPI, .MSAA_4X_HINT})
	rl.InitWindow(WIDTH, HEIGHT, "Creature Zoo")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	// Center point
	origin := rl.Vector2{f32(rl.GetScreenWidth())/2, f32(rl.GetScreenHeight())/2}

	// Init animals
	snake := init_snake(origin)
	lizard := init_lizard(origin)
	fish := init_fish(origin)

	current_animal: Animal_Type = .Snake
    rec := gif.new_recorder("preview.gif", 24, 600)
    defer gif.recorder_cleanup(&rec)
	for !rl.WindowShouldClose() {
		gif.recorder_update(&rec)
		if rl.IsMouseButtonPressed(.LEFT) {
			current_animal = Animal_Type( (int(current_animal) + 1) % len(Animal_Type) )
		}

		switch current_animal {
		case .Snake:
			resolve_snake(&snake)
		case .Lizard:
			resolve_lizard(&lizard)
		case .Fish:
			resolve_fish(&fish)
		}

		// Draw
		rl.BeginDrawing()
		rl.ClearBackground({40, 44, 52, 255})

		switch current_animal {
		case .Snake:
			display_snake(&snake)
		case .Lizard:
			display_lizard(&lizard)
		case .Fish:
			display_fish(&fish)
		}
		
		rl.DrawFPS(10, 10)
		rl.DrawText(fmt.ctprintf("Current Animal: %v (Click to change)", current_animal), 10, 40, 20, rl.RAYWHITE)
		rl.EndDrawing()
	}
}