// planner.odin
// This package implements the RRT* (Rapidly-exploring Random Tree Star) algorithm
// for 3D path planning with collision avoidance.
package planner

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"
import "../env"

// --- Planner State ---
// Node represents a point in the RRT tree.
Node :: struct {
    position: rl.Vector3,
    parent:   i32, // Index of the parent node in the tree (-1 for root).
}

tree:         [dynamic]Node
path_points:  [dynamic]rl.Vector3 // The final smoothed path
start_point:  rl.Vector3
goal_point:   rl.Vector3
all_obstacles: ^[dynamic]env.Obstacle // Pointer to the environment's obstacles
robot_radius: f32
planning_complete: bool

// --- Helper Procedures ---

// distance calculates the Euclidean distance between two points.
distance :: proc(a, b: rl.Vector3) -> f32 {
    return rl.Vector3Length(a - b)
}

// is_point_in_collision checks if a point collides with any obstacle.
is_point_in_collision :: proc(point: rl.Vector3) -> bool {
    for obs in all_obstacles^ {
        // Inflate the obstacle radius by the robot's radius for collision checking.
        inflated_radius := obs.radius + robot_radius
        // Check distance in 2D (XZ plane) and height separately for cylinders.
        dist_xz := distance({point.x, 0, point.z}, {obs.position.x, 0, obs.position.z})
        
        if dist_xz < inflated_radius &&
           point.y >= obs.position.y - env.OBSTACLE_HEIGHT / 2 &&
           point.y <= obs.position.y + env.OBSTACLE_HEIGHT / 2 {
            return true
        }
    }
    return false
}

// is_segment_in_collision checks if a line segment between two points collides.
is_segment_in_collision :: proc(a, b: rl.Vector3) -> bool {
    steps: i32 = 10
    for i in 0..=steps {
        t := f32(i) / f32(steps)
        p := linalg.lerp(a, b, t)
        if is_point_in_collision(p) {
            return true
        }
    }
    return false
}

// --- RRT Core Procedures ---

// initialize_planner sets up the planner with start/goal points and obstacles.
initialize_planner :: proc(start, goal: rl.Vector3, obstacles_ptr: ^[dynamic]env.Obstacle, in_robot_radius: f32) {
    clear(&tree)
    clear(&path_points)
    
    start_point = start
    goal_point = goal
    all_obstacles = obstacles_ptr
    robot_radius = in_robot_radius
    planning_complete = false

    append(&tree, Node{position = start, parent = -1})
    append(&path_points, start)
}

// sample_random_point generates a random point within the environment bounds.
sample_random_point :: proc() -> rl.Vector3 {
    // Occasionally sample the goal to bias the tree growth towards it.
    if rand.float32_range(0, 1) > 0.9 {
        return goal_point
    }
    
    // Otherwise, sample a random point in the environment.
    range_val: f32 = 10.0 * env.TILE_SIZE
    return rl.Vector3{
        rand.float32_range(-range_val, range_val),
        robot_radius, // Keep the path at the robot's height.
        rand.float32_range(-range_val, range_val),
    }
}

// nearest_node_index finds the index of the node in the tree closest to a given point.
nearest_node_index :: proc(point: rl.Vector3) -> int {
    nearest_idx := 0
    min_dist := distance(tree[0].position, point)
    for i in 1..<len(tree) {
        dist := distance(tree[i].position, point)
        if dist < min_dist {
            min_dist = dist
            nearest_idx = i
        }
    }
    return nearest_idx
}

// --- Path Smoothing (Catmull-Rom Spline) ---

