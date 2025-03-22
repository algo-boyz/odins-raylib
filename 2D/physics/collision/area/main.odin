package collision_area

/*******************************************************************************************
*
*   raylib [shapes] example - collision area
*
*   Example originally created with raylib 2.5, last time updated with raylib 2.5
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2013-2024 Ramon Santamaria (@raysan5)
*   Translation to Odin by Evan Martinez (@Nave55)
*
*   https://github.com/Nave55/Odin-Raylib-Examples/blob/main/Shapes/collision_area.odin
*
********************************************************************************************/

import rl "vendor:raylib"

// constants
SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
SCREEN_UPPER_LIMIT: f32 : 40

// variables
box_a_speed: f32
pause, collision := false, false
box_a, box_b, box_collision: rl.Rectangle

main :: proc() {
    // create window and close it when needed
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Template")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    // init game and then run main game loop
    initGame()
    for !rl.WindowShouldClose() do updateGame()

}

initGame :: proc() {
    // init boxes
    box_a = {10, f32(rl.GetScreenHeight() / 2 - 50), 200, 100}
    box_a_speed = 4
    box_b = {f32(rl.GetScreenWidth() / 2 - 30), f32(rl.GetScreenHeight() / 2 - 30), 60, 60}
}

gameLogic :: proc() {
    // Move box if not paused
    if !pause do box_a.x += box_a_speed

    // Bounce box on x screen limits
    if (box_a.x + box_a.width >= f32(rl.GetScreenWidth())) || (box_a.x <= 0) do box_a_speed *= -1

    // Update player-controlled-box (box02)
    box_b.x = f32(rl.GetMouseX()) - box_b.width / 2
    box_b.y = f32(rl.GetMouseY()) - box_b.height / 2

    // Make sure Box B does not go out of move area limits
    if box_b.x + box_b.width >= f32(rl.GetScreenWidth()) do box_b.x = f32(rl.GetScreenWidth()) - box_b.width
    else if box_b.x <= 0 do box_b.x = 0

    if (box_b.y + box_b.height) >= f32(rl.GetScreenHeight()) do box_b.y = f32(rl.GetScreenHeight()) - box_b.height
    else if (box_b.y <= SCREEN_UPPER_LIMIT) do  box_b.y = SCREEN_UPPER_LIMIT
    
    // Check boxes collision
    collision = rl.CheckCollisionRecs(box_a, box_b)

    // Get collision rectangle (only on collision)
    if collision do box_collision = rl.GetCollisionRec(box_a, box_b)

    // Pause Box A movement
    if rl.IsKeyPressed(.SPACE) do pause = !pause
}


drawGame :: proc() {
    // begin drawing and end drawing at scope exit
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.WHITE)

    rl.DrawRectangle(0, 0, SCREEN_WIDTH, i32(SCREEN_UPPER_LIMIT), collision ? rl.RED : rl.BLACK)
    rl.DrawRectangleRec(box_a, rl.GOLD)
    rl.DrawRectangleRec(box_b, rl.BLUE)
    
    if collision {
        // Draw collision area
        rl.DrawRectangleRec(box_collision, rl.LIME)

        // Draw collision message
        rl.DrawText("COLLISION!", 
                     rl.GetScreenWidth() / 2 - rl.MeasureText("COLLISION!", 20) / 2, 
                     i32(SCREEN_UPPER_LIMIT / 2) - 10, 
                     20, 
                     rl.BLACK);

        // Draw collision area
        rl.DrawText(rl.TextFormat("Collision Area: %v", box_collision.width * box_collision.height), 
                                   rl.GetScreenWidth() / 2 - 100, 
                                   i32(SCREEN_UPPER_LIMIT) + 10, 
                                   20, 
                                   rl.BLACK)
    }
    // Draw help instructions
    rl.DrawText("Press SPACE to PAUSE/RESUME", 
                 20, 
                 SCREEN_HEIGHT - 35, 
                 20, 
                 rl.LIGHTGRAY);

    rl.DrawFPS(10, 10);
}

updateGame :: proc() {
    gameLogic()
    drawGame()
}