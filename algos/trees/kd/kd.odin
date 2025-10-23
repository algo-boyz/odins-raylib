package kd

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:sync"
import "../../../rlutil/fibr"

// Hyperrectangle structure for bounding boxes
Hyperrect :: struct {
    dim: int,
    min: []f64,
    max: []f64,
}

// Node in the k-d tree
Node :: struct {
    pos:   []f64,
    dir:   int,
    data:  rawptr,
    left:  ^Node,
    right: ^Node,
}

// Result node for search results
Result_Node :: struct {
    item:    ^Node,
    dist_sq: f64,
    next:    ^Result_Node,
}

// Main k-d tree structure
Tree :: struct {
    dim:    int,
    root:   ^Node,
    rect:   ^Hyperrect,
    destr:  proc(data: rawptr),
    mutex:  sync.Mutex,
}

// Result set for queries
Result_Set :: struct {
    tree:   ^Tree,
    rlist:  ^Result_Node,
    riter:  ^Result_Node,
    size:   int,
}

// Helper macro equivalent
sq :: proc(x: f64) -> f64 {
    return x * x
}

// Create a new k-d tree
create :: proc(k: int, allocator := context.allocator) -> ^Tree {
    context.allocator = allocator
    
    tree := new(Tree)
    tree.dim = k
    tree.root = nil
    tree.destr = nil
    tree.rect = nil
    
    return tree
}

// Free the k-d tree
cleanup :: proc(tree: ^Tree) {
    if tree == nil do return
    clear(tree)
    free(tree)
}

// Clear all nodes recursively
clear_rec :: proc(node: ^Node, destr: proc(data: rawptr)) {
    if node == nil do return
    
    clear_rec(node.left, destr)
    clear_rec(node.right, destr)
    
    if destr != nil {
        destr(node.data)
    }
    
    delete(node.pos)
    free(node)
}

// Clear the tree
clear :: proc(tree: ^Tree) {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    clear_rec(tree.root, tree.destr)
    tree.root = nil
    
    if tree.rect != nil {
        hyperrect_free(tree.rect)
        tree.rect = nil
    }
}

// Set data destructor
set_data_destructor :: proc(tree: ^Tree, destr: proc(data: rawptr)) {
    tree.destr = destr
}

// Insert recursively
insert_rec :: proc(nptr: ^^Node, pos: []f64, data: rawptr, dir: int, dim: int) -> bool {
    if nptr^ == nil {
        node := new(Node)
        node.pos = make([]f64, dim)
        copy(node.pos, pos)
        node.data = data
        node.dir = dir
        node.left = nil
        node.right = nil
        nptr^ = node
        return true
    }
    
    node := nptr^
    new_dir := (node.dir + 1) % dim
    
    if pos[node.dir] < node.pos[node.dir] {
        return insert_rec(&node.left, pos, data, new_dir, dim)
    }
    return insert_rec(&node.right, pos, data, new_dir, dim)
}

// Insert a point into the tree
insert :: proc(tree: ^Tree, pos: []f64, data: rawptr) -> bool {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    if !insert_rec(&tree.root, pos, data, 0, tree.dim) {
        return false
    }
    
    if tree.rect == nil {
        tree.rect = hyperrect_create(tree.dim, pos, pos)
    } else {
        hyperrect_extend(tree.rect, pos)
    }
    
    return true
}

// Insert with 3D coordinates
insert3 :: proc(tree: ^Tree, x, y, z: f64, data: rawptr) -> bool {
    pos := []f64{x, y, z}
    return insert(tree, pos, data)
}

// Find nearest neighbor recursively
find_nearest :: proc(node: ^Node, pos: []f64, range: f64, list: ^Result_Node, ordered: bool, dim: int) -> int {
    if node == nil do return 0
    
    dist_sq: f64 = 0
    for i in 0..<dim {
        dist_sq += sq(node.pos[i] - pos[i])
    }
    
    added_res := 0
    if dist_sq <= sq(range) {
        if rlist_insert(list, node, ordered ? dist_sq : -1.0) {
            added_res = 1
        } else {
            return -1
        }
    }
    
    dx := pos[node.dir] - node.pos[node.dir]
    
    ret := find_nearest(dx <= 0.0 ? node.left : node.right, pos, range, list, ordered, dim)
    if ret >= 0 && abs(dx) < range {
        added_res += ret
        ret = find_nearest(dx <= 0.0 ? node.right : node.left, pos, range, list, ordered, dim)
    }
    
    if ret == -1 do return -1
    added_res += ret
    return added_res
}

