package astar

import "core:math"
import rl "vendor:raylib"

Node :: struct {
    index:    [3]i32,
    position: [3]f32,
    g_score:  f32,
    f_score:  f32,
    parent:   ^Node,
    state:    NodeState,
    time:     f32,
    time_idx: i32,
}

NodeState :: enum {
    NOT_EXPANDED,
    IN_OPEN_SET,
    IN_CLOSE_SET,
}

// Hash table to store expanded nodes
Nodes :: struct {
    data_3d: map[[3]i32]^Node,
    data_4d: map[[4]i32]^Node,
}

AStar :: struct {
    // Path finding params
    resolution:       f32,
    time_resolution:  f32,
    lambda_heuristic: f32,
    margin:           f32,
    tie_breaker:      f32,
    // Map params
    origin:    [3]f32,
    map_size:  [3]f32,
    time_origin: f32,
    // Search state
    nodes:           [dynamic]^Node,
    expanded_nodes:  Nodes,
    open_set:        [dynamic]^Node,
    path_nodes:      [dynamic]^Node,
    has_path:        bool,
}

init :: proc(a: ^AStar, resolution, time_resolution, lambda_heu, margin: f32) {
    a.resolution = resolution
    a.time_resolution = time_resolution
    a.lambda_heuristic = lambda_heu
    a.margin = margin
    a.tie_breaker = 1.0 + 1.0/10000.0
    // Init dynamic arrays
    a.nodes = make([dynamic]^Node)
    a.open_set = make([dynamic]^Node)
    a.path_nodes = make([dynamic]^Node)
    // Init hash tables
    a.expanded_nodes.data_3d = make(map[[3]i32]^Node)
    a.expanded_nodes.data_4d = make(map[[4]i32]^Node)
}

destroy :: proc(a: ^AStar) {
    for node in a.nodes {
        free(node)
    }
    delete(a.nodes)
    delete(a.open_set)
    delete(a.path_nodes)
    delete(a.expanded_nodes.data_3d)
    delete(a.expanded_nodes.data_4d)
}

reset :: proc(a: ^AStar) {
    clear(&a.expanded_nodes.data_3d)
    clear(&a.expanded_nodes.data_4d)
    clear(&a.open_set)
    clear(&a.path_nodes)
    for node in a.nodes {
        node.parent = nil
        node.state = .NOT_EXPANDED
    }
}

pos_to_idx :: proc(a: ^AStar, pos: [3]f32) -> [3]i32 {
    return [3]i32{
        i32(math.floor((pos.x - a.origin.x) / a.resolution)),
        i32(math.floor((pos.y - a.origin.y) / a.resolution)),
        i32(math.floor((pos.z - a.origin.z) / a.resolution)),
    }
}

// Heuristic flavors
euclidean_heuristic :: proc(a: ^AStar, x1, x2: [3]f32) -> f32 {
    dx := x2.x - x1.x
    dy := x2.y - x1.y
    dz := x2.z - x1.z
    return a.tie_breaker * math.sqrt_f32(dx*dx + dy*dy + dz*dz)
}

manhattan_heuristic :: proc(a: ^AStar, x1, x2: [3]f32) -> f32 {
    dx := x2.x - x1.x
    dy := x2.y - x1.y
    dz := x2.z - x1.z
    return a.tie_breaker * (abs(dx) + abs(dy) + abs(dz))
}

diagonal_heuristic :: proc(a: ^AStar, x1, x2: [3]f32) -> f32 {
    dx := abs(x1.x - x2.x)
    dy := abs(x1.y - x2.y)
    dz := abs(x1.z - x2.z)
    h: f32
    diag := min(min(dx, dy), dz)
    dx -= diag
    dy -= diag
    dz -= diag
    if dx < 1e-4 {
        h = 1.0 * math.sqrt_f32(3.0) * diag + math.sqrt_f32(2.0) * min(dy, dz) + 1.0 * abs(dy - dz)
    }
    if dy < 1e-4 {
        h = 1.0 * math.sqrt_f32(3.0) * diag + math.sqrt_f32(2.0) * min(dx, dz) + 1.0 * abs(dx - dz)
    }
    if dz < 1e-4 {
        h = 1.0 * math.sqrt_f32(3.0) * diag + math.sqrt_f32(2.0) * min(dx, dy) + 1.0 * abs(dx - dy)
    }
    return a.tie_breaker * h
}

Result :: enum {
    PATH_FOUND,
    PATH_NOT_FOUND,
}

