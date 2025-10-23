package ecs

import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"
import "../../trees/octree"
import "../../../rlutil/geom"

WIDTH    :: 800
HEIGHT   :: 600
TAG_SIZE :: 128

// Global model manager
ModelManager :: struct {
    models: map[string]rl.Model,
}

g_model_manager: ModelManager

// Node in a circular linked list - now with octree integration
Node :: struct {
    id:           u32,                                 // Unique ID for octree operations
    model_key:    string,
    pos:          rl.Vector3,
    bb:           rl.BoundingBox,
    tick:         proc(node: ^Node),                   // Custom tick func
    on_collision: proc(node: ^Node, other: ^Node),     // Custom collision func
    next:         ^Node,
    tags:         [TAG_SIZE]u8,
    // Octree-specific fields
    old_bounds:   geom.Aabb,                          // Track previous bounds for updates
    velocity:     rl.Vector3,                         // For movement prediction
    radius:       f32,                                // Collision radius
}

// ECS World with octree integration
ECSWorld :: struct {
    head:         ^Node,
    octree:       octree.Octree(^Node),
    next_id:      u32,
    world_bounds: geom.Aabb,
}

g_world: ECSWorld

// Helper function to convert rl.BoundingBox to geom.Aabb
bb_to_aabb :: proc(bb: rl.BoundingBox) -> geom.Aabb {
    return geom.Aabb{
        min = {bb.min.x, bb.min.y, bb.min.z},
        max = {bb.max.x, bb.max.y, bb.max.z},
    }
}

// Helper function to convert rl.Vector3 to [3]f32
vec3_to_array :: proc(v: rl.Vector3) -> [3]f32 {
    return {v.x, v.y, v.z}
}

// Bounds function for octree - returns AABB of a node
node_bounds :: proc(node: ^Node) -> geom.Aabb {
    center := vec3_to_array(node.pos)
    radius := node.radius
    return geom.Aabb{
        min = center - {radius, radius, radius},
        max = center + {radius, radius, radius},
    }
}

// Point function for octree - returns center point of a node
node_point :: proc(node: ^Node) -> [3]f32 {
    return vec3_to_array(node.pos)
}

// Init ECS World with octree
init_ecs_world :: proc(bounds: geom.Aabb) {
    g_world.head = nil
    g_world.next_id = 1
    g_world.world_bounds = bounds
    
    octree.init(&g_world.octree, bounds, 6, 10) // max_depth=6, max_items=10
    g_world.octree.bounds_func = node_bounds
    g_world.octree.point_func = node_point
}

// Cleanup ECS World
deinit_ecs_world :: proc() {
    unload_nodes(g_world.head)
    octree.deinit(&g_world.octree)
}

// Model management functions
init_model_manager :: proc() {
    g_model_manager.models = make(map[string]rl.Model)
}

load_model :: proc(key: string, filepath: string) -> bool {
    if key in g_model_manager.models {
        fmt.printf("Model '%s' already loaded\n", key)
        return true
    }
    
    model := rl.LoadModel(strings.clone_to_cstring(filepath))
    if model.meshCount == 0 {
        fmt.printf("Failed to load model: %s\n", filepath)
        return false
    }
    
    g_model_manager.models[key] = model
    fmt.printf("Loaded model '%s' from %s\n", key, filepath)
    return true
}

get_model :: proc(key: string) -> (rl.Model, bool) {
    model, exists := g_model_manager.models[key]
    return model, exists
}

unload_all_models :: proc() {
    for key, model in g_model_manager.models {
        rl.UnloadModel(model)
        fmt.printf("Unloaded model '%s'\n", key)
    }
    delete(g_model_manager.models)
}

// Node creation with octree integration
new_node :: proc(model_key: string, pos: rl.Vector3, radius: f32, play, tick: proc(node: ^Node), collide: proc(node: ^Node, other: ^Node)) -> ^Node {
    model, exists := get_model(model_key)
    if !exists {
        fmt.printf("Error: Model '%s' not found\n", model_key)
        return nil
    }
    
    n := new(Node)
    n.id = g_world.next_id
    g_world.next_id += 1
    n.model_key = model_key
    n.pos = pos
    n.radius = radius
    n.bb = rl.GetModelBoundingBox(model)
    n.tick = tick
    n.on_collision = collide
    n.next = nil
    n.velocity = {0, 0, 0}
    n.old_bounds = node_bounds(n)
    mem.zero_slice(n.tags[:])
    
    play(n) // Init the node
    
    // Insert into octree
    if !octree.insert(&g_world.octree, n) {
        fmt.printf("Warning: Failed to insert node %d into octree\n", n.id)
    }
    
    return n
}