// Find nearest neighbor using iterative algorithm
nearest_i :: proc(node: ^Node, pos: []f64, result: ^^Node, result_dist_sq: ^f64, rect: ^Hyperrect) {
    dir := node.dir
    dummy: f64
    dist_sq: f64
    nearer_subtree, farther_subtree: ^Node
    nearer_hyperrect_coord, farther_hyperrect_coord: ^f64
    
    // Decide whether to go left or right
    dummy = pos[dir] - node.pos[dir]
    if dummy <= 0 {
        nearer_subtree = node.left
        farther_subtree = node.right
        nearer_hyperrect_coord = &rect.max[dir]
        farther_hyperrect_coord = &rect.min[dir]
    } else {
        nearer_subtree = node.right
        farther_subtree = node.left
        nearer_hyperrect_coord = &rect.min[dir]
        farther_hyperrect_coord = &rect.max[dir]
    }
    
    if nearer_subtree != nil {
        // Slice the hyperrect for nearer subtree
        dummy = nearer_hyperrect_coord^
        nearer_hyperrect_coord^ = node.pos[dir]
        // Recurse down into nearer subtree
        nearest_i(nearer_subtree, pos, result, result_dist_sq, rect)
        // Undo the slice
        nearer_hyperrect_coord^ = dummy
    }
    
    // Check distance of current node
    dist_sq = 0
    for i in 0..<rect.dim {
        dist_sq += sq(node.pos[i] - pos[i])
    }
    
    if dist_sq < result_dist_sq^ {
        result^ = node
        result_dist_sq^ = dist_sq
    }
    
    if farther_subtree != nil {
        // Get hyperrect of farther subtree
        dummy = farther_hyperrect_coord^
        farther_hyperrect_coord^ = node.pos[dir]
        
        // Check if we need to recurse
        if hyperrect_dist_sq(rect, pos) < result_dist_sq^ {
            nearest_i(farther_subtree, pos, result, result_dist_sq, rect)
        }
        
        // Undo the slice
        farther_hyperrect_coord^ = dummy
    }
}

// Find nearest neighbor
nearest :: proc(tree: ^Tree, pos: []f64) -> ^Result_Set {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    if tree == nil || tree.rect == nil do return nil
    
    // Allocate result set
    rset := new(Result_Set)
    rset.rlist = new(Result_Node)
    rset.rlist.next = nil
    rset.tree = tree
    
    // Duplicate bounding hyperrectangle
    rect := hyperrect_duplicate(tree.rect)
    if rect == nil {
        res_free(rset)
        return nil
    }
    defer hyperrect_free(rect)
    
    // Initial guess is root node
    result := tree.root
    dist_sq: f64 = 0
    for i in 0..<tree.dim {
        dist_sq += sq(result.pos[i] - pos[i])
    }
    
    // Search for nearest neighbor recursively
    nearest_i(tree.root, pos, &result, &dist_sq, rect)
    
    // Store result
    if result != nil {
        if rlist_insert(rset.rlist, result, -1.0) {
            rset.size = 1
            res_rewind(rset)
            return rset
        }
    }
    
    res_free(rset)
    return nil
}

// Find nearest neighbor with 3D coordinates
nearest3 :: proc(tree: ^Tree, x, y, z: f64) -> ^Result_Set {
    pos := []f64{x, y, z}
    return nearest(tree, pos)
}

// Find nearest neighbors within range
nearest_range :: proc(tree: ^Tree, pos: []f64, range: f64) -> ^Result_Set {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    rset := new(Result_Set)
    rset.rlist = new(Result_Node)
    rset.rlist.next = nil
    rset.tree = tree
    
    ret := find_nearest(tree.root, pos, range, rset.rlist, false, tree.dim)
    if ret == -1 {
        res_free(rset)
        return nil
    }
    
    rset.size = ret
    res_rewind(rset)
    return rset
}

