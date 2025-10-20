package nodes

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

// Edge represents a connection between nodes
Edge :: struct {
    target: ^Node,
    cost:   f32,
}

// Node represents a pathfinding node
Node :: struct {
    position:    rl.Vector2,
    connections: [dynamic]Edge,
    g_score:     f32,
    previous:    ^Node,
}

// NodeMap manages the grid of pathfinding nodes
NodeMap :: struct {
    width:     int,
    height:    int,
    cell_size: f32,
    nodes:     []^Node,
}

// Constructor equivalent - initialize a new NodeMap
create :: proc() -> NodeMap {
    return NodeMap{
        width     = 0,
        height    = 0,
        cell_size = 0,
        nodes     = nil,
    }
}

// Destructor equivalent - cleanup allocated memory
destroy :: proc(nm: ^NodeMap) {
    if nm.nodes != nil {
        for node in nm.nodes {
            if node != nil {
                delete(node.connections)
                free(node)
            }
        }
        delete(nm.nodes)
    }
}

// Init the NodeMap from ASCII map data
init :: proc(nm: ^NodeMap, ascii_map: []string, cell_size: int) {
    nm.cell_size = f32(cell_size)
    EMPTY_SQUARE :: '0'
    
    // Set map dimensions
    nm.height = len(ascii_map)
    if nm.height == 0 {
        return
    }
    nm.width = len(ascii_map[0])
    
    // Allocate memory for nodes
    nm.nodes = make([]^Node, nm.width * nm.height)
    
    // Create nodes based on ASCII map
    for y in 0..<nm.height {
        line := ascii_map[y]
        
        // Check for mismatched line lengths
        if len(line) != nm.width {
            fmt.printf("Mismatched line #%d in ASCII map (%d instead of %d)\n", 
                      y, len(line), nm.width)
        }
        for x in 0..<nm.width {
            tile := EMPTY_SQUARE
            if x < len(line) {
                tile = rune(line[x])
            }
            index := x + nm.width * y
            
            // Create nodes for tiles that are not empty
            if tile == EMPTY_SQUARE {
                nm.nodes[index] = nil
            } else {
                node := new(Node)
                node.position.x = (f32(x) + 0.5) * nm.cell_size
                node.position.y = (f32(y) + 0.5) * nm.cell_size
                node.connections = make([dynamic]Edge)
                node.g_score = math.F32_MAX
                node.previous = nil
                nm.nodes[index] = node
            }
        }
    }
    // Establish connections between adjacent nodes
    for y in 0..<nm.height {
        for x in 0..<nm.width {
            node := get_node(nm, x, y)
            if node != nil {
                // Connect to west neighbor
                if x > 0 {
                    node_west := get_node(nm, x - 1, y)
                    if node_west != nil {
                        connect(node, node_west, 1.0)
                        connect(node_west, node, 1.0)
                    }
                }
                // Connect to south neighbor
                if y > 0 {
                    node_south := get_node(nm, x, y - 1)
                    if node_south != nil {
                        connect(node, node_south, 1.0)
                        connect(node_south, node, 1.0)
                    }
                }
            }
        }
    }
}

// Connect one node to another
connect :: proc(node: ^Node, other: ^Node, cost: f32) {
    edge := Edge{
        target = other,
        cost   = cost,
    }
    append(&node.connections, edge)
}

// Get node at grid coordinates
get_node :: proc(nm: ^NodeMap, x, y: int) -> ^Node {
    if x < 0 || x >= nm.width || y < 0 || y >= nm.height {
        return nil
    }
    return nm.nodes[x + nm.width * y]
}

// Draw the NodeMap
draw :: proc(nm: ^NodeMap) {
    CELL_COLOR :: rl.Color{255, 0, 0, 255}    // Red for blocks
    LINE_COLOR :: rl.Color{128, 128, 128, 255} // Grey for connections
    
    for y in 0..<nm.height {
        for x in 0..<nm.width {
            node := get_node(nm, x, y)
            if node == nil {
                // Draw blocked cell
                rl.DrawRectangle(
                    i32(f32(x) * nm.cell_size),
                    i32(f32(y) * nm.cell_size),
                    i32(nm.cell_size - 1),
                    i32(nm.cell_size - 1),
                    CELL_COLOR
                )
            } else {
                // Draw connections between nodes
                for connection in node.connections {
                    other := connection.target
                    rl.DrawLine(
                        i32(node.position.x),
                        i32(node.position.y),
                        i32(other.position.x),
                        i32(other.position.y),
                        LINE_COLOR
                    )
                }
            }
        }
    }
}

