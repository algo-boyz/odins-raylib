package main

import "core:fmt"
import "vendor:raylib"

main :: proc() {
    screen_width:i32 = 800
    screen_height:i32 = 450

    raylib.InitWindow(screen_width, screen_height, "Raylib [models] example - loading gltf animations")
    defer raylib.CloseWindow()

    // Define camera
    camera := raylib.Camera3D {
        position   = raylib.Vector3{ 6.0, 6.0, 6.0 },
        target     = raylib.Vector3{ 0.0, 2.0, 0.0 },
        up         = raylib.Vector3{ 0.0, 1.0, 0.0 },
        fovy       = 45.0,
        projection = .PERSPECTIVE,
    }

    // Load model and animations
    model := raylib.LoadModel("assets/robot.glb")
    defer raylib.UnloadModel(model)

    position := raylib.Vector3{ 0.0, 0.0, 0.0 }

    anim_count: i32
    model_animations := raylib.LoadModelAnimations("assets/robot.glb", &anim_count)
    defer raylib.UnloadModelAnimations(model_animations, anim_count)

    anim_index: u32 = 0
    anim_current_frame: u32 = 0

    raylib.SetTargetFPS(60)

    for !raylib.WindowShouldClose() {
        raylib.UpdateCamera(&camera, .ORBITAL)

        // Switch animations with mouse buttons
        if raylib.IsMouseButtonPressed(.RIGHT) {
            anim_index = (anim_index + 1) % cast(u32)anim_count
        } else if raylib.IsMouseButtonPressed(.LEFT) {
            anim_index = (anim_index + cast(u32)anim_count - 1) % cast(u32)anim_count
        }

        // Update model animation
        anim := model_animations[anim_index]
        anim_current_frame = (anim_current_frame + 1) % cast(u32)anim.frameCount
        raylib.UpdateModelAnimation(model, anim, cast(i32)anim_current_frame)

        raylib.BeginDrawing()
        defer raylib.EndDrawing()

        raylib.ClearBackground(raylib.RAYWHITE)

        raylib.BeginMode3D(camera)
        defer raylib.EndMode3D()

        raylib.DrawModel(model, position, 1.0, raylib.WHITE)
        raylib.DrawGrid(10, 1.0)

        raylib.DrawText("Use LEFT/RIGHT mouse buttons to switch animation", 10, 10, 20, raylib.GRAY)
        raylib.DrawText(raylib.TextFormat("Animation: %s", anim.name), 10, raylib.GetScreenHeight() - 20, 10, raylib.DARKGRAY)
    }
}