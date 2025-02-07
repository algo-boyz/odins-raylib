package astar

import "core:fmt"
import "core:math"

import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

Map :: struct {
    camera: rl.Camera3D,
    start_pos: [3]f32,
    end_pos: [3]f32,
    obstacles: [dynamic][3]f32,
    astar: AStar,
    grid_size: i32,
    cell_size: f32,
}

init_map :: proc() -> Map {
    scene: Map
    // Init camera
    scene.camera = rl.Camera3D{
        position = {20, 20, 20},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45,
        projection = rl.CameraProjection.PERSPECTIVE,
    }
    // Init grid parameters
    scene.grid_size = 20
    scene.cell_size = 1.0
    // Set start and end positions
    scene.start_pos = {2, 0, 2}
    scene.end_pos = {15, 0, 15}
    // Init A*
    resolution := scene.cell_size
    init(&scene.astar, resolution, resolution, 1.0, 0.5)
    scene.astar.origin = {-1, -1, -1}
    scene.astar.map_size = {f32(scene.grid_size + 2), f32(scene.grid_size + 2), f32(scene.grid_size + 2)}
    // Create some obstacles
    scene.obstacles = make([dynamic][3]f32)
    for i := 0; i < 50; i += 1 {
        pos := [3]f32{
            f32(rl.GetRandomValue(0, scene.grid_size-1)),
            0,
            f32(rl.GetRandomValue(0, scene.grid_size-1)),
        }
        // Don't place obstacles at start or end
        if !rl.Vector3Equals(rl.Vector3{pos.x, pos.y, pos.z}, rl.Vector3{scene.start_pos.x, scene.start_pos.y, scene.start_pos.z}) &&
           !rl.Vector3Equals(rl.Vector3{pos.x, pos.y, pos.z}, rl.Vector3{scene.end_pos.x, scene.end_pos.y, scene.end_pos.z}) {
            append(&scene.obstacles, pos)
        }
    }
    return scene
}

update_map :: proc(m: ^Map) {
    rl.UpdateCamera(&m.camera, rl.CameraMode.ORBITAL)
}

draw_map :: proc(m: ^Map) {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.RAYWHITE)
    rl.BeginMode3D(m.camera)
    // Draw grid
    for i:i32; i < m.grid_size; i += 1 {
        for j:i32; j < m.grid_size; j += 1 {
            pos := rl.Vector3{f32(i), 0, f32(j)}
            rl.DrawCube(pos, 1, 0.1, 1, rl.LIGHTGRAY)
            rl.DrawCubeWires(pos, 1, 0.1, 1, rl.GRAY)
        }
    }
    // Draw obstacles
    for obstacle in m.obstacles {
        pos := rl.Vector3{obstacle.x, obstacle.y + 0.5, obstacle.z}
        rl.DrawCube(pos, 1, 1, 1, rl.GRAY)
        rl.DrawCubeWires(pos, 1, 1, 1, rl.DARKGRAY)
    }
    // Draw start position
    rl.DrawSphere(rl.Vector3{m.start_pos.x, m.start_pos.y + 0.5, m.start_pos.z}, 0.3, rl.GREEN)
    rl.DrawCubeWires(rl.Vector3{m.start_pos.x, m.start_pos.y + 0.5, m.start_pos.z}, 0.6, 0.6, 0.6, rl.DARKGREEN)
    // Draw end position
    rl.DrawSphere(rl.Vector3{m.end_pos.x, m.end_pos.y + 0.5, m.end_pos.z}, 0.3, rl.RED)
    rl.DrawCubeWires(rl.Vector3{m.end_pos.x, m.end_pos.y + 0.5, m.end_pos.z}, 0.6, 0.6, 0.6, rl.MAROON)
    // Draw explored nodes
    for node in m.astar.nodes {
        if node.state == NodeState.IN_CLOSE_SET {
            pos := rl.Vector3{node.position.x, node.position.y + 0.3, node.position.z}
            rl.DrawSphere(pos, 0.1, rl.Fade(rl.BLUE, 0.3))
        }
    }
    // Draw path
    if m.astar.has_path {
        for i := 0; i < len(m.astar.path_nodes)-1; i += 1 {
            start := m.astar.path_nodes[i].position
            end := m.astar.path_nodes[i+1].position
            start_pos := rl.Vector3{start.x, start.y + 0.5, start.z}
            end_pos := rl.Vector3{end.x, end.y + 0.5, end.z}
            rl.DrawLine3D(start_pos, end_pos, rl.GOLD)
            rl.DrawSphere(start_pos, 0.2, rl.ORANGE)
        }
        // Draw last node of path
        if len(m.astar.path_nodes) > 0 {
            last := m.astar.path_nodes[len(m.astar.path_nodes)-1].position
            rl.DrawSphere(rl.Vector3{last.x, last.y + 0.5, last.z}, 0.2, rl.ORANGE)
        }
    }
    rl.EndMode3D()
    rl.DrawText("A* Pathfinder", 10, 10, 20, rl.DARKGRAY)
    rl.DrawText("Press SPACE to find path", 10, 70, 20, rl.DARKGRAY)
    rl.DrawText("Press R to reset", 10, 100, 20, rl.DARKGRAY)
}

destroy_map :: proc(m: ^Map) {
    delete(m.obstacles)
    destroy(&m.astar)
}

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "A* Pathfinder")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    m := init_map()
    defer destroy_map(&m)
    for !rl.WindowShouldClose() {
        update_map(&m)
        // Handle input
        if rl.IsKeyPressed(.SPACE) {
            if !m.astar.has_path {
                reset(&m.astar)
                if search(&m) == Result.PATH_NOT_FOUND {
                    fmt.println("No path found!")
                }
            }
        }
        if rl.IsKeyPressed(.R) {
            m.astar.has_path = false
            reset(&m.astar)
        }
        draw_map(&m)
    }
}