package main

import rl "vendor:raylib"
import "core:math"

main :: proc() {
    SCREEN_WIDTH :: 800
    SCREEN_HEIGHT :: 450

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [models] example - plane rotations (yaw, pitch, roll)")

    camera := rl.Camera3D{
        position = {0.0, 50.0, -120.0},    // Camera position perspective
        target = {0.0, 0.0, 0.0},          // Camera looking at point
        up = {0.0, 1.0, 0.0},              // Camera up vector
        fovy = 30.0,                       // Camera field-of-view Y
        projection = .PERSPECTIVE,         // Camera type
    }

    // Load 3D model and texture
    model := rl.LoadModel("assets/plane.obj")
    texture := rl.LoadTexture("assets/plane_diffuse.png")
    model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture

    // Initialize rotation angles
    pitch := f32(0.0)
    roll := f32(0.0)
    yaw := f32(0.0)

    rl.SetTargetFPS(60)

    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        // Plane pitch (x-axis) controls
        if rl.IsKeyDown(.DOWN) {
            pitch += 0.6
        } else if rl.IsKeyDown(.UP) {
            pitch -= 0.6
        } else {
            if pitch > 0.3 do pitch -= 0.3
            else if pitch < -0.3 do pitch += 0.3
        }

        // Plane yaw (y-axis) controls
        if rl.IsKeyDown(.S) {
            yaw -= 1.0
        } else if rl.IsKeyDown(.A) {
            yaw += 1.0
        } else {
            if yaw > 0.0 do yaw -= 0.5
            else if yaw < 0.0 do yaw += 0.5
        }

        // Plane roll (z-axis) controls
        if rl.IsKeyDown(.LEFT) {
            roll -= 1.0
        } else if rl.IsKeyDown(.RIGHT) {
            roll += 1.0
        } else {
            if roll > 0.0 do roll -= 0.5
            else if roll < 0.0 do roll += 0.5
        }

        // Transformation matrix for rotations
        rotation := rl.Vector3{
            math.PI * pitch / 180.0,  // DEG2RAD equivalent
            math.PI * yaw / 180.0,
            math.PI * roll / 180.0,
        }
        model.transform = rl.MatrixRotateXYZ(rotation)
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        // Draw 3D model
        rl.BeginMode3D(camera)
        defer rl.EndMode3D()
        rl.DrawModel(model, {0.0, -8.0, 0.0}, 1.0, rl.WHITE)
        rl.DrawGrid(10, 10.0)
        
        // Draw controls info
        rl.DrawRectangle(30, 370, 260, 70, rl.Fade(rl.GREEN, 0.5))
        rl.DrawRectangleLines(30, 370, 260, 70, rl.Fade(rl.DARKGREEN, 0.5))
        rl.DrawText("Pitch controlled with: KEY_UP / KEY_DOWN", 40, 380, 10, rl.DARKGRAY)
        rl.DrawText("Roll controlled with: KEY_LEFT / KEY_RIGHT", 40, 400, 10, rl.DARKGRAY)
        rl.DrawText("Yaw controlled with: KEY_A / KEY_S", 40, 420, 10, rl.DARKGRAY)
        rl.DrawText("(c) WWI Plane Model by GiaHanLam", SCREEN_WIDTH - 240, SCREEN_HEIGHT - 20, 10, rl.DARKGRAY)
        rl.EndDrawing()
    }
    rl.UnloadModel(model)
    rl.UnloadTexture(texture)
    rl.CloseWindow()
}