// Find nearest neighbors within range with 3D coordinates
nearest_range3 :: proc(tree: ^Tree, x, y, z: f64, range: f64) -> ^Result_Set {
    pos := []f64{x, y, z}
    return nearest_range(tree, pos, range)
}

deg2rad :: proc( degrees: f64 ) -> f64 {
    return degrees * ( math.PI / 180.0 )
}

EARTH_RAD_KM :: 6_368

// Distance between two points on a sphere, in kilometers
haversine_distance :: proc( lat1: f64, lon1: f64, lat2: f64, lon2: f64 ) -> f64 {

    dlat := deg2rad( lat2 - lat1 )
    dlon := deg2rad( lon2 - lon1 )

    a := math.sin( dlat / 2 ) * math.sin( dlat / 2 ) +
         math.cos( deg2rad(lat1 ) ) * math.cos( deg2rad( lat2 ) ) *
         math.sin( dlon / 2 ) * math.sin( dlon / 2 )

    c := 2 * math.atan2( math.sqrt( a ), math.sqrt( 1 - a ) )

    return EARTH_RAD_KM * c
}

// Fixed nearest_geo that works with the existing k-d tree structure
nearest_geo :: proc(tree: ^Tree, target_lat, target_long: f64) -> ([]f64, f64, rawptr) {
    if tree == nil || tree.root == nil || tree.dim != 2 {
        return nil, math.F64_MAX, nil
    }
    
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    target_pos := []f64{target_lat, target_long}
    
    nearest_geo_recursive :: proc(node: ^Node, target: []f64, rect: ^Hyperrect, 
                                best_dist: ^f64, best_pos: ^[]f64, best_data: ^rawptr) {
        if node == nil do return
        
        // Calculate haversine distance to current node
        current_dist := haversine_distance(target[0], target[1], node.pos[0], node.pos[1])
        
        // Update best if this is closer
        if current_dist < best_dist^ {
            best_dist^ = current_dist
            // Copy position
            if best_pos^ == nil {
                best_pos^ = make([]f64, 2)
            }
            copy(best_pos^, node.pos)
            best_data^ = node.data
        }
        
        dir := node.dir
        
        // Decide which subtree to search first
        nearer_subtree, farther_subtree: ^Node
        nearer_hyperrect_coord, farther_hyperrect_coord: ^f64
        
        if target[dir] < node.pos[dir] {
            nearer_subtree = node.left
            farther_subtree = node.right
            nearer_hyperrect_coord = &rect.max[dir]
            farther_hyperrect_coord = &rect.min[dir]
        } else {
            nearer_subtree = node.right
            farther_subtree = node.left
            nearer_hyperrect_coord = &rect.min[dir]
            farther_hyperrect_coord = &rect.max[dir]
        }
        
        // Search nearer subtree first
        if nearer_subtree != nil {
            old_coord := nearer_hyperrect_coord^
            nearer_hyperrect_coord^ = node.pos[dir]
            nearest_geo_recursive(nearer_subtree, target, rect, best_dist, best_pos, best_data)
            nearer_hyperrect_coord^ = old_coord
        }
        
        // Check if we need to search farther subtree
        if farther_subtree != nil {
            old_coord := farther_hyperrect_coord^
            farther_hyperrect_coord^ = node.pos[dir]
            
            // For geographic searches, we need to be more careful about pruning
            // Convert the rectangular bound check to approximate geographic distance
            min_possible_dist := hyperrect_min_geo_dist(rect, target)
            
            if min_possible_dist < best_dist^ {
                nearest_geo_recursive(farther_subtree, target, rect, best_dist, best_pos, best_data)
            }
            
            farther_hyperrect_coord^ = old_coord
        }
    }
    
    // Create working copy of bounding rectangle
    rect := hyperrect_duplicate(tree.rect)
    if rect == nil {
        return nil, math.F64_MAX, nil
    }
    defer hyperrect_free(rect)
    
    best_dist := math.F64_MAX
    best_pos: []f64 = nil
    best_data: rawptr = nil
    
    nearest_geo_recursive(tree.root, target_pos, rect, &best_dist, &best_pos, &best_data)
    
    return best_pos, best_dist, best_data
}