// Insert a node at the end of the circular linked list with octree integration
insert_end :: proc(model_key: string, pos: rl.Vector3, radius: f32, play, tick: proc(node: ^Node), collide: proc(node: ^Node, other: ^Node)) -> bool {
    n := new_node(model_key, pos, radius, play, tick, collide)
    if n == nil {
        return false
    }
    
    if g_world.head == nil {
        g_world.head = n
        n.next = g_world.head
    } else {
        tmp := g_world.head
        for tmp.next != g_world.head {
            tmp = tmp.next
        }
        tmp.next = n
        n.next = g_world.head
    }
    return true
}

// Update node position in octree
update_node_in_octree :: proc(node: ^Node) {
    new_bounds := node_bounds(node)
    
    // Only update octree if bounds changed significantly
    if !geom.aabb_contains(node.old_bounds, new_bounds) || 
       !geom.aabb_contains(new_bounds, node.old_bounds) {
        
        if !octree.update(&g_world.octree, node, node) {
            // If update failed, try remove and insert
            octree.remove(&g_world.octree, node)
            if !octree.insert(&g_world.octree, node) {
                fmt.printf("Warning: Failed to reinsert node %d into octree\n", node.id)
            }
        }
        node.old_bounds = new_bounds
    }
}

render_nodes :: proc() {
    if g_world.head == nil do return
    tmp := g_world.head
    for {
        model, exists := get_model(tmp.model_key)
        if exists {
            rl.DrawModel(model, tmp.pos, 1, rl.WHITE)
        } else {
            fmt.printf("Warning: Model '%s' not found\n", tmp.model_key)
        }
        
        // Update node logic
        tmp.tick(tmp)
        
        // Update octree position
        update_node_in_octree(tmp)
        
        tmp = tmp.next
        if tmp == g_world.head do break
    }
}

update_bbs :: proc() {
    if g_world.head == nil do return
    tmp := g_world.head
    for {
        model, exists := get_model(tmp.model_key)
        if exists {
            tmp.bb = rl.GetModelBoundingBox(model)
            tmp.bb.min += tmp.pos
            tmp.bb.max += tmp.pos
        }
        tmp = tmp.next
        if tmp == g_world.head do break
    }
}

// Optimized collision detection using octree
check_collisions :: proc() {
    if g_world.head == nil do return
    
    nearby_nodes := make([dynamic]^Node, 0, 32)
    defer delete(nearby_nodes)
    
    tmp := g_world.head
    for {
        // Query octree for nearby nodes using sphere query
        center := vec3_to_array(tmp.pos)
        query_radius := tmp.radius * 2.0 // Check within double radius
        
        octree.query_sphere(&g_world.octree, center, query_radius, &nearby_nodes)
        
        // Check collisions with nearby nodes only
        for other in nearby_nodes {
            if tmp != other {
                distance := rl.Vector3Distance(tmp.pos, other.pos)
                collision_distance := tmp.radius + other.radius
                
                if distance <= collision_distance {
                    if tmp.on_collision != nil {
                        tmp.on_collision(tmp, other)
                    }
                }
            }
        }
        
        clear(&nearby_nodes)
        tmp = tmp.next
        if tmp == g_world.head do break
    }
}

// Query nodes in a specific area
query_nodes_in_area :: proc(bounds: geom.Aabb, result: ^[dynamic]^Node) {
    octree.query_aabb(&g_world.octree, bounds, result)
}

// Query nodes near a point
query_nodes_near_point :: proc(center: [3]f32, radius: f32, result: ^[dynamic]^Node) {
    octree.query_sphere(&g_world.octree, center, radius, result)
}

// Raycast to find nodes
raycast_nodes :: proc(origin, direction: [3]f32, max_distance: f32, result: ^[dynamic]^Node) {
    ray := octree.Ray{origin = origin, direction = direction}
    octree.query_ray(&g_world.octree, ray, max_distance, result)
}

unload_nodes :: proc(head: ^Node) {
    if head == nil do return
    tmp := head
    for {
        node := tmp.next
        octree.remove(&g_world.octree, tmp) // Remove from octree
        free(tmp)
        tmp = node
        if tmp == head do break
    }
}

// Debug: Get octree statistics
get_octree_stats :: proc() -> octree.Stats {
    return octree.get_stats(&g_world.octree)
}

