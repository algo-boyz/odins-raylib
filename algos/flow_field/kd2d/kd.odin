package kd2d

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:sync"
import "../../../../rlutil/fibr"

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

// Thread work data for parallel nearest neighbor search
Nearest_Work :: struct {
    node:     ^Node,
    target_x: f32,
    target_y: f32,
    best:     ^Result,
    mutex:    ^sync.Mutex,
    depth:    int,
}

// Thread work data for parallel range search
Range_Work :: struct {
    node:       ^Node,
    target_x:   f32,
    target_y:   f32,
    max_dist:   f32,
    results:    ^[dynamic]Result,
    mutex:      ^sync.Mutex,
    depth:      int,
}

Range_Query_Work :: struct {
    node:       ^Node,
    target_x:   f32,
    target_y:   f32,
    max_dist:   f32,
    results:    ^[dynamic]int,
    mutex:      ^sync.Mutex,
    depth:      int,
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

// Single-threaded nearest neighbor (original)
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
        
        current_dist := euclidean_distance(target_x, target_y, node.x, node.y)
        
        if current_dist < best.distance {
            best.x = node.x
            best.y = node.y
            best.data = node.data
            best.distance = current_dist
        }
        axis := depth % 2
        next_depth := depth + 1
        
        target_coord, node_coord: f32
        if axis == 0 {
            target_coord = target_x
            node_coord = node.x
        } else {
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
        
        nearest_recursive(near_subtree, target_x, target_y, best, next_depth)
        
        coord_diff := math.abs(target_coord - node_coord)
        approx_dist := coord_diff
        if approx_dist < best.distance {
            nearest_recursive(far_subtree, target_x, target_y, best, next_depth)
        }
    }
    nearest_recursive(tree.root, target_x, target_y, &best_res, 0)
    
    return best_res, best_res.distance != math.F32_MAX
}

