package main

import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
    // Initialization
    screen_width:i32 = 800
    screen_height:i32 = 450

    rl.InitWindow(screen_width, screen_height, "Raylib [models] example - models loading")
    defer rl.CloseWindow()

    // Define the camera
    camera := rl.Camera3D{
        position   = {50, 50, 50},
        target     = {0, 10, 0},
        up         = {0, 1, 0},
        fovy       = 45,
        projection = .PERSPECTIVE,
    }

    // Load model and texture
    model := rl.LoadModel("assets/castle.obj")
    defer rl.UnloadModel(model)

    texture := rl.LoadTexture("assets/castle_diffuse.png")
    defer rl.UnloadTexture(texture)

    // Set model texture
    model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture

    position := rl.Vector3{0, 0, 0}

    // Calculate bounding box
    bounds := rl.GetMeshBoundingBox(model.meshes[0])

    selected := false

    rl.DisableCursor()
    rl.SetTargetFPS(60)

    // Main game loop
    for !rl.WindowShouldClose() {
        // Update camera
        rl.UpdateCamera(&camera, .FIRST_PERSON)

        // Handle file drops
        if rl.IsFileDropped() {
            dropped_files := rl.LoadDroppedFiles()
            defer rl.UnloadDroppedFiles(dropped_files)

            if dropped_files.count == 1 {
                file_path := dropped_files.paths[0]
                
                if rl.IsFileExtension(file_path, ".obj") {
                    // Unload previous model and load new one
                    rl.UnloadModel(model)
                    model = rl.LoadModel(file_path)
                    model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
                    bounds = rl.GetMeshBoundingBox(model.meshes[0])
                } 
                else if rl.IsFileExtension(file_path, ".png") {
                    // Unload current texture and load new one
                    rl.UnloadTexture(texture)
                    texture = rl.LoadTexture(file_path)
                    model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
                }
            }
        }

        // Model selection
        if rl.IsMouseButtonPressed(.LEFT) {
            ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), camera)
            collision := rl.GetRayCollisionBox(ray, bounds)
            
            if collision.hit {
                selected = !selected
            } else {
                selected = false
            }
        }

        // Draw
        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)

        rl.DrawModel(model, position, 1, rl.WHITE)
        rl.DrawGrid(20, 10)

        if selected {
            rl.DrawBoundingBox(bounds, rl.GREEN)
        }

        rl.EndMode3D()
        
        rl.DrawText("Drag & drop model to load mesh/texture.", 10, rl.GetScreenHeight() - 20, 10, rl.DARKGRAY)
        
        if selected {
            rl.DrawText("MODEL SELECTED", rl.GetScreenWidth() - 110, 10, 10, rl.GREEN)
        }

        rl.DrawText("(c) Castle 3D model by Alberto Cano", screen_width - 200, screen_height - 20, 10, rl.GRAY)
        rl.DrawFPS(10, 10)
    }
}