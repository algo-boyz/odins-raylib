package main

import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
    screen_width:i32 = 800
    screen_height:i32 = 450

    rl.InitWindow(screen_width, screen_height, "Raylib [models] example - loading gltf animations")
    defer rl.CloseWindow()

    // Define camera
    camera := rl.Camera3D {
        position   = rl.Vector3{ 6.0, 6.0, 6.0 },
        target     = rl.Vector3{ 0.0, 2.0, 0.0 },
        up         = rl.Vector3{ 0.0, 1.0, 0.0 },
        fovy       = 45.0,
        projection = .PERSPECTIVE,
    }

    // Load model and animations
    robot:cstring = "assets/robot.glb"
    
    model := rl.LoadModel(robot)
    defer rl.UnloadModel(model)
    // Load skinning shader
    skinningShader := rl.LoadShader("assets/skinning.vs", "assets/skinning.fs")
    defer rl.UnloadShader(skinningShader)
    model.materials[0].shader = skinningShader

    position := rl.Vector3{ 0.0, 0.0, 0.0 }

    anim_count: i32
    model_animations := rl.LoadModelAnimations(robot, &anim_count)
    defer rl.UnloadModelAnimations(model_animations, anim_count)

    anim_index: u32 = 0
    anim_current_frame: u32 = 0

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&camera, .ORBITAL)

        // Switch animations with mouse buttons
        if rl.IsMouseButtonPressed(.RIGHT) {
            anim_index = (anim_index + 1) % cast(u32)anim_count
        } else if rl.IsMouseButtonPressed(.LEFT) {
            anim_index = (anim_index + cast(u32)anim_count - 1) % cast(u32)anim_count
        }

        // Update model animation
        anim := model_animations[anim_index]
        anim_current_frame = (anim_current_frame + 1) % cast(u32)anim.frameCount
        rl.UpdateModelAnimation(model, anim, cast(i32)anim_current_frame)

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)
        defer rl.EndMode3D()

        rl.DrawModel(model, position, 1.0, rl.WHITE)
        rl.DrawGrid(10, 1.0)

        rl.DrawText("Use LEFT/RIGHT mouse buttons to switch animation", 10, 10, 20, rl.GRAY)
        rl.DrawText(rl.TextFormat("Animation: %s", anim.name), 10, rl.GetScreenHeight() - 20, 10, rl.DARKGRAY)
    }
}