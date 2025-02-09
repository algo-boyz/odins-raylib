package main

import rl "vendor:raylib"

main :: proc() {
    rl.InitWindow(800, 600, "glb model animation")

    animCount:i32 = 0
    animFrame:i32 = 0
    model := rl.LoadModel("assets/orc_warrior.glb")
    animations := rl.LoadModelAnimations("assets/orc_warrior.glb", &animCount)

    // Create rotation matrix for -90 degrees around X-axis
    rotationMatrix := rl.MatrixRotateX(90 * rl.DEG2RAD)
    // Apply the rotation to the model's transform
    model.transform = rotationMatrix

    camera := rl.Camera{}
    camera.position = { 4, 4, 4 }
    camera.target = { 0, 2, 0 }
    camera.up = { 0, 1, 0 }
    camera.fovy = 60
    camera.projection = rl.CameraProjection.PERSPECTIVE

    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.BeginMode3D(camera)
            rl.DrawModel(model, { 0, 0, 0 }, 1, rl.WHITE)
            if rl.IsKeyDown(rl.KeyboardKey.W) {
                rl.UpdateModelAnimation(model, animations[0], animFrame)
                if (animFrame >= animations[0].frameCount) {
                    animFrame = 0
                }
                animFrame += 1
            }
            rl.DrawGrid(100, 5)
        rl.EndMode3D()
        rl.EndDrawing()
    }
    rl.CloseWindow()
}