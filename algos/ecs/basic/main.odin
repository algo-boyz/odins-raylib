package ecs

import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

WIDTH    :: 800
HEIGHT   :: 600
TAG_SIZE :: 128

// Global model manager
ModelManager :: struct {
    models: map[string]rl.Model,
}

g_model_manager: ModelManager

// Node in circular linked list
Node :: struct {
    model_key:    string,
    pos:          rl.Vector3,
    bb:           rl.BoundingBox,
    tick:         proc(node: ^Node),                   // Custom tick func
    on_collision: proc(node: ^Node, other: ^Node),     // Custom collision func
    next:         ^Node,
    tags:         [TAG_SIZE]u8,
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

// Node creation with model key instead of model directly
new_node :: proc(model_key: string, pos: rl.Vector3, play, tick: proc(node: ^Node), collide: proc(node: ^Node, other: ^Node)) -> ^Node {
    model, exists := get_model(model_key)
    if !exists {
        fmt.printf("Error: Model '%s' not found\n", model_key)
        return nil
    }
    
    n := new(Node)
    n.model_key = model_key
    n.pos = pos
    n.bb = rl.GetModelBoundingBox(model)
    n.tick = tick
    n.on_collision = collide
    n.next = nil
    mem.zero_slice(n.tags[:])
    play(n) // The struct does not have to store the function; it plays exactly once
    return n
}

// Insert a node at the end of the circular linked list
insert_end :: proc(head: ^^Node, model_key: string, pos: rl.Vector3, play, tick: proc(node: ^Node), collide: proc(node: ^Node, other: ^Node)) -> bool {
    n := new_node(model_key, pos, play, tick, collide)
    if n == nil {
        return false
    }
    
    if head^ == nil {
        head^ = n
        n.next = head^
    } else {
        tmp := head^
        for tmp.next != head^ {
            tmp = tmp.next
        }
        tmp.next = n
        n.next = head^
    }
    return true
}

render_nodes :: proc(head: ^Node) {
    if head == nil do return
    tmp := head
    for {
        model, exists := get_model(tmp.model_key)
        if exists {
            rl.DrawModel(model, tmp.pos, 1, rl.WHITE)
        } else {
            fmt.printf("Warning: Model '%s' not found\n", tmp.model_key)
        }
        tmp.tick(tmp)
        tmp = tmp.next
        if tmp == head do break
    }
}

update_bbs :: proc(head: ^Node) {
    if head == nil do return
    tmp := head
    for {
        model, exists := get_model(tmp.model_key)
        if exists {
            tmp.bb = rl.GetModelBoundingBox(model)
            tmp.bb.min += tmp.pos
            tmp.bb.max += tmp.pos
        }
        tmp = tmp.next
        if tmp == head do break
    }
}

check_collisions :: proc(head: ^Node) {
    if head == nil do return
    tmp := head
    for {
        other := head
        for {
            if tmp != other && rl.CheckCollisionBoxes(tmp.bb, other.bb) {
                if tmp.on_collision != nil {
                    tmp.on_collision(tmp, other)
                }
            }
            other = other.next
            if other == head do break
        }
        tmp = tmp.next
        if tmp == head do break
    }
}

unload_nodes :: proc(head: ^Node) {
    if head == nil do return
    tmp := head
    for {
        node := tmp.next
        free(tmp)
        tmp = node
        if tmp == head do break
    }
}

play :: proc(n: ^Node) {
    fmt.printf("Spawned actor with model '%s' at position: (%f, %f, %f)\n", 
               n.model_key, n.pos.x, n.pos.y, n.pos.z)
    if n.pos.x < 0 {
        n.tags[0] = 'F'
    } else {
        n.tags[0] = 'B'
    }
}

tick :: proc(n: ^Node) {
    if n.pos.x < -3 {
        n.tags[0] = 'F'
    } else if n.pos.x > 3 {
        n.tags[0] = 'B'
    }
    n.pos.x += (n.tags[0] == 'F') ? 0.025 : -0.025
}

collide :: proc(node: ^Node, other: ^Node) {
    if rl.Vector3Distance(node.pos, other.pos) >= 0.5 { // Bounce back
        model, exists := get_model(node.model_key)
        if exists {
            rl.DrawModelWires(model, node.pos, 1, rl.RED)
            rl.DrawSphereWires(linalg.lerp(node.pos, other.pos, 0.1), 0.5, 8, 8, rl.PURPLE)
        }
    } else if node.tags[0] == 'F' && other.tags[0] == 'B' {
        node.tags[0] = 'B'
    } else if node.tags[0] == 'B' && other.tags[0] == 'B' {
        node.tags[0] = 'F'
    }
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "ECS")
    rl.SetTargetFPS(60)

    init_model_manager()
    defer unload_all_models()

    load_model("bullet", "../assets/bullet.obj")
    cam := rl.Camera{
        position = {0, 10, 10},
        target   = {0, 0, 0},
        up       = {0, 1, 0},
        fovy     = 45,
        projection = rl.CameraProjection.PERSPECTIVE,
    }
    head: ^Node = nil   // Init circular linked list
    // Insert nodes using model keys - same model can be used multiple times
    insert_end(&head, "bullet", { 0, 0, 0 }, play, tick, collide)
    insert_end(&head, "bullet", { 2, 0, 0 }, play, tick, collide)
    insert_end(&head, "bullet", {-2, 0, 0 }, play, tick, collide)
    defer unload_nodes(head)
    
    for !rl.WindowShouldClose() {
        update_bbs(head)    // Update bounding boxes
        rl.BeginDrawing()
            rl.ClearBackground(rl.RAYWHITE)
            rl.BeginMode3D(cam)
                check_collisions(head)
                render_nodes(head)
            rl.EndMode3D()
            rl.DrawText("Entity Component System (ECS)", 10, 10, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}