package main

import rl "vendor:raylib"

main :: proc() {
    // Initialization
    screen_width :: 800
    screen_height :: 450

    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(screen_width, screen_height, "raylib [shaders] example - raymarching shapes")

    camera := rl.Camera{
        position = rl.Vector3{2.5, 2.5, 3.0},    // Camera position
        target = rl.Vector3{0.0, 0.0, 0.7},      // Camera looking at point
        up = rl.Vector3{0.0, 1.0, 0.0},          // Camera up vector
        fovy = 65.0,                             // Camera field-of-view Y
        projection = .PERSPECTIVE,                // Camera projection type
    }

    // Load raymarching shader
    // NOTE: Defining nil for vertex shader forces usage of internal default vertex shader
    shader := rl.LoadShader(nil, "assets/raymarching.fs")

    // Get shader locations for required uniforms
    view_eye_loc := rl.GetShaderLocation(shader, "viewEye")
    view_center_loc := rl.GetShaderLocation(shader, "viewCenter")
    run_time_loc := rl.GetShaderLocation(shader, "runTime")
    resolution_loc := rl.GetShaderLocation(shader, "resolution")

    resolution := [2]f32{f32(screen_width), f32(screen_height)}
    rl.SetShaderValue(shader, resolution_loc, &resolution, .VEC2)

    run_time: f32 = 0.0

    rl.DisableCursor()                   // Limit cursor to relative movement inside the window
    rl.SetTargetFPS(60)                  // Set our game to run at 60 frames-per-second

    for !rl.WindowShouldClose() {        // Detect window close button or ESC key
        // Update
        rl.UpdateCamera(&camera, .FIRST_PERSON)

        camera_pos := [3]f32{camera.position.x, camera.position.y, camera.position.z}
        camera_target := [3]f32{camera.target.x, camera.target.y, camera.target.z}

        delta_time := rl.GetFrameTime()
        run_time += delta_time

        // Set shader required uniform values
        rl.SetShaderValue(shader, view_eye_loc, &camera_pos, .VEC3)
        rl.SetShaderValue(shader, view_center_loc, &camera_target, .VEC3)
        rl.SetShaderValue(shader, run_time_loc, &run_time, .FLOAT)

        // Check if screen is resized
        if rl.IsWindowResized() {
            resolution = [2]f32{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
            rl.SetShaderValue(shader, resolution_loc, &resolution, .VEC2)
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        // We only draw a white full-screen rectangle,
        // frame is generated in shader using raymarching
        rl.BeginShaderMode(shader)
        rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.WHITE)
        rl.EndShaderMode()

        rl.DrawText("🔆 Raytracing fluid simulation", 
                    rl.GetScreenWidth() - 280, 
                    rl.GetScreenHeight() - 20, 
                    10, 
                    rl.BLACK)
        rl.EndDrawing()
    }

    // De-Initialization
    rl.UnloadShader(shader)           // Unload shader
    rl.CloseWindow()                  // Close window and OpenGL context
}