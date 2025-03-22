package game

import rl "vendor:raylib"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"

ARRAY_SIZE :: 1000
QUAD_ARRAY_SIZE :: 300
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
}

quads: [QUAD_ARRAY_SIZE]Quad
points: [ARRAY_SIZE]Point

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
		if rl.IsKeyPressed(.SPACE){
			QuadTreeCheckCollision()
			//doQuads = !doQuads
		}
		NaiveCheckCollision()	
		//if !doQuads{
		//	NaiveCheckCollision(&points)	
		//}else{
		//	QuadTreeCheckCollision(&points,&quadsList)
		//}
		//QuadTreeCheckCollision()

		rl.BeginDrawing()
		rl.ClearBackground(rl.GRAY)

		for p in points{
			rl.DrawCircle(cast(i32)p.pos.x,cast(i32)p.pos.y,p.radius,p.color)
		}
		//pos_str := fmt.ctprintf("pos.x: %v, pos.y: %v - dir.x: %v, dir.y %v",points[0].pos.x,points[0].pos.y,points[0].dir.x,points[0].pos.y)
		//rl.DrawText(pos_str, 4, 4, 25, rl.GREEN)
		rl.DrawRectangle(0,0,200,100,rl.BLACK)
		dt_str := fmt.ctprintf("dt: %v", dt)
		fps_str := fmt.ctprintf("fps: %v", fps)
		rl.DrawText(dt_str, 4, 4, 25, rl.GREEN)
		rl.DrawText(fps_str, 4, 25, 25, rl.GREEN)
		if doQuads{
			rl.DrawText("Quad Tree", 4, 50, 25, rl.GREEN)
			for i in 0..<QUAD_ARRAY_SIZE{
				rl.DrawRectangleLines(cast(i32)quads[i].quad_rect.position.x,
					cast(i32)quads[i].quad_rect.position.y,
					cast(i32)quads[i].quad_rect.half_dimensions.x,
					cast(i32)quads[i].quad_rect.half_dimensions.y,
					rl.BLUE)
			}
			//fmt.println(fmt.ctprintf("x: %v",quads[0].quad_rect.position.x))

		}else{
			rl.DrawText("Naive", 4, 50, 25, rl.GREEN)
		}
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

	for i in 0..<QUAD_ARRAY_SIZE{
		SetupQuad(i)
	}
}

SetupQuad :: proc(quad_index : int)
{
	quad := quads[quad_index]
	quad.quad_rect.position.x = 0
	quad.quad_rect.position.y = 0
	quad.quad_rect.half_dimensions.x = 0
	quad.quad_rect.half_dimensions.y = 0
	quad.num_points = 0
	quad.points[0] = 0
	quad.points[1] = 0
	quad.points[2] = 0
	quad.points[3] = 0
	quad.is_subdivide = false
	quad.child_quads[0] = 0
	quad.child_quads[1] = 0
	quad.child_quads[2] = 0
	quad.child_quads[3] = 0
}