// Worker function for parallel nearest neighbor search
nearest_worker :: proc(arg: rawptr) {
    work := cast(^Nearest_Work)arg
    if work.node == nil do return
    
    node := work.node
    current_dist := euclidean_distance(work.target_x, work.target_y, node.x, node.y)
    
    // Update best with mutex protection
    sync.mutex_lock(work.mutex)
    if current_dist < work.best.distance {
        work.best.x = node.x
        work.best.y = node.y
        work.best.data = node.data
        work.best.distance = current_dist
    }
    current_best := work.best.distance
    sync.mutex_unlock(work.mutex)
    
    axis := work.depth % 2
    next_depth := work.depth + 1
    
    target_coord, node_coord: f32
    if axis == 0 {
        target_coord = work.target_x
        node_coord = node.x
    } else {
        target_coord = work.target_y
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
    
    // Process near subtree recursively (same thread)
    if near_subtree != nil {
        near_work := Nearest_Work{
            node = near_subtree,
            target_x = work.target_x,
            target_y = work.target_y,
            best = work.best,
            mutex = work.mutex,
            depth = next_depth,
        }
        nearest_worker(&near_work)
    }
    
    // Check if far subtree needs searching
    coord_diff := math.abs(target_coord - node_coord)
    sync.mutex_lock(work.mutex)
    current_best = work.best.distance
    sync.mutex_unlock(work.mutex)
    
    if coord_diff < current_best && far_subtree != nil {
        far_work := Nearest_Work{
            node = far_subtree,
            target_x = work.target_x,
            target_y = work.target_y,
            best = work.best,
            mutex = work.mutex,
            depth = next_depth,
        }
        nearest_worker(&far_work)
    }
}

// Multi-threaded nearest neighbor search
nearest_parallel :: proc(tree: ^Tree, target_x, target_y: f32, num_threads := 4) -> (Result, bool) {
    sync.mutex_lock(&tree.mutex)
    root := tree.root
    sync.mutex_unlock(&tree.mutex)
    
    if root == nil {
        return {}, false
    }
    
    best_res := Result{
        distance = math.F32_MAX,
    }
    result_mutex: sync.Mutex
    
    // Spawn threads for left and right subtrees
    if root.left != nil && root.right != nil && num_threads >= 2 {
        left_work := new(Nearest_Work)
        left_work.node = root.left
        left_work.target_x = target_x
        left_work.target_y = target_y
        left_work.best = &best_res
        left_work.mutex = &result_mutex
        left_work.depth = 1
        
        right_work := new(Nearest_Work)
        right_work.node = root.right
        right_work.target_x = target_x
        right_work.target_y = target_y
        right_work.best = &best_res
        right_work.mutex = &result_mutex
        right_work.depth = 1
        
        left_thread: fibr.Thread
        fibr.spawn(&left_thread, nearest_worker, left_work)
        
        // Process right subtree in current thread
        nearest_worker(right_work)
        
        fibr.join(&left_thread)
        
        free(left_work)
        free(right_work)
    } else {
        // Fall back to single-threaded
        work := Nearest_Work{
            node = root,
            target_x = target_x,
            target_y = target_y,
            best = &best_res,
            mutex = &result_mutex,
            depth = 0,
        }
        nearest_worker(&work)
    }
    
    // Check root node itself
    root_dist := euclidean_distance(target_x, target_y, root.x, root.y)
    if root_dist < best_res.distance {
        best_res.x = root.x
        best_res.y = root.y
        best_res.data = root.data
        best_res.distance = root_dist
    }
    
    return best_res, best_res.distance != math.F32_MAX
}

// Single-threaded range query
in_range :: proc(tree: ^Tree, target_x, target_y: f32, max_distance: f32) -> []Result {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    res := make([dynamic]Result)
    
    range_recursive :: proc(node: ^Node, target_x, target_y: f32, 
                               max_dist: f32, results: ^[dynamic]Result, depth: int) {
        if node == nil do return
        
        current_dist := euclidean_distance(target_x, target_y, node.x, node.y)
        
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
        
        target_coord, node_coord: f32
        if axis == 0 {
            target_coord = target_x
            node_coord = node.x
        } else {
            target_coord = target_y
            node_coord = node.y
        }
        coord_diff := math.abs(target_coord - node_coord)
        approx_dist := coord_diff
        
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

// Worker function for parallel range search
range_worker :: proc(arg: rawptr) {
    work := cast(^Range_Work)arg
    if work.node == nil do return
    
    node := work.node
    current_dist := euclidean_distance(work.target_x, work.target_y, node.x, node.y)
    
    if current_dist <= work.max_dist {
        sync.mutex_lock(work.mutex)
        append(work.results, Result{
            x = node.x,
            y = node.y,
            data = node.data,
            distance = current_dist,
        })
        sync.mutex_unlock(work.mutex)
    }
    
    axis := work.depth % 2
    next_depth := work.depth + 1
    
    target_coord, node_coord: f32
    if axis == 0 {
        target_coord = work.target_x
        node_coord = node.x
    } else {
        target_coord = work.target_y
        node_coord = node.y
    }
    
    coord_diff := math.abs(target_coord - node_coord)
    approx_dist := coord_diff
    
    if target_coord < node_coord {
        if node.left != nil {
            left_work := Range_Work{
                node = node.left,
                target_x = work.target_x,
                target_y = work.target_y,
                max_dist = work.max_dist,
                results = work.results,
                mutex = work.mutex,
                depth = next_depth,
            }
            range_worker(&left_work)
        }
        if approx_dist <= work.max_dist && node.right != nil {
            right_work := Range_Work{
                node = node.right,
                target_x = work.target_x,
                target_y = work.target_y,
                max_dist = work.max_dist,
                results = work.results,
                mutex = work.mutex,
                depth = next_depth,
            }
            range_worker(&right_work)
        }
    } else {
        if node.right != nil {
            right_work := Range_Work{
                node = node.right,
                target_x = work.target_x,
                target_y = work.target_y,
                max_dist = work.max_dist,
                results = work.results,
                mutex = work.mutex,
                depth = next_depth,
            }
            range_worker(&right_work)
        }
        if approx_dist <= work.max_dist && node.left != nil {
            left_work := Range_Work{
                node = node.left,
                target_x = work.target_x,
                target_y = work.target_y,
                max_dist = work.max_dist,
                results = work.results,
                mutex = work.mutex,
                depth = next_depth,
            }
            range_worker(&left_work)
        }
    }
}

// Multi-threaded range search
in_range_parallel :: proc(tree: ^Tree, target_x, target_y: f32, max_distance: f32, num_threads := 4) -> []Result {
    sync.mutex_lock(&tree.mutex)
    root := tree.root
    sync.mutex_unlock(&tree.mutex)
    
    res := make([dynamic]Result)
    if root == nil {
        return res[:]
    }
    
    result_mutex: sync.Mutex
    
    if root.left != nil && root.right != nil && num_threads >= 2 {
        left_work := new(Range_Work)
        left_work.node = root.left
        left_work.target_x = target_x
        left_work.target_y = target_y
        left_work.max_dist = max_distance
        left_work.results = &res
        left_work.mutex = &result_mutex
        left_work.depth = 1
        
        right_work := new(Range_Work)
        right_work.node = root.right
        right_work.target_x = target_x
        right_work.target_y = target_y
        right_work.max_dist = max_distance
        right_work.results = &res
        right_work.mutex = &result_mutex
        right_work.depth = 1
        
        left_thread: fibr.Thread
        fibr.spawn(&left_thread, range_worker, left_work)
        
        range_worker(right_work)
        
        fibr.join(&left_thread)
        
        free(left_work)
        free(right_work)
    } else {
        work := Range_Work{
            node = root,
            target_x = target_x,
            target_y = target_y,
            max_dist = max_distance,
            results = &res,
            mutex = &result_mutex,
            depth = 0,
        }
        range_worker(&work)
    }
    
    // Check root
    root_dist := euclidean_distance(target_x, target_y, root.x, root.y)
    if root_dist <= max_distance {
        append(&res, Result{
            x = root.x,
            y = root.y,
            data = root.data,
            distance = root_dist,
        })
    }
    
    return res[:]
}

// Single-threaded query version
in_range_query :: proc(tree: ^Tree, target_x, target_y: f32, max_distance: f32, result: ^[dynamic]int) {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    clear(result)
    
    range_recursive :: proc(node: ^Node, target_x, target_y: f32, max_dist: f32, results: ^[dynamic]int, depth: int) {
        if node == nil { return }
        
        current_dist := euclidean_distance(target_x, target_y, node.x, node.y)
        
        if current_dist <= max_dist {
            append(results, int(uintptr(node.data)))
        }
        
        axis := depth % 2
        next_depth := depth + 1
        
        target_coord, node_coord: f32
        if axis == 0 {
            target_coord = target_x
            node_coord = node.x
        } else {
            target_coord = target_y
            node_coord = node.y
        }
        coord_diff := math.abs(target_coord - node_coord)
        approx_dist := coord_diff
        
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

// Worker for parallel query version
range_query_worker :: proc(arg: rawptr) {
    work := cast(^Range_Query_Work)arg
    if work.node == nil do return
    
    node := work.node
    current_dist := euclidean_distance(work.target_x, work.target_y, node.x, node.y)
    
    if current_dist <= work.max_dist {
        sync.mutex_lock(work.mutex)
        append(work.results, int(uintptr(node.data)))
        sync.mutex_unlock(work.mutex)
    }
    
    axis := work.depth % 2
    next_depth := work.depth + 1
    
    target_coord, node_coord: f32
    if axis == 0 {
        target_coord = work.target_x
        node_coord = node.x
    } else {
        target_coord = work.target_y
        node_coord = node.y
    }
    
    coord_diff := math.abs(target_coord - node_coord)
    approx_dist := coord_diff
    
    if target_coord < node_coord {
        if node.left != nil {
            left_work := Range_Query_Work{
                node = node.left,
                target_x = work.target_x,
                target_y = work.target_y,
                max_dist = work.max_dist,
                results = work.results,
                mutex = work.mutex,
                depth = next_depth,
            }
            range_query_worker(&left_work)
        }
        if approx_dist <= work.max_dist && node.right != nil {
            right_work := Range_Query_Work{
                node = node.right,
                target_x = work.target_x,
                target_y = work.target_y,
                max_dist = work.max_dist,
                results = work.results,
                mutex = work.mutex,
                depth = next_depth,
            }
            range_query_worker(&right_work)
        }
    } else {
        if node.right != nil {
            right_work := Range_Query_Work{
                node = node.right,
                target_x = work.target_x,
                target_y = work.target_y,
                max_dist = work.max_dist,
                results = work.results,
                mutex = work.mutex,
                depth = next_depth,
            }
            range_query_worker(&right_work)
        }
        if approx_dist <= work.max_dist && node.left != nil {
            left_work := Range_Query_Work{
                node = node.left,
                target_x = work.target_x,
                target_y = work.target_y,
                max_dist = work.max_dist,
                results = work.results,
                mutex = work.mutex,
                depth = next_depth,
            }
            range_query_worker(&left_work)
        }
    }
}

// Multi-threaded query version
in_range_query_parallel :: proc(tree: ^Tree, target_x, target_y: f32, max_distance: f32, result: ^[dynamic]int, num_threads := 4) {
    sync.mutex_lock(&tree.mutex)
    root := tree.root
    sync.mutex_unlock(&tree.mutex)
    
    clear(result)
    if root == nil {
        return
    }
    
    result_mutex: sync.Mutex
    
    if root.left != nil && root.right != nil && num_threads >= 2 {
        left_work := new(Range_Query_Work)
        left_work.node = root.left
        left_work.target_x = target_x
        left_work.target_y = target_y
        left_work.max_dist = max_distance
        left_work.results = result
        left_work.mutex = &result_mutex
        left_work.depth = 1
        
        right_work := new(Range_Query_Work)
        right_work.node = root.right
        right_work.target_x = target_x
        right_work.target_y = target_y
        right_work.max_dist = max_distance
        right_work.results = result
        right_work.mutex = &result_mutex
        right_work.depth = 1
        
        left_thread: fibr.Thread
        fibr.spawn(&left_thread, range_query_worker, left_work)
        
        range_query_worker(right_work)
        
        fibr.join(&left_thread)
        
        free(left_work)
        free(right_work)
    } else {
        work := Range_Query_Work{
            node = root,
            target_x = target_x,
            target_y = target_y,
            max_dist = max_distance,
            results = result,
            mutex = &result_mutex,
            depth = 0,
        }
        range_query_worker(&work)
    }
    
    // Check root
    root_dist := euclidean_distance(target_x, target_y, root.x, root.y)
    if root_dist <= max_distance {
        append(result, int(uintptr(root.data)))
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

euclidean_distance :: proc( x1: f32, y1: f32, x2: f32, y2: f32 ) -> f32 {
    dx := x2 - x1
    dy := y2 - y1
    return math.sqrt( dx*dx + dy*dy )
}