// Dijkstra's pathfinding algo
astar :: proc(nm: ^NodeMap, start_pos: rl.Vector2, end_node: ^Node) -> [dynamic]^Node {
    start_node := closest_node(nm, start_pos)
    if start_node == nil || end_node == nil {
        fmt.eprintln("Error: Start or End node is null.")
        return make([dynamic]^Node)
    }
    if start_node == end_node {
        return make([dynamic]^Node) // Return empty path if start == end
    }
    // Reset all nodes
    for node in nm.nodes {
        if node != nil {
            node.g_score = math.F32_MAX
            node.previous = nil
        }
    }
    start_node.g_score = 0
    start_node.previous = nil
    
    open_list := make([dynamic]^Node)
    closed_list := make([dynamic]^Node)
    defer delete(open_list)
    defer delete(closed_list)
    
    append(&open_list, start_node)
    
    for len(open_list) > 0 {
        // Sort open_list by g_score
        slice.sort_by(open_list[:], proc(a, b: ^Node) -> bool {
            return a.g_score < b.g_score
        })
        current_node := open_list[0]
        if current_node == end_node {
            break
        }
        ordered_remove(&open_list, 0)
        append(&closed_list, current_node)
        
        for connection in current_node.connections {
            target_node := connection.target
            
            // Check if target_node is not in closed_list
            found_in_closed := false
            for closed_node in closed_list {
                if closed_node == target_node {
                    found_in_closed = true
                    break
                }
            }
            if !found_in_closed {
                g_score := current_node.g_score + connection.cost
                
                // Check if target_node is in open_list
                found_in_open := false
                for open_node in open_list {
                    if open_node == target_node {
                        found_in_open = true
                        break
                    }
                }
                if !found_in_open {
                    target_node.g_score = g_score
                    target_node.previous = current_node
                    append(&open_list, target_node)
                } else if g_score < target_node.g_score {
                    target_node.g_score = g_score
                    target_node.previous = current_node
                }
            }
        }
    }
    // Reconstruct path
    path := make([dynamic]^Node)
    current_node := end_node
    
    for current_node != nil {
        inject_at(&path, 0, current_node)
        current_node = current_node.previous
    }
    // Remove redundant first node if it doubles back
    if len(path) > 1 {
        agent_direction := rl.Vector2Normalize(start_pos - path[0].position)
        node_direction := rl.Vector2Normalize(path[1].position - path[0].position)
        
        if rl.Vector2DotProduct(agent_direction, node_direction) > 0.99 {
            ordered_remove(&path, 0)
        }
    }
    return path
}

// Draw a path
draw_path :: proc(path: [dynamic]^Node, line_color: rl.Color) {
    for i in 1..<len(path) {
        node_a := path[i - 1]
        node_b := path[i]
        
        if node_a != nil && node_b != nil {
            rl.DrawLine(
                i32(node_a.position.x),
                i32(node_a.position.y),
                i32(node_b.position.x),
                i32(node_b.position.y),
                line_color
            )
        }
    }
}

// Get the closest node to a world position
closest_node :: proc(nm: ^NodeMap, world_pos: rl.Vector2) -> ^Node {
    i := int(world_pos.x / nm.cell_size)
    j := int(world_pos.y / nm.cell_size)
    
    if i < 0 || i >= nm.width || j < 0 || j >= nm.height {
        fmt.eprintf("Error: Clicked position is out of bounds: (%f, %f)\n", 
                   world_pos.x, world_pos.y)
        return nil
    }
    return get_node(nm, i, j)
}

// Get a random valid node
random_node :: proc(nm: ^NodeMap) -> ^Node {    
    for {
        x := rand.int_max(nm.width)
        y := rand.int_max(nm.height)
        node := get_node(nm, x, y)
        if node != nil {
            return node
        }
    }
}