// catmull_rom_spline interpolates a point on a curve defined by four control points.
catmull_rom_spline :: proc(p0, p1, p2, p3: rl.Vector3, t: f32) -> rl.Vector3 {
    t2 := t * t
    t3 := t2 * t

    out: rl.Vector3
    out.x = 0.5 * ((2.0 * p1.x) +
                   (-p0.x + p2.x) * t +
                   (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 +
                   (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3)
    out.y = 0.5 * ((2.0 * p1.y) +
                   (-p0.y + p2.y) * t +
                   (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 +
                   (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3)
    out.z = 0.5 * ((2.0 * p1.z) +
                   (-p0.z + p2.z) * t +
                   (2.0 * p0.z - 5.0 * p1.z + 4.0 * p2.z - p3.z) * t2 +
                   (-p0.z + 3.0 * p1.z - 3.0 * p2.z + p3.z) * t3)
    return out
}

// generate_smooth_path creates a smooth path from a raw sequence of points.
generate_smooth_path :: proc(raw_path: []rl.Vector3, subdivisions: int) -> [dynamic]rl.Vector3 {
    smooth_path := make([dynamic]rl.Vector3)
    n := len(raw_path)
    if n < 2 {
        for p in raw_path { append(&smooth_path, p) }
        return smooth_path
    }

    for i in 0..<n - 1 {
        p0 := i == 0 ? raw_path[i] : raw_path[i - 1]
        p1 := raw_path[i]
        p2 := raw_path[i + 1]
        p3 := (i + 2 < n) ? raw_path[i + 2] : raw_path[i + 1]

        for j in 0..<subdivisions {
            t := f32(j) / f32(subdivisions)
            append(&smooth_path, catmull_rom_spline(p0, p1, p2, p3, t))
        }
    }
    append(&smooth_path, raw_path[n-1])
    return smooth_path
}

// --- Main Planner Logic ---

// plan_step executes one iteration of the RRT* algorithm.
plan_step :: proc() {
    if planning_complete || len(tree) == 0 {
        return
    }

    // 1. Sample a random point.
    sample := sample_random_point()

    // 2. Find the nearest node in the tree to the sample.
    nearest_idx := nearest_node_index(sample)
    nearest_pos := tree[nearest_idx].position

    // 3. Steer from the nearest node towards the sample.
    dir := sample - nearest_pos
    if rl.Vector3LengthSqr(dir) == 0 { return }

    dir = rl.Vector3Normalize(dir)
    step_size: f32 = env.TILE_SIZE * 0.9
    new_point := nearest_pos + (dir * step_size)
    
    // 4. Check for collisions.
    if is_point_in_collision(new_point) || is_segment_in_collision(nearest_pos, new_point) {
        return // Collision, discard this step.
    }
    
    // 5. Add the new node to the tree.
    append(&tree, Node{position = new_point, parent = auto_cast nearest_idx})

    // 6. Check if the goal is reachable from the new node.
    if distance(new_point, goal_point) < step_size &&
       !is_point_in_collision(goal_point) &&
       !is_segment_in_collision(new_point, goal_point) {
        
        // Goal is reached!
        append(&tree, Node{position = goal_point, parent = auto_cast (len(tree) - 1)})
        
        // Reconstruct the path from goal to start.
        raw_path := make([dynamic]rl.Vector3)
        current_idx := len(tree) - 1
        for current_idx != -1 {
            append(&raw_path, tree[current_idx].position)
            current_idx = int(tree[current_idx].parent)
        }
        // The path is backwards, so we need to reverse it.
        slice.reverse(raw_path[:])
        
        // Smooth the path and store it.
        path_points = generate_smooth_path(raw_path[:], 15)
        
        planning_complete = true
        fmt.println("Path found! Tree size:", len(tree))
    }
}

// --- Public Accessors ---

// draw_planner visualizes the RRT tree and the final path.
draw_planner :: proc() {
    // Draw tree edges
    for i in 1..<len(tree) {
        from := tree[i].position
        to := tree[tree[i].parent].position
        rl.DrawLine3D(from, to, rl.Color{100, 100, 100, 100})
    }

    // Draw the final smoothed path
    if len(path_points) > 1 {
        for i in 0..<len(path_points) - 1 {
            rl.DrawLine3D(path_points[i], path_points[i+1], rl.PURPLE)
            rl.DrawSphere(path_points[i], 0.1, rl.PURPLE)
        }
        rl.DrawSphere(path_points[len(path_points)-1], 0.1, rl.PURPLE)
    }
}

// get_full_path returns the current smoothed path.
get_full_path :: proc() -> []rl.Vector3 {
    return path_points[:]
}

// is_planning_complete returns true if a path has been found.
is_planning_complete :: proc() -> bool {
    return planning_complete
}
