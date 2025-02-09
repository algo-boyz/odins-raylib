package triangle

import "core:fmt"
import "core:math"
import "core:strings"

import rl "vendor:raylib"

// ported from: https://github.com/arceryz/raylib-examples

vec2 :: rl.Vector2

TriNet :: struct {
    position: vec2,
    scale: f32,
    vertices: [dynamic]vec2,
    indices: [dynamic]int,
    vertex_to_index: map[string]int,
    index_to_neighbors: map[int]map[int]int,
}

make_triangle_net :: proc() -> ^TriNet {
    net := new(TriNet)
    net.scale = 100.0
    net.vertices = make([dynamic]vec2)
    net.indices = make([dynamic]int)
    net.vertex_to_index = make(map[string]int)
    net.index_to_neighbors = make(map[int]map[int]int)
    return net
}

clear :: proc(net: ^TriNet) {
    clear(net)
}

get_vertex_key :: proc(vert: vec2) -> string {
    return fmt.tprintf("%3.3f,%3.3f", vert.x, vert.y)
}

add_triangles :: proc(net: ^TriNet, triangles: []vec2) {
    for i := 0; i < len(triangles); i += 3 {
        for j := 0; j < 3; j += 1 {
            vertex := triangles[i + j]
            key := get_vertex_key(vertex)
            // Add new vertex if key not present
            if _, ok := net.vertex_to_index[key]; !ok {
                append(&net.vertices, vertex)
                net.vertex_to_index[key] = len(net.vertices) - 1
            }
            append(&net.indices, net.vertex_to_index[key])
        }
        // Count edge occurrences
        for j := len(net.indices) - 3; j < len(net.indices); j += 1 {
            for k := len(net.indices) - 3; k < len(net.indices); k += 1 {
                if j == k do continue
                idx_j := net.indices[j]
                idx_k := net.indices[k]
                // Initialize the inner map if it doesn't exist
                if net.index_to_neighbors[idx_j] == nil {
                    net.index_to_neighbors[idx_j] = make(map[int]int)
                }
                // Get the current neighbors map
                neighbors := net.index_to_neighbors[idx_j]
                // Update the count
                neighbors[idx_k] = neighbors[idx_k] + 1
                // Reassign the updated neighbors map
                net.index_to_neighbors[idx_j] = neighbors
            }
        }
    }
}

is_edge_internal :: proc(net: ^TriNet, u, v: int) -> bool {
    if neighbors, ok := net.index_to_neighbors[u]; ok {
        if count, exists := neighbors[v]; exists {
            return count != 1
        }
    }
    return false
}

is_vertex_internal :: proc(net: ^TriNet, u: int) -> bool {
    if neighbors, ok := net.index_to_neighbors[u]; ok {
        for _, count in neighbors {
            if count < 2 do return false
        }
        return true
    }
    return false
}

transform :: proc(net: ^TriNet, vert: vec2) -> vec2 {
    scaled := vec2{vert.x * net.scale, -vert.y * net.scale}
    return vec2{scaled.x + net.position.x, scaled.y + net.position.y}
}

inv_transform :: proc(net: ^TriNet, pos: vec2) -> vec2 {
    vec := vec2{
        (pos.x - net.position.x) / net.scale,
        (pos.y - net.position.y) / net.scale,
    }
    return vec2{vec.x, -vec.y}
}

get_nearest_vertex :: proc(net: ^TriNet, pos: vec2, dist: f32) -> vec2 {
    min_dist := f32(99999)
    min_vert := pos
    for vert in net.vertices {
        curr_dist := rl.Vector2Distance(pos, vert)
        if curr_dist < min_dist {
            min_dist = curr_dist
            min_vert = vert
        }
    }
    return min_dist < dist ? min_vert : pos
}

draw :: proc(net: ^TriNet, external, internal: rl.Color) {
    for i := 0; i < len(net.indices); i += 3 {
        for j := 0; j < 3; j += 1 {
            i1 := net.indices[i + j]
            i2 := net.indices[i + (j + 1) % 3]
            v1 := transform(net, net.vertices[i1])
            v2 := transform(net, net.vertices[i2])
            color := is_edge_internal(net, i1, i2) ? internal : external
            rl.DrawLineV(v1, v2, color)
        }
    }
    for i := 0; i < len(net.vertices); i += 1 {
        pos := transform(net, net.vertices[i])
        color := is_vertex_internal(net, i) ? internal : external
        rl.DrawCircleV(pos, 3, color)
    }
}

draw_polygon :: proc(net: ^TriNet, verts: []vec2, color: rl.Color, until := -1) {
    end := until < 0 ? len(verts) : until
    // Draw vertices
    for i := 0; i <= end && i < len(verts); i += 1 {
        rl.DrawCircleV(transform(net, verts[i]), 4, color)
    }
    // Draw edges
    for i := 0; i < end; i += 1 {
        v1 := transform(net, verts[i])
        v2 := transform(net, verts[(i + 1) % len(verts)])
        rl.DrawLineV(v1, v2, color)
    }
}

draw_labels :: proc(net: ^TriNet, size: f32, color: rl.Color) {
    for i := 0; i < len(net.vertices); i += 1 {
        pos := transform(net, net.vertices[i])
        text := fmt.tprintf("%d", i)
        rl.DrawText(strings.clone_to_cstring(text), i32(pos.x), i32(pos.y), i32(size), color)
    }
    // Draw edge counters
    for idx1, neighbors in net.index_to_neighbors {
        for idx2, count in neighbors {
            if count == 0 do continue
            
            pos1 := net.vertices[idx1]
            pos2 := net.vertices[idx2]
            
            dir := (pos2 - pos1) * 0.3
            text_pos := transform(net, pos1 + dir)
            
            text := fmt.tprintf("%d", count)
            rl.DrawText(strings.clone_to_cstring(text), 
                       i32(text_pos.x), i32(text_pos.y), 
                       i32(size * 0.5), color)
        }
    }
}

get_polygon :: proc(net: ^TriNet) -> []vec2 {
    // Find starting vertex
    current_vertex := 0
    for i := 0; i < len(net.vertices); i += 1 {
        if !is_vertex_internal(net, i) {
            current_vertex = i
            break
        }
    }
    seen := make(map[int]bool)
    list := make([dynamic]vec2)
    
    for i := 0; i < len(net.vertices); i += 1 {
        seen[current_vertex] = true
        append(&list, net.vertices[current_vertex])
        next_vertex := -1
        if neighbors, ok := net.index_to_neighbors[current_vertex]; ok {
            for idx, count in neighbors {
                if count == 1 && !seen[idx] {
                    next_vertex = idx
                    break
                }
            }
        }
        if next_vertex == -1 do break
        current_vertex = next_vertex
    }
    
    return list[:]
}