// Helper function to estimate minimum geographic distance from a hyperrectangle
hyperrect_min_geo_dist :: proc(rect: ^Hyperrect, target: []f64) -> f64 {
    // Find the closest point in the rectangle to the target
    closest_lat := clamp(target[0], rect.min[0], rect.max[0])
    closest_lon := clamp(target[1], rect.min[1], rect.max[1])
    
    return haversine_distance(target[0], target[1], closest_lat, closest_lon)
}

// Result set functions
res_free :: proc(rset: ^Result_Set) {
    if rset == nil do return
    clear_results(rset)
    free(rset.rlist)
    free(rset)
}

res_size :: proc(rset: ^Result_Set) -> int {
    return rset.size
}

res_rewind :: proc(rset: ^Result_Set) {
    rset.riter = rset.rlist.next
}

res_end :: proc(rset: ^Result_Set) -> bool {
    return rset.riter == nil
}

res_next :: proc(rset: ^Result_Set) -> bool {
    if rset.riter == nil do return false
    rset.riter = rset.riter.next
    return rset.riter != nil
}

res_item :: proc(rset: ^Result_Set, pos: []f64 = nil) -> rawptr {
    if rset.riter == nil do return nil
    
    if pos != nil && len(pos) >= rset.tree.dim {
        copy(pos, rset.riter.item.pos)
    }
    
    return rset.riter.item.data
}

res_item3 :: proc(rset: ^Result_Set) -> (rawptr, f64, f64, f64) {
    if rset.riter == nil do return nil, 0, 0, 0
    
    item := rset.riter.item
    return item.data, item.pos[0], item.pos[1], item.pos[2]
}

res_item_data :: proc(rset: ^Result_Set) -> rawptr {
    return res_item(rset)
}

// Hyperrectangle functions
hyperrect_create :: proc(dim: int, min_pos: []f64, max_pos: []f64) -> ^Hyperrect {
    rect := new(Hyperrect)
    rect.dim = dim
    rect.min = make([]f64, dim)
    rect.max = make([]f64, dim)
    
    copy(rect.min, min_pos)
    copy(rect.max, max_pos)
    
    return rect
}

hyperrect_free :: proc(rect: ^Hyperrect) {
    if rect == nil do return
    delete(rect.min)
    delete(rect.max)
    free(rect)
}

hyperrect_duplicate :: proc(rect: ^Hyperrect) -> ^Hyperrect {
    if rect == nil do return nil
    return hyperrect_create(rect.dim, rect.min, rect.max)
}

hyperrect_extend :: proc(rect: ^Hyperrect, pos: []f64) {
    for i in 0..<rect.dim {
        if pos[i] < rect.min[i] {
            rect.min[i] = pos[i]
        }
        if pos[i] > rect.max[i] {
            rect.max[i] = pos[i]
        }
    }
}

hyperrect_dist_sq :: proc(rect: ^Hyperrect, pos: []f64) -> f64 {
    result: f64 = 0
    for i in 0..<rect.dim {
        if pos[i] < rect.min[i] {
            result += sq(rect.min[i] - pos[i])
        } else if pos[i] > rect.max[i] {
            result += sq(rect.max[i] - pos[i])
        }
    }
    return result
}

// Insert into result list (ordered if dist_sq >= 0)
rlist_insert :: proc(list: ^Result_Node, item: ^Node, dist_sq: f64) -> bool {
    rnode := new(Result_Node)
    rnode.item = item
    rnode.dist_sq = dist_sq
    
    current := list
    if dist_sq >= 0.0 {
        for current.next != nil && current.next.dist_sq < dist_sq {
            current = current.next
        }
    }
    
    rnode.next = current.next
    current.next = rnode
    return true
}

// Clear results
clear_results :: proc(rset: ^Result_Set) {
    node := rset.rlist.next
    for node != nil {
        tmp := node
        node = node.next
        free(tmp)
    }
    rset.rlist.next = nil
}