package kdgeo

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:sync"
import "../../../rlutil/fibr"
// Geographic-specific k-d tree that uses haversine distance
Node :: struct {
    lat:   f64,
    lon:   f64,
    data:  rawptr,
    left:  ^Node,
    right: ^Node,
    axis:  int, // 0 for latitude, 1 for longitude
}

Tree :: struct {
    root:   ^Node,
    destr:  proc(data: rawptr),
    mutex:  sync.Mutex,
}

Result :: struct {
    lat:      f64,
    lon:      f64,
    data:     rawptr,
    distance: f64,
}

// Create a new geographic k-d tree
create :: proc(allocator := context.allocator) -> (tree: Tree) {
    context.allocator = allocator
    tree.root = nil
    tree.destr = nil
    return tree
}

// Insert point into the geo k-d tree
insert :: proc(tree: ^Tree, lat, lon: f64, data: rawptr) -> bool {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    insert_recursive :: proc(node: ^^Node, lat, lon: f64, data: rawptr, depth: int) {
        if node^ == nil {
            node^ = new(Node)
            node^.lat = lat
            node^.lon = lon
            node^.data = data
            node^.axis = depth % 2
            node^.left = nil
            node^.right = nil
            return
        }
        current := node^
        next_depth := depth + 1
        
        if current.axis == 0 { // Split on latitude
            if lat < current.lat {
                insert_recursive(&current.left, lat, lon, data, next_depth)
            } else {
                insert_recursive(&current.right, lat, lon, data, next_depth)
            }
        } else { // Split on longitude
            if lon < current.lon {
                insert_recursive(&current.left, lat, lon, data, next_depth)
            } else {
                insert_recursive(&current.right, lat, lon, data, next_depth)
            }
        }
    }
    insert_recursive(&tree.root, lat, lon, data, 0)
    return true
}

// Find nearest neighbor in geo k-d tree
nearest :: proc(tree: ^Tree, target_lat, target_lon: f64) -> (Result, bool) {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    if tree.root == nil {
        return {}, false
    }
    best_res := Result{
        distance = math.F64_MAX,
    }

    nearest_recursive :: proc(node: ^Node, target_lat, target_lon: f64, best: ^Result, depth: int) {
        if node == nil do return
        
        // Calculate distance to node
        current_dist := haversine_distance(target_lat, target_lon, node.lat, node.lon)
        
        // Update best if closer
        if current_dist < best.distance {
            best.lat = node.lat
            best.lon = node.lon
            best.data = node.data
            best.distance = current_dist
        }
        axis := depth % 2
        next_depth := depth + 1
        
        // Determine which subtree to search first
        target_coord, node_coord: f64
        if axis == 0 { // Lat
            target_coord = target_lat
            node_coord = node.lat
        } else { // Lon
            target_coord = target_lon
            node_coord = node.lon
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
        nearest_recursive(near_subtree, target_lat, target_lon, best, next_depth)
        
        // Check if we need to search far subtree
        // Approximate check using coord diff
        coord_diff := abs(target_coord - node_coord)
        
        // Convert coordinate difference to approximate distance
        // This is a rough approximation - for accuracy, need to
        // compute the actual min distance to the far subtree
        approx_dist: f64
        if axis == 0 { // Lat diff
            approx_dist = coord_diff * 111.0 // Rough km per degree latitude
        } else { // Lon diff
            avg_lat := (target_lat + node.lat) / 2.0
            approx_dist = coord_diff * 111.0 * math.cos(deg2rad(avg_lat))
        }
        if approx_dist < best.distance {
            nearest_recursive(far_subtree, target_lat, target_lon, best, next_depth)
        }
    }
    nearest_recursive(tree.root, target_lat, target_lon, &best_res, 0)
    
    return best_res, best_res.distance != math.F64_MAX
}

// Find all points within given distance (assumes km)
in_range :: proc(tree: ^Tree, target_lat, target_lon: f64, max_distance_km: f64) -> []Result {
    sync.mutex_lock(&tree.mutex)
    defer sync.mutex_unlock(&tree.mutex)
    
    res := make([dynamic]Result)
    
    range_recursive :: proc(node: ^Node, target_lat, target_lon: f64, 
                               max_dist: f64, results: ^[dynamic]Result, depth: int) {
        if node == nil do return
        
        current_dist := haversine_distance(target_lat, target_lon, node.lat, node.lon)
        
        // Add to results if within range
        if current_dist <= max_dist {
            append(results, Result{
                lat = node.lat,
                lon = node.lon,
                data = node.data,
                distance = current_dist,
            })
        }
        axis := depth % 2
        next_depth := depth + 1
        
        // Always search both subtrees for range queries, but with pruning
        target_coord, node_coord: f64
        if axis == 0 { // Lat
            target_coord = target_lat
            node_coord = node.lat
        } else { // Lon
            target_coord = target_lon
            node_coord = node.lon
        }
        coord_diff := abs(target_coord - node_coord)
        
        // Approx dist for pruning
        approx_dist: f64
        if axis == 0 { // Lat diff
            approx_dist = coord_diff * 111.0
        } else { // Lon diff
            avg_lat := (target_lat + node.lat) / 2.0
            approx_dist = coord_diff * 111.0 * math.cos(deg2rad(avg_lat))
        }
        // Search subtrees for points within range
        if target_coord < node_coord {
            range_recursive(node.left, target_lat, target_lon, max_dist, results, next_depth)
            if approx_dist <= max_dist {
                range_recursive(node.right, target_lat, target_lon, max_dist, results, next_depth)
            }
        } else {
            range_recursive(node.right, target_lat, target_lon, max_dist, results, next_depth)
            if approx_dist <= max_dist {
                range_recursive(node.left, target_lat, target_lon, max_dist, results, next_depth)
            }
        }
    }
    range_recursive(tree.root, target_lat, target_lon, max_distance_km, &res, 0)
    
    return res[:]
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
    free(tree)
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