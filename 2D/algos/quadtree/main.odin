package game

import rl "vendor:raylib"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"

ARRAY_SIZE :: 1000
QUAD_ARRAY_SIZE :: 1000  // Increased from 300 to handle more subdivisions
NUM_QUAD_POINTS :: 4
POINT_CIRCLE_MIN_SIZE :: 2
POINT_CIRCLE_MAX_SIZE :: 6

HitDirection:: enum {
	top,bottom,left,right
}

Point:: struct{
	pos: rl.Vector2,
	radius: f32,
	dir: rl.Vector2,
	color: rl.Color,
}

Rect :: struct{
	half_dimensions : rl.Vector2,
	position : rl.Vector2,
}

Quad :: struct{
	quad_rect : Rect,
	num_points : i32,
	points: [NUM_QUAD_POINTS]int,
	is_subdivide : bool,
	child_quads: [4]int,
	active: bool, // Add flag to track if quad is in use
}

quads: [QUAD_ARRAY_SIZE]Quad
points: [ARRAY_SIZE]Point
num_active_quads: int = 0 // Track number of active quads
quad_array_full: bool = false // Track if we ran out of quad space

main :: proc(){
	rl.InitWindow(1280, 720, "quatree")
	doQuads : bool = false
	dt : f32= 0.0
	fps : i32 = 0.0

	GenPoints()

	for !rl.WindowShouldClose()
	{
		dt = rl.GetFrameTime()
		fps = rl.GetFPS()
		MovePoints(dt)
		
		// Toggle between naive and quadtree collision detection
		if rl.IsKeyPressed(.SPACE){
			doQuads = !doQuads
		}
		
		if doQuads {
			QuadTreeCheckCollision()
		} else {
			NaiveCheckCollision()	
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.GRAY)

		// Draw quadtree visualization if enabled
		if doQuads {
			// Draw quad boundaries
			for i in 0..<num_active_quads {
				if quads[i].active {
					// Draw quad rectangle
					rl.DrawRectangleLines(
						cast(i32)(quads[i].quad_rect.position.x - quads[i].quad_rect.half_dimensions.x),
						cast(i32)(quads[i].quad_rect.position.y - quads[i].quad_rect.half_dimensions.y),
						cast(i32)(quads[i].quad_rect.half_dimensions.x * 2),
						cast(i32)(quads[i].quad_rect.half_dimensions.y * 2),
						rl.BLUE
					)
					
					// Draw quad center point
					rl.DrawCircle(
						cast(i32)quads[i].quad_rect.position.x,
						cast(i32)quads[i].quad_rect.position.y,
						2, rl.YELLOW
					)
					
					// Show number of points in each quad
					if quads[i].num_points > 0 {
						point_count_str := fmt.ctprintf("%d", quads[i].num_points)
						rl.DrawText(point_count_str, 
							cast(i32)(quads[i].quad_rect.position.x - 10),
							cast(i32)(quads[i].quad_rect.position.y - 10),
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
		quad_count_str := fmt.ctprintf("active quads: %d", num_active_quads)
		
		rl.DrawText(dt_str, 4, 4, 20, rl.GREEN)
		rl.DrawText(fps_str, 4, 25, 20, rl.GREEN)
		rl.DrawText(quad_count_str, 4, 46, 20, rl.GREEN)
		
		if doQuads{
			rl.DrawText("Mode: Quad Tree", 4, 67, 20, rl.GREEN)
		}else{
			rl.DrawText("Mode: Naive", 4, 67, 20, rl.GREEN)
		}
		rl.DrawText("Press SPACE to toggle", 4, 88, 16, rl.LIGHTGRAY)
		
		rl.EndDrawing()
	}
	rl.CloseWindow()
}

GenPoints :: proc()
{
	for i in 0..<ARRAY_SIZE{
		ran_y:= cast(f32)rand.int31_max(720)
		ran_x:= cast(f32)rand.int31_max(1280)
		points[i].pos.x = ran_x
		points[i].pos.y = ran_y

		ran_r := cast(f32)rand.int31_max(POINT_CIRCLE_MAX_SIZE) + POINT_CIRCLE_MIN_SIZE
		points[i].radius = ran_r

		points[i].color = rl.RED

		points[i].dir.x = cast(f32)(rand.int31_max(199)-100)/100
		points[i].dir.y = cast(f32)(rand.int31_max(199)-100)/100
	}

	// Initialize all quads as inactive
	for i in 0..<QUAD_ARRAY_SIZE{
		SetupQuad(i)
		quads[i].active = false
	}
}

SetupQuad :: proc(quad_index : int)
{
	quads[quad_index].quad_rect.position.x = 0
	quads[quad_index].quad_rect.position.y = 0
	quads[quad_index].quad_rect.half_dimensions.x = 0
	quads[quad_index].quad_rect.half_dimensions.y = 0
	quads[quad_index].num_points = 0
	quads[quad_index].points[0] = 0
	quads[quad_index].points[1] = 0
	quads[quad_index].points[2] = 0
	quads[quad_index].points[3] = 0
	quads[quad_index].is_subdivide = false
	quads[quad_index].child_quads[0] = 0
	quads[quad_index].child_quads[1] = 0
	quads[quad_index].child_quads[2] = 0
	quads[quad_index].child_quads[3] = 0
	quads[quad_index].active = false
}

MovePoints:: proc(dt : f32)
{
	for i in 0..<ARRAY_SIZE{
		points[i].pos.x += (points[i].dir.x * 100) * dt
		points[i].pos.y += (points[i].dir.y * 100) * dt
		if points[i].pos.x >= 1280.0 {
			points[i].pos.x = 1280
			points[i].dir.x = -points[i].dir.x
		}else if points[i].pos.x <= 0.0{
			points[i].pos.x = 0.0
			points[i].dir.x = -points[i].dir.x  // Fixed: was adding 1.0
		}
		if points[i].pos.y >= 720{
			points[i].pos.y = 720
			points[i].dir.y = -points[i].dir.y
		}else if points[i].pos.y <= 0{
			points[i].pos.y = 0
			points[i].dir.y = -points[i].dir.y  // Fixed: was adding 1.0
		}
	}
}

ReflectDirection:: proc(dir : rl.Vector2, hitDir:HitDirection) -> rl.Vector2
{
	n :rl.Vector2= {0.0,0.0}
	switch hitDir{
		case .top:
			n :rl.Vector2= {-1.0,0.0}
		case .bottom:
			n :rl.Vector2= {1.0,0.0}
		case .right:
			n :rl.Vector2= {0.0,-1.0}
		case .left:
			n :rl.Vector2= {0.0,1.0}
	}
	return linalg.reflect(dir,n)
}

QuadTreeCheckCollision :: proc(){
	// Reset all quads
	for i in 0..<QUAD_ARRAY_SIZE {
		quads[i].active = false
	}
	
	// Setup root quad
	SetupQuad(0)
	quads[0].quad_rect.position.x = 1280.0/2.0
	quads[0].quad_rect.position.y = 720.0/2.0
	quads[0].quad_rect.half_dimensions.x = 1280.0/2.0
	quads[0].quad_rect.half_dimensions.y = 720.0/2.0
	quads[0].num_points = 0
	quads[0].is_subdivide = false
	quads[0].active = true

	next_free_quad_index := 1
	num_active_quads = 1
	
	// Build quad tree
	for i in 0..<ARRAY_SIZE{
		BuildQuadTree(points[i],i,0,&next_free_quad_index)	
	}

	// Query quad tree for collisions
	for i in 0..<ARRAY_SIZE{
		if(QueryQuadTreeForCollision(i,0)){
			points[i].color = rl.GREEN
		}else{
			points[i].color = rl.RED
		}
	}
}

BuildQuadTree :: proc(point: Point,
	point_index : int,
	quad_index:int,
	next_free_quad_index:^int)->bool
{
	//if the point is not in the bounds of this quad return false
	if(!CheckPointInQuadBounds(quads[quad_index],point)){
		return false
	}

	//if this quad has room check if we can add it
	if(quads[quad_index].num_points < NUM_QUAD_POINTS){
		//add point to this quad and return true
		quad_point_index := quads[quad_index].num_points
		quads[quad_index].points[quad_point_index] = point_index
		quads[quad_index].num_points += 1
		return true
	}	
	
	// Only subdivide if we have enough space for 4 new quads
	if(!quads[quad_index].is_subdivide && next_free_quad_index^ + 4 < QUAD_ARRAY_SIZE){
		next_free_quad_index^ = SubdivideQuadTree(quad_index,next_free_quad_index^)
		quads[quad_index].is_subdivide = true
	}
	
	// Only try child quads if we successfully subdivided
	if quads[quad_index].is_subdivide {
		//try add point to child quads
		for i in 0..<4{
			if(BuildQuadTree(point,point_index,quads[quad_index].child_quads[i],next_free_quad_index)){
				return true
			}	
		}
	}
	
	// If we can't subdivide and quad is full, we have to force add to this quad
	// This isn't ideal but prevents crashes
	if quads[quad_index].num_points < NUM_QUAD_POINTS {
		quad_point_index := quads[quad_index].num_points
		quads[quad_index].points[quad_point_index] = point_index
		quads[quad_index].num_points += 1
		return true
	}
	
	return false
}

SubdivideQuadTree :: proc(quad_index:int, next_free_quad_index:int)-> int {
	// Check if we have enough space for 4 new quads
	if next_free_quad_index + 4 >= QUAD_ARRAY_SIZE {
		fmt.println("Warning: Not enough space in quad array for subdivision!")
		return next_free_quad_index
	}
	
	new_quad_index := next_free_quad_index
	half_x := quads[quad_index].quad_rect.half_dimensions.x / 2
	half_y := quads[quad_index].quad_rect.half_dimensions.y / 2

	//setup top left
	quads[new_quad_index].quad_rect.half_dimensions.x = half_x
	quads[new_quad_index].quad_rect.half_dimensions.y = half_y
	quads[new_quad_index].quad_rect.position.x = quads[quad_index].quad_rect.position.x - half_x
	quads[new_quad_index].quad_rect.position.y = quads[quad_index].quad_rect.position.y - half_y
	quads[new_quad_index].num_points = 0
	quads[new_quad_index].is_subdivide = false
	quads[new_quad_index].active = true
	quads[quad_index].child_quads[0] = new_quad_index
	new_quad_index += 1

	//setup top right
	quads[new_quad_index].quad_rect.half_dimensions.x = half_x
	quads[new_quad_index].quad_rect.half_dimensions.y = half_y
	quads[new_quad_index].quad_rect.position.x = quads[quad_index].quad_rect.position.x + half_x
	quads[new_quad_index].quad_rect.position.y = quads[quad_index].quad_rect.position.y - half_y
	quads[new_quad_index].num_points = 0
	quads[new_quad_index].is_subdivide = false
	quads[new_quad_index].active = true
	quads[quad_index].child_quads[1] = new_quad_index
	new_quad_index += 1

	//setup bottom left
	quads[new_quad_index].quad_rect.half_dimensions.x = half_x
	quads[new_quad_index].quad_rect.half_dimensions.y = half_y
	quads[new_quad_index].quad_rect.position.x = quads[quad_index].quad_rect.position.x - half_x
	quads[new_quad_index].quad_rect.position.y = quads[quad_index].quad_rect.position.y + half_y
	quads[new_quad_index].num_points = 0
	quads[new_quad_index].is_subdivide = false
	quads[new_quad_index].active = true
	quads[quad_index].child_quads[2] = new_quad_index
	new_quad_index += 1

	//setup bottom right
	quads[new_quad_index].quad_rect.half_dimensions.x = half_x
	quads[new_quad_index].quad_rect.half_dimensions.y = half_y
	quads[new_quad_index].quad_rect.position.x = quads[quad_index].quad_rect.position.x + half_x
	quads[new_quad_index].quad_rect.position.y = quads[quad_index].quad_rect.position.y + half_y
	quads[new_quad_index].num_points = 0
	quads[new_quad_index].is_subdivide = false
	quads[new_quad_index].active = true
	quads[quad_index].child_quads[3] = new_quad_index
	new_quad_index += 1

	// Update active quad count
	num_active_quads = new_quad_index
	
	return new_quad_index
}

QueryQuadTreeForCollision :: proc(point_index:int, quad_index:int) -> bool
{
	if !quads[quad_index].active {
		return false
	}
	
	quad := quads[quad_index]
	
	//if the point is not in the bounds of this quad return false
	if(!CheckPointInQuadBounds(quads[quad_index],points[point_index])){
		return false
	}

	//check quad points for collision
	for i in 0..<quad.num_points{
		if(quad.points[i] != point_index){
			if(CirclesIntersect(points[quad.points[i]],points[point_index])){
				return true
			}
		}
	}

	//loop and check child quads if subdivided
	if quad.is_subdivide {
		for i in 0..<4{
			if(QueryQuadTreeForCollision(point_index,quads[quad_index].child_quads[i])){
				return true
			}
		}
	}

	return false
}

NaiveCheckCollision :: proc()
{
	for i in 0..<ARRAY_SIZE{
		points[i].color = rl.RED
		for j in 0..<ARRAY_SIZE{
			if i != j{
				if(CirclesIntersect(points[i],points[j])){
					points[i].color = rl.GREEN
				}
			}
		}
	}
}

CheckPointInQuadBounds :: proc(quad : Quad, point : Point) -> bool{
	return point.pos.x <= quad.quad_rect.position.x + quad.quad_rect.half_dimensions.x &&
		point.pos.x >= quad.quad_rect.position.x - quad.quad_rect.half_dimensions.x &&
		point.pos.y >= quad.quad_rect.position.y - quad.quad_rect.half_dimensions.y &&
		point.pos.y <= quad.quad_rect.position.y + quad.quad_rect.half_dimensions.y
}

CirclesIntersect :: proc(a:Point,b:Point) -> bool {
    distance_squared := (a.pos.x - b.pos.x) * (a.pos.x - b.pos.x) + 
                        (a.pos.y - b.pos.y) * (a.pos.y - b.pos.y)
    radii_sum := a.radius + b.radius
    return distance_squared <= radii_sum * radii_sum
}