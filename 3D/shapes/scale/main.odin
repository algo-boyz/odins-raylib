package main

import rl "vendor:raylib"

main :: proc() {
    screenWidth:i32 = 800;
    screenHeight:i32 = 450;

    rl.InitWindow(screenWidth, screenHeight, "Scale");

    camera : rl.Camera3D;
    camera.position    = rl.Vector3{0.0, 10.0, 10.0}; 
    camera.target      = rl.Vector3{0.0, 0.0, 0.0};   
    camera.up          = rl.Vector3{0.0, 1.0, 0.0};   
    camera.fovy        = 45.0;                        
    camera.projection  = rl.CameraProjection.PERSPECTIVE;

    cubePosition : rl.Vector3 = rl.Vector3{0.0, 0.0, 0.0};
    scale:f32 = 2  // Start with basic cube

    rl.SetTargetFPS(60);

    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&camera, rl.CameraMode.FREE);
        if rl.IsKeyPressed(rl.KeyboardKey.Z) { 
            camera.target = rl.Vector3{0.0, 0.0, 0.0}
        }
        if rl.IsKeyPressed(rl.KeyboardKey.P) {
            scale = clamp(scale + 1, 0, 10)
        } 
        if rl.IsKeyPressed(rl.KeyboardKey.M) {
            scale = clamp(scale - 1, 0, 10)
        }
        rl.BeginDrawing();
        rl.ClearBackground(rl.RAYWHITE);

        rl.BeginMode3D(camera);

        rl.DrawGrid(10, 1.0);
        cubePosition.y = scale / 2 
        rl.DrawCubeWires(cubePosition, scale, scale, scale, rl.RED);

        rl.EndMode3D();

        rl.DrawText(rl.TextFormat("Scale: %f (Press P to increase, M to decrease)", scale), 10, 70, 20, rl.DARKGRAY)
        rl.DrawFPS(10, 10);

        rl.EndDrawing();
    }

    rl.CloseWindow();
}