MovePoints:: proc(dt : f32)
{
	for i in 0..<ARRAY_SIZE{
		points[i].pos.x += (points[i].dir.x * 100) * dt
		points[i].pos.y += (points[i].dir.y * 100) * dt
		if points[i].pos.x >= 1280.0 {
			//p.dir = ReflectDirection(p.dir,HitDirection.right)
			points[i].pos.x = 1280
			points[i].dir.x = -points[i].dir.x
		}else if points[i].pos.x <= 0.0{
			//p.dir = ReflectDirection(p.dir,HitDirection.left)
			points[i].pos.x = 0.0
			points[i].dir.x = points[i].dir.x +1.0
		}
		if points[i].pos.y >= 720{
			//p.dir = ReflectDirection(p.dir,HitDirection.bottom)
			points[i].pos.y = 720
			points[i].dir.y = -points[i].dir.y
		}else if points[i].pos.y <= 0{
			//p.dir = ReflectDirection(p.dir,HitDirection.top)
			points[i].pos.y = 0
			points[i].dir.y = points[i].dir.y + 1.0
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
	SetupQuad(0)
	quads[0].quad_rect.position.x = 1280.0/2.0
	quads[0].quad_rect.position.y = 720.0/2.0
	quads[0].quad_rect.half_dimensions.x = 1280.0/2.0
	quads[0].quad_rect.half_dimensions.y = 720.0/2.0
	quads[0].num_points = 0
	quads[0].is_subdivide = false

	next_free_quad_index := 1
	////build quad tree
	for i in 0..<ARRAY_SIZE{
		BuildQuadTree(points[i],i,0,&next_free_quad_index)	
	}

	for i in 0..<QUAD_ARRAY_SIZE{
		fmt.println(fmt.ctprintf("half: %v, %v",quads[i].quad_rect.half_dimensions.x,quads[i].quad_rect.half_dimensions.y))
		fmt.println(fmt.ctprintf("pos: %v, %v",quads[i].quad_rect.position.x,quads[i].quad_rect.position.y))
	}
	////query quad tree
	//for i in 0..<ARRAY_SIZE{
	//	if(QueryQuadTreeForCollision(i,0)){
	//		points[i].color = rl.GREEN
	//	}else{
	//		points[i].color = rl.RED
	//	}
	//}
	
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
	
	if(!quads[quad_index].is_subdivide){
		next_free_quad_index^ = SubdivideQuadTree(quad_index,next_free_quad_index^)
		quads[quad_index].is_subdivide = true
	}
	//try add point to child quads
	for i in 0..<4{
		if(BuildQuadTree(point,point_index,quads[quad_index].child_quads[i],next_free_quad_index)){
			return true
		}	
	}
	return false
}
//TODO: need to replace the top left etc with quads[new_quad_index].
SubdivideQuadTree :: proc(quad_index:int, next_free_quad_index:int)-> int {

	fmt.println(fmt.ctprintf("next free %v",next_free_quad_index))
    
	new_quad_index := next_free_quad_index
	//TODO: print half dimensions to see if the divide is working
	//setup top left
	half_x := quads[quad_index].quad_rect.half_dimensions.x / 2
	half_y := quads[quad_index].quad_rect.half_dimensions.y / 2

	pos_x := quads[quad_index].quad_rect.position.x - half_x
	pos_y := quads[quad_index].quad_rect.position.y - half_y

	quads[new_quad_index].quad_rect.half_dimensions.x = half_x
	quads[new_quad_index].quad_rect.half_dimensions.y = half_y
	quads[new_quad_index].quad_rect.position.x = pos_x
	quads[new_quad_index].quad_rect.position.y = pos_y

	//fmt.println(fmt.ctprintf("half: %v, %v  pos: %v %v",half_x,half_y,pos_x,pos_y))
	quads[new_quad_index].num_points = 0
	quads[new_quad_index].is_subdivide = false
	quads[quad_index].child_quads[0] = new_quad_index
	new_quad_index += 1

	//setup top right
	quads[new_quad_index].quad_rect.half_dimensions.x = quads[quad_index].quad_rect.half_dimensions.x / 2
	quads[new_quad_index].quad_rect.half_dimensions.y = quads[quad_index].quad_rect.half_dimensions.y / 2
	quads[new_quad_index].quad_rect.position.x = quads[quad_index].quad_rect.position.x + quads[new_quad_index].quad_rect.half_dimensions.x
	quads[new_quad_index].quad_rect.position.y = quads[quad_index].quad_rect.position.y - quads[new_quad_index].quad_rect.half_dimensions.y
	quads[new_quad_index].num_points = 0
	quads[new_quad_index].is_subdivide = false
	quads[quad_index].child_quads[1] = new_quad_index
	new_quad_index += 1

	//setup bottom left
	quads[new_quad_index].quad_rect.half_dimensions.x = quads[quad_index].quad_rect.half_dimensions.x / 2
	quads[new_quad_index].quad_rect.half_dimensions.y = quads[quad_index].quad_rect.half_dimensions.y / 2
	quads[new_quad_index].quad_rect.position.x = quads[quad_index].quad_rect.position.x - quads[new_quad_index].quad_rect.half_dimensions.x
	quads[new_quad_index].quad_rect.position.y = quads[quad_index].quad_rect.position.y + quads[new_quad_index].quad_rect.half_dimensions.y
	quads[new_quad_index].num_points = 0
	quads[new_quad_index].is_subdivide = false
	quads[quad_index].child_quads[2] = new_quad_index
	new_quad_index += 1

	//setup bottom right
	quads[new_quad_index].quad_rect.half_dimensions.x = quads[quad_index].quad_rect.half_dimensions.x / 2
	quads[new_quad_index].quad_rect.half_dimensions.y = quads[quad_index].quad_rect.half_dimensions.y / 2
	quads[new_quad_index].quad_rect.position.x = quads[quad_index].quad_rect.position.x + quads[new_quad_index].quad_rect.half_dimensions.x
	quads[new_quad_index].quad_rect.position.y = quads[quad_index].quad_rect.position.y + quads[new_quad_index].quad_rect.half_dimensions.y
	quads[new_quad_index].num_points = 0
	quads[new_quad_index].is_subdivide = false
	quads[quad_index].child_quads[3] = new_quad_index
	new_quad_index += 1

	//return next free element
	return new_quad_index
}

QueryQuadTreeForCollision :: proc(point_index:int,
	quad_index:int) -> bool
{
	quad := quads[quad_index]
	
	//if the point is not in the bounds of this quad return false
	if(!CheckPointInQuadBounds(quads[quad_index],points[point_index])){
		return false
	}

	//check quad points fo collision
	//if point index is == quad index skip and dont check self collsion
	//if collision set red and return
	for i in 0..<quad.num_points{
		if(quad.points[i] != point_index){
			if(CirclesIntersect(points[i],points[point_index])){
				return true
			}
		}
	}

	//loop and check child quads
	for i in 0..<4{
		if(QueryQuadTreeForCollision(point_index,quads[quad_index].child_quads[i])){
			return true
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