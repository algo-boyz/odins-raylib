package geom

import rl "vendor:raylib"

Rectangle :: struct {
    position: rl.Vector2,
    size: rl.Vector2,
}

is_point_in_rectangle :: proc(point: rl.Vector2, rect: Rectangle) -> bool {
    return point.x >= rect.position.x && 
           point.x <= rect.position.x + rect.size.x &&
           point.y >= rect.position.y && 
           point.y <= rect.position.y + rect.size.y
}
