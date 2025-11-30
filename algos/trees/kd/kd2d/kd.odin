package kd2d

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:sync"

// 2D Cartesian k-d tree that uses Euclidean distance
Node :: struct {
    x:   f32,
    y:   f32,
    data:  rawptr,
    left:  ^Node,
    right: ^Node,
    axis:  int, // 0 for x, 1 for y
}

Tree :: struct {
    root:   ^Node,
    destr:  proc(data: rawptr),
    mutex:  sync.Mutex,
}

Result :: struct {
    x:      f32,
    y:      f32,
    data:     rawptr,
    distance: f32,
}

// Create a new 2D k-d tree
create :: proc(allocator := context.allocator) -> (tree: Tree) {
    context.allocator = allocator
    tree.root = nil
    tree.destr = nil
    return tree
}

// Insert point into the 2D k-d tree
insert :: proc(tree: ^Tree, x, y: f32, data: rawptr) -> bool {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    insert_recursive :: proc(node: ^^Node, x, y: f32, data: rawptr, depth: int) {
        if node^ == nil {
            node^ = new(Node)
            node^.x = x
            node^.y = y
            node^.data = data
            node^.axis = depth % 2
            node^.left = nil
            node^.right = nil
            return
        }
        current := node^
        next_depth := depth + 1
        
        if current.axis == 0 { // Split on x
            if x < current.x {
                insert_recursive(&current.left, x, y, data, next_depth)
            } else {
                insert_recursive(&current.right, x, y, data, next_depth)
            }
        } else { // Split on y
            if y < current.y {
                insert_recursive(&current.left, x, y, data, next_depth)
            } else {
                insert_recursive(&current.right, x, y, data, next_depth)
            }
        }
    }
    insert_recursive(&tree.root, x, y, data, 0)
    return true
}

// Find nearest neighbor in 2D k-d tree
nearest :: proc(tree: ^Tree, target_x, target_y: f32) -> (Result, bool) {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    if tree.root == nil {
        return {}, false
    }
    best_res := Result{
        distance = math.F32_MAX,
    }

    nearest_recursive :: proc(node: ^Node, target_x, target_y: f32, best: ^Result, depth: int) {
        if node == nil do return
        
        // Calculate distance to node
        current_dist := euclidean_distance(target_x, target_y, node.x, node.y)
        
        // Update best if closer
        if current_dist < best.distance {
            best.x = node.x
            best.y = node.y
            best.data = node.data
            best.distance = current_dist
        }
        axis := depth % 2
        next_depth := depth + 1
        
        // Determine which subtree to search first
        target_coord, node_coord: f32
        if axis == 0 { // x
            target_coord = target_x
            node_coord = node.x
        } else { // y
            target_coord = target_y
            node_coord = node.y
        }
        near_subtree, far_subtree: ^Node
        if target_coord < node_coord {
            near_subtree = node.left
            far_subtree = node.right
        } else {
            near_subtree = node.right
            far_subtree = node.left
        }
        // Search near subtree first
        nearest_recursive(near_subtree, target_x, target_y, best, next_depth)
        
        // Check if we need to search far subtree
        // Approximate check using coord diff
        coord_diff := math.abs(target_coord - node_coord)
        
        // Min distance to far subtree is coord_diff (perpendicular distance to splitting plane)
        approx_dist := coord_diff
        if approx_dist < best.distance {
            nearest_recursive(far_subtree, target_x, target_y, best, next_depth)
        }
    }
    nearest_recursive(tree.root, target_x, target_y, &best_res, 0)
    
    return best_res, best_res.distance != math.F32_MAX
}

// Find all points within given distance
in_range :: proc(tree: ^Tree, target_x, target_y: f32, max_distance: f32) -> []Result {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    res := make([dynamic]Result)
    
    range_recursive :: proc(node: ^Node, target_x, target_y: f32, 
                               max_dist: f32, results: ^[dynamic]Result, depth: int) {
        if node == nil do return
        
        current_dist := euclidean_distance(target_x, target_y, node.x, node.y)
        
        // Add to results if within range
        if current_dist <= max_dist {
            append(results, Result{
                x = node.x,
                y = node.y,
                data = node.data,
                distance = current_dist,
            })
        }
        axis := depth % 2
        next_depth := depth + 1
        
        // Determine subtrees
        target_coord, node_coord: f32
        if axis == 0 { // x
            target_coord = target_x
            node_coord = node.x
        } else { // y
            target_coord = target_y
            node_coord = node.y
        }
        coord_diff := math.abs(target_coord - node_coord)
        
        // Approx dist for pruning (min dist to far side)
        approx_dist := coord_diff
        // Search near subtree first
        if target_coord < node_coord {
            range_recursive(node.left, target_x, target_y, max_dist, results, next_depth)
            if approx_dist <= max_dist {
                range_recursive(node.right, target_x, target_y, max_dist, results, next_depth)
            }
        } else {
            range_recursive(node.right, target_x, target_y, max_dist, results, next_depth)
            if approx_dist <= max_dist {
                range_recursive(node.left, target_x, target_y, max_dist, results, next_depth)
            }
        }
    }
    range_recursive(tree.root, target_x, target_y, max_distance, &res, 0)
    
    return res[:]
}

// Query version: append indices to provided dynamic array (for compatibility with spatial hash)
in_range_query :: proc(tree: ^Tree, target_x, target_y: f32, max_distance: f32, result: ^[dynamic]int) {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    clear(result)
    
    range_recursive :: proc(node: ^Node, target_x, target_y: f32, max_dist: f32, results: ^[dynamic]int, depth: int) {
        if node == nil { return }
        
        current_dist := euclidean_distance(target_x, target_y, node.x, node.y)
        
        // Add index if within range (includes self at dist 0)
        if current_dist <= max_dist {
            append(results, int(uintptr(node.data)))
        }
        
        axis := depth % 2
        next_depth := depth + 1
        
        target_coord, node_coord: f32
        if axis == 0 { // x
            target_coord = target_x
            node_coord = node.x
        } else { // y
            target_coord = target_y
            node_coord = node.y
        }
        coord_diff := math.abs(target_coord - node_coord)
        approx_dist := coord_diff
        
        // Search near first
        if target_coord < node_coord {
            range_recursive(node.left, target_x, target_y, max_dist, results, next_depth)
            if approx_dist <= max_dist {
                range_recursive(node.right, target_x, target_y, max_dist, results, next_depth)
            }
        } else {
            range_recursive(node.right, target_x, target_y, max_dist, results, next_depth)
            if approx_dist <= max_dist {
                range_recursive(node.left, target_x, target_y, max_dist, results, next_depth)
            }
        }
    }
    
    if tree.root != nil {
        range_recursive(tree.root, target_x, target_y, max_distance, result, 0)
    }
}

destroy :: proc(tree: ^Tree) {
    if tree == nil do return
    
    clear_recursive :: proc(node: ^Node, destr: proc(data: rawptr)) {
        if node == nil do return
        
        clear_recursive(node.left, destr)
        clear_recursive(node.right, destr)
        
        if destr != nil {
            destr(node.data)
        }
        free(node)
    }
    clear_recursive(tree.root, tree.destr)
    tree.root = nil
}

// Euclidean distance between two points
euclidean_distance :: proc( x1: f32, y1: f32, x2: f32, y2: f32 ) -> f32 {
    dx := x2 - x1
    dy := y2 - y1
    return math.sqrt( dx*dx + dy*dy )
}