// search for path from start to end
search :: proc(m: ^Map) -> Result {
    a := &m.astar
    reset(a)
    dyn := false
    time_start:f32 = -1.0
    // Init start node
    start_node := new(Node)
    append(&a.nodes, start_node)
    start_node.position = m.start_pos
    start_node.index = pos_to_idx(a, m.start_pos)
    start_node.g_score = 0
    start_node.f_score = a.lambda_heuristic * euclidean_heuristic(a, m.start_pos, m.end_pos)
    start_node.state = NodeState.IN_OPEN_SET
    if dyn {
        a.time_origin = time_start
        start_node.time = time_start
        start_node.time_idx = i32((time_start - a.time_origin) / a.time_resolution)
        a.expanded_nodes.data_4d[[4]i32{start_node.index.x, start_node.index.y, start_node.index.z, start_node.time_idx}] = start_node
    } else {
        a.expanded_nodes.data_3d[start_node.index] = start_node
    }
    append(&a.open_set, start_node)
    end_index := pos_to_idx(a, m.end_pos)
    // search loop
    for len(a.open_set) > 0 {
        // Get node with lowest f_score
        current := pop_min_f_score(&a.open_set)
        current.state = NodeState.IN_CLOSE_SET
        // Check if we reached the end
        if abs(current.index.x - end_index.x) <= 1 &&
           abs(current.index.y - end_index.y) <= 1 &&
           abs(current.index.z - end_index.z) <= 1 {
            retrieve_path(a, current)
            a.has_path = true
            return Result.PATH_FOUND
        }
        // or expand neighbors
        for dx := -a.resolution; dx <= a.resolution + 1e-3; dx += a.resolution {
            for dy := -a.resolution; dy <= a.resolution + 1e-3; dy += a.resolution {
                for dz := -a.resolution; dz <= a.resolution + 1e-3; dz += a.resolution {
                    if abs(dx) < 1e-3 && abs(dy) < 1e-3 && abs(dz) < 1e-3 do continue
                    neighbor_pos := [3]f32{
                        current.position.x + dx,
                        current.position.y + dy,
                        current.position.z + dz,
                    }
                    // Check if in bounds
                    if !is_pos_valid(m, neighbor_pos) do continue
                    neighbor_index := pos_to_idx(a, neighbor_pos)
                    // Check if in closed set
                    if dyn {
                        neighbor_time := current.time + 1.0
                        neighbor_time_idx := i32((neighbor_time - a.time_origin) / a.time_resolution)
                        if node, ok := a.expanded_nodes.data_4d[[4]i32{neighbor_index.x, neighbor_index.y, neighbor_index.z, neighbor_time_idx}]; 
                           ok && node.state == NodeState.IN_CLOSE_SET {
                            continue
                        }
                    } else {
                        if node, ok := a.expanded_nodes.data_3d[neighbor_index]; 
                           ok && node.state == NodeState.IN_CLOSE_SET {
                            continue
                        }
                    }
                    // Compute scores
                    tentative_g_score := current.g_score + math.sqrt(dx*dx + dy*dy + dz*dz)
                    tentative_f_score := tentative_g_score + a.lambda_heuristic * euclidean_heuristic(a, neighbor_pos, m.end_pos)
                    // Create or update neighbor
                    neighbor: ^Node
                    if dyn {
                        neighbor_time := current.time + 1.0
                        neighbor_time_idx := i32((neighbor_time - a.time_origin) / a.time_resolution)
                        neighbor = a.expanded_nodes.data_4d[[4]i32{neighbor_index.x, neighbor_index.y, neighbor_index.z, neighbor_time_idx}]
                    } else {
                        neighbor = a.expanded_nodes.data_3d[neighbor_index]
                    }
                    if neighbor == nil {
                        neighbor = new(Node)
                        append(&a.nodes, neighbor)
                        neighbor.position = neighbor_pos
                        neighbor.index = neighbor_index
                        neighbor.g_score = tentative_g_score
                        neighbor.f_score = tentative_f_score
                        neighbor.parent = current
                        neighbor.state = .IN_OPEN_SET
                        if dyn {
                            neighbor.time = current.time + 1.0
                            neighbor.time_idx = i32((neighbor.time - a.time_origin) / a.time_resolution)
                            a.expanded_nodes.data_4d[[4]i32{neighbor_index.x, neighbor_index.y, neighbor_index.z, neighbor.time_idx}] = neighbor
                        } else {
                            a.expanded_nodes.data_3d[neighbor_index] = neighbor
                        }
                        append(&a.open_set, neighbor)
                    } else if neighbor.state == .IN_OPEN_SET && tentative_g_score < neighbor.g_score {
                        neighbor.g_score = tentative_g_score
                        neighbor.f_score = tentative_f_score
                        neighbor.parent = current
                        if dyn do neighbor.time = current.time + 1.0
                    }
                }
            }
        }
    }
    return Result.PATH_NOT_FOUND
}

is_pos_valid :: proc(m: ^Map, pos: [3]f32) -> bool {
    // Check if position is within grid bounds
    if pos.x < 0 || pos.x >= f32(m.grid_size) ||
       pos.z < 0 || pos.z >= f32(m.grid_size) {
        return false
    }
    // Check if position collides with obstacles
    for obstacle in m.obstacles {
        if math.abs(pos.x - obstacle.x) < 1.0 &&
           math.abs(pos.z - obstacle.z) < 1.0 {
            return false
        }
    }
    return true
}

retrieve_path :: proc(a: ^AStar, end_node: ^Node) {
    current := end_node
    for current != nil {
        append(&a.path_nodes, current)
        current = current.parent
    } // Reverse path
    for i := 0; i < len(a.path_nodes)/2; i += 1 {
        j := len(a.path_nodes) - 1 - i
        a.path_nodes[i], a.path_nodes[j] = a.path_nodes[j], a.path_nodes[i]
    }
}

// get and remove node with minimum f_score from open set
pop_min_f_score :: proc(open_set: ^[dynamic]^Node) -> ^Node {
    if len(open_set) == 0 do return nil
    min_idx := 0
    min_f_score := open_set[0].f_score
    for i := 1; i < len(open_set); i += 1 {
        if open_set[i].f_score < min_f_score {
            min_idx = i
            min_f_score = open_set[i].f_score
        }
    }
    node := open_set[min_idx]
    ordered_remove(open_set, min_idx)
    return node
}