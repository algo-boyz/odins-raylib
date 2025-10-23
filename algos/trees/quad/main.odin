package quad

import rl "vendor:raylib"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"

LEN :: 1000
NUM_POINTS :: 4
POINT_MIN_SIZE :: 2
POINT_MAX_SIZE :: 6

HitDirection:: enum { top, bottom, left, right }

Point:: struct{
	radius: f32,
	color: rl.Color,
	pos, dir: rl.Vector2,
}

Rect :: struct{
	half_dims, pos : rl.Vector2,
}

Quad :: struct{
	quad_rect : Rect,
	num_points : i32,
	points: [NUM_POINTS]int,
	is_subdivide : bool,
	child_quads: [4]int,
	active: bool, // Track if quad is in use
}
quads: [LEN]Quad
points: [LEN]Point
num_active: int // Track number of active quads
is_full: bool   // Track if we ran out of quad space

main :: proc(){
	rl.InitWindow(1280, 720, "quatree")
	do_quads: bool
	dt: f32
	fps: i32
	gen_points()

	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()
		fps = rl.GetFPS()
		move(dt)
		// Toggle between naive and quadtree collision detection
		if rl.IsKeyPressed(.SPACE){
			do_quads = !do_quads
		}
		if do_quads {
			on_collision()
		} else {
			collide_simple()	
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.GRAY)
		// Draw quadtree visualization if enabled
		if do_quads {
			// Draw quad boundaries
			for i in 0..<num_active {
				if quads[i].active {
					// Draw quad rectangle
					rl.DrawRectangleLines(
						cast(i32)(quads[i].quad_rect.pos.x - quads[i].quad_rect.half_dims.x),
						cast(i32)(quads[i].quad_rect.pos.y - quads[i].quad_rect.half_dims.y),
						cast(i32)(quads[i].quad_rect.half_dims.x * 2),
						cast(i32)(quads[i].quad_rect.half_dims.y * 2),
						rl.BLUE
					)
					// Draw quad center point
					rl.DrawCircle(
						cast(i32)quads[i].quad_rect.pos.x,
						cast(i32)quads[i].quad_rect.pos.y,
						2, rl.YELLOW
					)
					// Show number of points in each quad
					if quads[i].num_points > 0 {
						point_count_str := fmt.ctprintf("%d", quads[i].num_points)
						rl.DrawText(point_count_str, 
							cast(i32)(quads[i].quad_rect.pos.x - 10),
							cast(i32)(quads[i].quad_rect.pos.y - 10),
							12, rl.WHITE
						)
					}
				}
			}
		}
		// Draw points
		for p in points{
			rl.DrawCircle(cast(i32)p.pos.x,cast(i32)p.pos.y,p.radius,p.color)
		}
		// Draw UI
		rl.DrawRectangle(0,0,250,120,rl.BLACK)
		dt_str := fmt.ctprintf("dt: %.3f", dt)
		fps_str := fmt.ctprintf("fps: %v", fps)
		quad_count_str := fmt.ctprintf("active quads: %d", num_active)
		
		rl.DrawText(dt_str, 4, 4, 20, rl.GREEN)
		rl.DrawText(fps_str, 4, 25, 20, rl.GREEN)
		rl.DrawText(quad_count_str, 4, 46, 20, rl.GREEN)
		if do_quads{
			rl.DrawText("Mode: Quad Tree", 4, 67, 20, rl.GREEN)
		}else{
			rl.DrawText("Mode: Naive", 4, 67, 20, rl.GREEN)
		}
		rl.DrawText("Press SPACE to toggle", 4, 88, 16, rl.LIGHTGRAY)
		rl.EndDrawing()
	}
	rl.CloseWindow()
}

gen_points :: proc() {
	for i in 0..<LEN{
		ran_y:= cast(f32)rand.int31_max(720)
		ran_x:= cast(f32)rand.int31_max(1280)
		points[i].pos.x = ran_x
		points[i].pos.y = ran_y
		ran_r := cast(f32)rand.int31_max(POINT_MAX_SIZE) + POINT_MIN_SIZE
		points[i].radius = ran_r
		points[i].color = rl.RED
		points[i].dir.x = cast(f32)(rand.int31_max(199)-100)/100
		points[i].dir.y = cast(f32)(rand.int31_max(199)-100)/100
	}
	// Init all quads as inactive
	for i in 0..<LEN{
		init_quad(i)
		quads[i].active = false
	}
}

