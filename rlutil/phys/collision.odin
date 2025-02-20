package phys

import rl "vendor:raylib"

CollisionSide :: enum {
	None,
	Top,
	Bottom,
	Left,
	Right,
}

Entity2D :: struct {
	pos:   rl.Vector2,
	size:  rl.Vector2,
	color: rl.Color,
	speed: f32,
}

get_collision_side :: proc(e1, e2: Entity2D) -> CollisionSide {
	if is_entity_collision2d(e1, e2) {
		overlap_left := e1.pos.x + e1.size.x - e2.pos.x
		overlap_right := e2.pos.x + e2.size.x - e1.pos.x
		overlap_top := e1.pos.y + e1.size.y - e2.pos.y
		overlap_bottom := e2.pos.y + e2.size.y - e1.pos.y

		min_overlap_x := min(overlap_left, overlap_right)
		min_overlap_y := min(overlap_top, overlap_bottom)

		if min_overlap_x < min_overlap_y {
			if overlap_left > 0 && overlap_right > e2.size.x {
				return .Right
			} else {
				return .Left
			}
		} else {
			if overlap_top > 0 && overlap_bottom > e2.size.y {
				return .Top
			} else {
				return .Bottom
			}
		}
	}
	return .None
}

is_entity_collision2d :: proc(e1, e2: Entity2D) -> bool {
	r1 := rl.Rectangle{
		width  = e1.size.x,
		height = e1.size.y,
		x      = e1.pos.x,
		y      = e1.pos.y,
	}
	r2 := rl.Rectangle{
		width  = e2.size.x,
		height = e2.size.y,
		x      = e2.pos.x,
		y      = e2.pos.y,
	}
	return rl.CheckCollisionRecs(r1, r2)
}

get_collision_entity2d :: proc(e1, e2: Entity2D) -> rl.Rectangle {
	rect1 := rl.Rectangle{
		width  = e1.size.x,
		height = e1.size.y,
		x      = e1.pos.x,
		y      = e1.pos.y,
	}
	rect2 := rl.Rectangle{
		width  = e2.size.x,
		height = e2.size.y,
		x      = e2.pos.x,
		y      = e2.pos.y,
	}

	return rl.GetCollisionRec(rect1, rect2)
}