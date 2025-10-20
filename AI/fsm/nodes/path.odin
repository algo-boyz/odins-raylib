package nodes

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Path :: struct {
    pos:       rl.Vector2,
    curr_node: ^Node,
    path:      [dynamic]^Node,
    curr_idx:  int,
    speed:     f32,
}

new_path :: proc() -> Path {
    return Path{
        pos       = {},
        curr_node = nil,
        path      = make([dynamic]^Node),
        curr_idx  = 0,
        speed     = 100,
    }
}

destroy_path :: proc(pa: ^Path) {
    delete(pa.path)
}

set_node :: proc(pa: ^Path, node: ^Node) {
    if node == nil {
        fmt.eprintln("Error: Attempted to set a null node.")
        return
    }
    pa.curr_node = node
    pa.pos = node.position
}

set_speed :: proc(pa: ^Path, speed: f32) {
    pa.speed = speed
}

update_path :: proc(pa: ^Path, delta_time: f32) {
    if len(pa.path) == 0 {
        return
    }
    next_node := pa.path[pa.curr_idx]
    if next_node == nil {
        fmt.eprintln("Error: Next node in the path is null.")
        return
    }
    direction := next_node.position - pa.pos
    distance := math.sqrt(direction.x * direction.x + direction.y * direction.y)
    if distance == 0 {
        pa.curr_idx += 1
        return
    }
    // Normalize the direction vector
    unit_direction := direction / distance
    // Calculate distance after movement
    distance_after_move := distance - pa.speed * delta_time
    
    if distance_after_move > 0 {
        // Still moving towards the target node
        pa.pos += unit_direction * pa.speed * delta_time
    } else {
        // Agent has reached or overshot the node
        pa.curr_idx += 1
        
        if pa.curr_idx >= len(pa.path) {
            // Reached the end of the path
            pa.pos = next_node.position
            pa.curr_node = next_node
            clear(&pa.path)
        } else {
            // Move to the next node and handle overshoot
            pa.pos = next_node.position
            new_next_node := pa.path[pa.curr_idx]
            if new_next_node == nil {
                fmt.eprintln("Error: New next node is null.")
                return
            }
            // Calculate overshoot distance
            overshoot_distance := -distance_after_move
            // Calculate new direction
            new_direction := new_next_node.position - next_node.position
            new_length := math.sqrt(new_direction.x * new_direction.x + new_direction.y * new_direction.y)
            if new_length > 0 {
                new_unit_direction := new_direction / new_length
                pa.pos += new_unit_direction * overshoot_distance
            }
        }
    }
}

go_to :: proc(pa: ^Path, start, end: ^Node, node_map: ^NodeMap) {
    if end == nil {
        fmt.eprintln("Error: Destination node is null.")
        return
    }
    if start == end {
        return // Arrived at destination
    }
    // Calculate path using A* search
    pa.path = astar(node_map, start.position, end)
    if len(pa.path) == 0 {
        fmt.eprintln("Error: No path found from start to end.")
        fmt.eprintf("Start Node: (%f, %f)\n", start.position.x, start.position.y)
        fmt.eprintf("End Node: (%f, %f)\n", end.position.x, end.position.y)
        return
    }
    pa.curr_idx = 0
}

clear_path :: proc(pa: ^Path) {
    clear(&pa.path)
}

path_position :: proc(pa: ^Path) -> rl.Vector2 {
    return pa.pos
}

get_path :: proc(pa: ^Path) -> [dynamic]^Node {
    return pa.path
}