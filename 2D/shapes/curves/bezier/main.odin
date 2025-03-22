package line_bezier

/*******************************************************************************************
*
*   raylib [shapes] example - Cubic-bezier lines
*
*   Example originally created with raylib 1.7, last time updated with raylib 1.7
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2017-2024 Ramon Santamaria (@raysan5)
*   Translation to Odin by Evan Martinez (@Nave55)
*
*   https://github.com/Nave55/Odin-Raylib-Examples/blob/main/Core/line_bezier.odin
*
********************************************************************************************/

import rl "vendor:raylib"

SCREEN_WIDTH ::  800
SCREEN_HEIGHT :: 450
FPS ::           60

mouse:             rl.Vector2
start_point:       rl.Vector2
end_point:         rl.Vector2
move_start_point:  bool
move_end_point:    bool


main :: proc() {
    // Set config flags and manage winddo
    rl.SetConfigFlags(rl.ConfigFlags({.MSAA_4X_HINT}))
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - cubic-bezier lines")
    defer rl.CloseWindow()
    rl.SetTargetFPS(FPS)

    // init game state and then run main game loop
    initGame()
    for !rl.WindowShouldClose() do updateGame()

}

initGame :: proc() {
    // init game variables
    start_point = {30, 30}
    end_point = {f32(SCREEN_WIDTH - 30), f32(SCREEN_HEIGHT - 30)}
    move_start_point = false
    move_end_point = false
}

gameLogic :: proc() {
    mouse = rl.GetMousePosition()

    if rl.CheckCollisionPointCircle(mouse, start_point, 10.0) && rl.IsMouseButtonDown(.LEFT) do move_start_point = true
    else if rl.CheckCollisionPointCircle(mouse, end_point, 10.0) && rl.IsMouseButtonDown(.LEFT) do move_end_point = true

    if move_start_point {
        start_point = mouse;
        if rl.IsMouseButtonReleased(.LEFT) do move_start_point = false
    }

    if move_end_point {
        end_point = mouse;
        if rl.IsMouseButtonReleased(.LEFT) do move_end_point = false;
    }
}

drawGame :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.RAYWHITE)

    rl.DrawText("MOVE START-END POINTS WITH MOUSE", 15, 20, 20, rl.GRAY)

    // Draw line Cubic Bezier, in-out interpolation (easing), no control points
    rl.DrawLineBezier(start_point, end_point, 4, rl.BLUE)
    
    // Draw start-end spline circles with some details
    rl.DrawCircleV(start_point, rl.CheckCollisionPointCircle(mouse, start_point, 10) ? 14 : 8, move_start_point ? rl.RED : rl.BLUE);
    rl.DrawCircleV(end_point, rl.CheckCollisionPointCircle(mouse, end_point, 10) ? 14 : 8, move_end_point ? rl.RED : rl.BLUE);

}

updateGame :: proc() {
    gameLogic()
    drawGame()
}