// Debug: Render octree bounds (for visualization)
render_octree_debug :: proc(node: ^octree.Node(^Node), depth: i32 = 0) {
    if node == nil do return
    
    // Only render leaf nodes or nodes with items
    if node.children[0] == nil || len(node.items) > 0 {
        min := node.bounds.min
        max := node.bounds.max
        
        color := depth == 0 ? rl.RED : 
                depth == 1 ? rl.GREEN :
                depth == 2 ? rl.BLUE : rl.YELLOW
        
        rl.DrawBoundingBox(
            rl.BoundingBox{
                min = {min.x, min.y, min.z},
                max = {max.x, max.y, max.z}
            }, 
            color
        )
    }
    
    // Recursively render children
    if node.children[0] != nil {
        for i in 0..<8 {
            render_octree_debug(node.children[i], depth + 1)
        }
    }
}

// Example behavior functions
play :: proc(n: ^Node) {
    fmt.printf("Spawned actor %d with model '%s' at position: (%f, %f, %f)\n", 
               n.id, n.model_key, n.pos.x, n.pos.y, n.pos.z)
    if n.pos.x < 0 {
        n.tags[0] = 'F'
    } else {
        n.tags[0] = 'B'
    }
}

tick :: proc(n: ^Node) {
    // Update direction based on position
    if n.pos.x < -3 {
        n.tags[0] = 'F'
    } else if n.pos.x > 3 {
        n.tags[0] = 'B'
    }
    
    // Move the node
    speed: f32 = 0.025
    n.velocity.x = (n.tags[0] == 'F') ? speed : -speed
    n.pos.x += n.velocity.x
}

collide :: proc(node: ^Node, other: ^Node) {
    distance := rl.Vector3Distance(node.pos, other.pos)
    collision_distance := node.radius + other.radius
    
    if distance <= collision_distance {
        model, exists := get_model(node.model_key)
        if exists {
            rl.DrawModelWires(model, node.pos, 1, rl.RED)
            rl.DrawSphereWires(linalg.lerp(node.pos, other.pos, 0.1), 0.5, 8, 8, rl.PURPLE)
        }
        
        // Bounce logic
        if node.tags[0] == 'F' && other.tags[0] == 'B' {
            node.tags[0] = 'B'
        } else if node.tags[0] == 'B' && other.tags[0] == 'B' {
            node.tags[0] = 'F'
        }
    }
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "ECS with Octree")
    rl.SetTargetFPS(60)

    init_model_manager()
    defer unload_all_models()

    // Init world bounds (20x20x20 cube centered at origin)
    world_bounds := geom.Aabb{
        min = {-10, -10, -10},
        max = { 10,  10,  10},
    }
    init_ecs_world(world_bounds)
    defer deinit_ecs_world()

    load_model("bullet", "../assets/bullet.obj")
    
    cam := rl.Camera{
        position = {0, 10, 10},
        target   = {0, 0, 0},
        up       = {0, 1, 0},
        fovy     = 45,
        projection = rl.CameraProjection.PERSPECTIVE,
    }
    
    // Insert nodes with collision radius
    insert_end("bullet", { 0, 0, 0}, 0.5, play, tick, collide)
    insert_end("bullet", { 2, 0, 0}, 0.5, play, tick, collide)
    insert_end("bullet", {-2, 0, 0}, 0.5, play, tick, collide)
    
    // Add more nodes for testing octree performance
    for i in 0..<10 {
        x := f32(i - 5) * 0.8
        z := f32(i % 3 - 1) * 0.8
        insert_end("bullet", {x, 0, z}, 0.3, play, tick, collide)
    }
    show_octree_debug := false
    
    for !rl.WindowShouldClose() {
        // Toggle octree debug visualization
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            show_octree_debug = !show_octree_debug
        }
        
        update_bbs()    // Update bounding boxes
        rl.BeginDrawing()
            rl.ClearBackground(rl.RAYWHITE)
            rl.BeginMode3D(cam)
                check_collisions()  // Now uses octree for optimization
                render_nodes()
                
                // Debug: Render octree structure
                if show_octree_debug {
                    render_octree_debug(g_world.octree.root)
                }
            rl.EndMode3D()
            
            rl.DrawText("Entity Component System with Octree", 10, 10, 20, rl.DARKGRAY)
            rl.DrawText("Press SPACE to toggle octree debug view", 10, 35, 16, rl.GRAY)
            
            // Show octree stats
            stats := get_octree_stats()
            stats_text := fmt.tprintf("Octree Stats - Nodes: %d, Items: %d, Max Depth: %d", 
                                    stats.num_nodes, stats.num_items, stats.max_depth)
            rl.DrawText(strings.clone_to_cstring(stats_text), 10, HEIGHT - 60, 14, rl.DARKBLUE)
            
        rl.EndDrawing()
    }
    rl.CloseWindow()
}