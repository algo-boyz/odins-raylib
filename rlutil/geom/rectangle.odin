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

rectangle_overlap_x :: proc(a, b: rl.Rectangle) -> bool {
    if a.y < b.y + b.height && a.y + a.height > b.y {
        return true
    }
    return false
}

rectangle_intersects :: proc(rec1, rec2: rl.Rectangle) -> bool {
    return ( rec1.x <= rec2.x + rec2.width && rec1.x + rec1.width >= rec2.x && 
            rec1.y <= rec2.y + rec2.height && rec1.y + rec1.height >= rec2.y )
}