init_quad :: proc(idx : int) {
	quads[idx].quad_rect.pos.x = 0
	quads[idx].quad_rect.pos.y = 0
	quads[idx].quad_rect.half_dims.x = 0
	quads[idx].quad_rect.half_dims.y = 0
	quads[idx].num_points = 0
	quads[idx].points[0] = 0
	quads[idx].points[1] = 0
	quads[idx].points[2] = 0
	quads[idx].points[3] = 0
	quads[idx].is_subdivide = false
	quads[idx].child_quads[0] = 0
	quads[idx].child_quads[1] = 0
	quads[idx].child_quads[2] = 0
	quads[idx].child_quads[3] = 0
	quads[idx].active = false
}

move:: proc(dt : f32) {
	for i in 0..<LEN{
		points[i].pos.x += (points[i].dir.x * 100) * dt
		points[i].pos.y += (points[i].dir.y * 100) * dt
		if points[i].pos.x >= 1280 {
			points[i].pos.x = 1280
			points[i].dir.x = -points[i].dir.x
		}else if points[i].pos.x <= 0{
			points[i].pos.x = 0
			points[i].dir.x = -points[i].dir.x  // Fixed: was adding 1
		}
		if points[i].pos.y >= 720{
			points[i].pos.y = 720
			points[i].dir.y = -points[i].dir.y
		}else if points[i].pos.y <= 0{
			points[i].pos.y = 0
			points[i].dir.y = -points[i].dir.y  // Fixed: was adding 1
		}
	}
}

reflect_dir:: proc(dir : rl.Vector2, hit:HitDirection) -> (n: rl.Vector2) {
	switch hit{
		case .top:
			n = {-1, 0 }
		case .bottom:
			n = { 1, 0 }
		case .right:
			n = { 0,-1 }
		case .left:
			n = { 0, 1 }
	}
	return linalg.reflect(dir,n)
}

on_collision :: proc(){
	// Reset quads
	for i in 0..<LEN {
		quads[i].active = false
	}
	// Root quad
	init_quad(0)
	quads[0].quad_rect.pos.x = 1280/2
	quads[0].quad_rect.pos.y = 720/2
	quads[0].quad_rect.half_dims.x = 1280/2
	quads[0].quad_rect.half_dims.y = 720/2
	quads[0].num_points = 0
	quads[0].is_subdivide = false
	quads[0].active = true

	next_free_quad_idx := 1
	num_active = 1
	
	// Build tree
	for i in 0..<LEN{
		build_tree(points[i],i,0,&next_free_quad_idx)	
	}
	// Query tree for collisions
	for i in 0..<LEN{
		if(collide(i,0)){
			points[i].color = rl.GREEN
		}else{
			points[i].color = rl.RED
		}
	}
}

build_tree :: proc(point: Point, point_idx, quad_idx:int, next_free_quad_idx:^int) -> bool {
	//if the point is not in the bounds of this quad return false
	if !point_in_bounds(quads[quad_idx],point) {
		return false
	}
	//if this quad has room check if we can add it
	if quads[quad_idx].num_points < NUM_POINTS {
		//add point to this quad and return true
		quad_point_idx := quads[quad_idx].num_points
		quads[quad_idx].points[quad_point_idx] = point_idx
		quads[quad_idx].num_points += 1
		return true
	}	
	// Only subdivide if we have enough space for 4 new quads
	if !quads[quad_idx].is_subdivide && next_free_quad_idx^ + 4 < LEN {
		next_free_quad_idx^ = subdivide(quad_idx,next_free_quad_idx^)
		quads[quad_idx].is_subdivide = true
	}
	// Only try child quads if we successfully subdivided
	if quads[quad_idx].is_subdivide {
		// Try add point to child quads
		for i in 0..<4{
			if build_tree(point,point_idx,quads[quad_idx].child_quads[i],next_free_quad_idx) {
				return true
			}	
		}
	}
	// If we can't subdivide and quad is full, we have to force add to this quad
	// This isn't ideal but prevents crashes
	if quads[quad_idx].num_points < NUM_POINTS {
		quad_point_idx := quads[quad_idx].num_points
		quads[quad_idx].points[quad_point_idx] = point_idx
		quads[quad_idx].num_points += 1
		return true
	}
	return false
}

