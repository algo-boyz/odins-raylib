package main

import rl "vendor:raylib"

main :: proc() {

    screenWidth :: 800
    screenHeight :: 450

    rl.InitWindow(screenWidth, screenHeight, "heightmap loading and drawing")

    camera := rl.Camera3D{}
    camera.position = rl.Vector3{ 180, 210, 180 }     // Camera position
    camera.target = rl.Vector3{ 00, 00, 00 }          // Camera looking at point
    camera.up = rl.Vector3{ 00, 10, 00 }              // Camera up vector (rotation towards target)
    camera.fovy = 450                                 // Camera field-of-view Y
    camera.projection = rl.CameraProjection.PERSPECTIVE      

    image := rl.LoadImage("assets/height_map.png")     // Load heightmap image (RAM)
    texture := rl.LoadTextureFromImage(image)         // Convert image to texture (VRAM)

    mesh := rl.GenMeshHeightmap(image, rl.Vector3{ 16, 8, 16 }) // Generate heightmap mesh (RAM and VRAM)
    model := rl.LoadModelFromMesh(mesh)

    model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture // Set map diffuse texture
    mapPosition := rl.Vector3{ -80, 00, -80 }                             // Define model position

    rl.UnloadImage(image)             // Unload heightmap image from RAM, already uploaded to VRAM

    rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second

    for (!rl.WindowShouldClose()) {
        rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL)
        rl.BeginDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)

        rl.DrawModel(model, mapPosition, 10, rl.RED)

        rl.DrawGrid(20, 10)

        rl.EndMode3D()

        rl.DrawTexture(texture, screenWidth - texture.width - 20, 20, rl.WHITE)
        rl.DrawRectangleLines(screenWidth - texture.width - 20, 20, texture.width, texture.height, rl.GREEN)

        rl.DrawFPS(10, 10)

        rl.EndDrawing()
    }
    rl.UnloadTexture(texture)
    rl.UnloadModel(model)
    rl.CloseWindow()
}