subdivide :: proc(quad_idx:int, next_free_quad_idx:int)-> int {
	// Check enough space for 4 new quads exists
	if next_free_quad_idx + 4 >= LEN {
		fmt.println("Warning: Not enough space in quad array for subdivision!")
		return next_free_quad_idx
	}
	new_quad_idx := next_free_quad_idx
	half_x := quads[quad_idx].quad_rect.half_dims.x / 2
	half_y := quads[quad_idx].quad_rect.half_dims.y / 2
	// Top left
	quads[new_quad_idx].quad_rect.half_dims.x = half_x
	quads[new_quad_idx].quad_rect.half_dims.y = half_y
	quads[new_quad_idx].quad_rect.pos.x = quads[quad_idx].quad_rect.pos.x - half_x
	quads[new_quad_idx].quad_rect.pos.y = quads[quad_idx].quad_rect.pos.y - half_y
	quads[new_quad_idx].num_points = 0
	quads[new_quad_idx].is_subdivide = false
	quads[new_quad_idx].active = true
	quads[quad_idx].child_quads[0] = new_quad_idx
	new_quad_idx += 1
	// Top right
	quads[new_quad_idx].quad_rect.half_dims.x = half_x
	quads[new_quad_idx].quad_rect.half_dims.y = half_y
	quads[new_quad_idx].quad_rect.pos.x = quads[quad_idx].quad_rect.pos.x + half_x
	quads[new_quad_idx].quad_rect.pos.y = quads[quad_idx].quad_rect.pos.y - half_y
	quads[new_quad_idx].num_points = 0
	quads[new_quad_idx].is_subdivide = false
	quads[new_quad_idx].active = true
	quads[quad_idx].child_quads[1] = new_quad_idx
	new_quad_idx += 1
	// Bottom left
	quads[new_quad_idx].quad_rect.half_dims.x = half_x
	quads[new_quad_idx].quad_rect.half_dims.y = half_y
	quads[new_quad_idx].quad_rect.pos.x = quads[quad_idx].quad_rect.pos.x - half_x
	quads[new_quad_idx].quad_rect.pos.y = quads[quad_idx].quad_rect.pos.y + half_y
	quads[new_quad_idx].num_points = 0
	quads[new_quad_idx].is_subdivide = false
	quads[new_quad_idx].active = true
	quads[quad_idx].child_quads[2] = new_quad_idx
	new_quad_idx += 1
	// Bottom right
	quads[new_quad_idx].quad_rect.half_dims.x = half_x
	quads[new_quad_idx].quad_rect.half_dims.y = half_y
	quads[new_quad_idx].quad_rect.pos.x = quads[quad_idx].quad_rect.pos.x + half_x
	quads[new_quad_idx].quad_rect.pos.y = quads[quad_idx].quad_rect.pos.y + half_y
	quads[new_quad_idx].num_points = 0
	quads[new_quad_idx].is_subdivide = false
	quads[new_quad_idx].active = true
	quads[quad_idx].child_quads[3] = new_quad_idx
	new_quad_idx += 1
	// Update active quad count
	num_active = new_quad_idx
	
	return new_quad_idx
}

collide :: proc(point_idx, quad_idx:int) -> bool {
	if !quads[quad_idx].active {
		return false
	}
	quad := quads[quad_idx]
	if !point_in_bounds(quads[quad_idx],points[point_idx]) {
		return false
	}
	// Check points for collision
	for i in 0..<quad.num_points{
		if quad.points[i] != point_idx {
			if intersects(points[quad.points[i]],points[point_idx]) {
				return true
			}
		}
	}
	// Check child quads if subdivided
	if quad.is_subdivide {
		for i in 0..<4{
			if collide(point_idx,quads[quad_idx].child_quads[i]) {
				return true
			}
		}
	}
	return false
}

collide_simple :: proc() {
	for i in 0..<LEN{
		points[i].color = rl.RED
		for j in 0..<LEN{
			if i != j{
				if intersects(points[i],points[j]) {
					points[i].color = rl.GREEN
				}
			}
		}
	}
}

point_in_bounds :: proc(quad: Quad, point: Point) -> bool{
	return point.pos.x <= quad.quad_rect.pos.x + quad.quad_rect.half_dims.x &&
		point.pos.x >= quad.quad_rect.pos.x - quad.quad_rect.half_dims.x &&
		point.pos.y >= quad.quad_rect.pos.y - quad.quad_rect.half_dims.y &&
		point.pos.y <= quad.quad_rect.pos.y + quad.quad_rect.half_dims.y
}

intersects :: proc(a, b: Point) -> bool {
    distance_squared := (a.pos.x - b.pos.x) * (a.pos.x - b.pos.x) + (a.pos.y - b.pos.y) * (a.pos.y - b.pos.y)
    sum := a.radius + b.radius
    return distance_squared <= sum * sum
}