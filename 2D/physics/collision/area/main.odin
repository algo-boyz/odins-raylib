package area

import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 450
UPPER_LIM :f32: 40

box_a_speed: f32
pause, collision: bool
box_a, box_b, box_collision: rl.Rectangle

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Template")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    init()
    for !rl.WindowShouldClose() do update()
}

init :: proc() {
    // init boxes
    box_a = {10, f32(rl.GetScreenHeight() / 2 - 50), 200, 100}
    box_a_speed = 4
    box_b = {f32(rl.GetScreenWidth() / 2 - 30), f32(rl.GetScreenHeight() / 2 - 30), 60, 60}
}

logic :: proc() {
    // Move box if unpaused
    if !pause do box_a.x += box_a_speed

    // Bounce box on x screen limits
    if (box_a.x + box_a.width >= f32(rl.GetScreenWidth())) || (box_a.x <= 0) do box_a_speed *= -1

    // Update player box
    box_b.x = f32(rl.GetMouseX()) - box_b.width / 2
    box_b.y = f32(rl.GetMouseY()) - box_b.height / 2

    // Make sure Box B does not go out of move area limits
    if box_b.x + box_b.width >= f32(rl.GetScreenWidth()) do box_b.x = f32(rl.GetScreenWidth()) - box_b.width
    else if box_b.x <= 0 do box_b.x = 0

    if (box_b.y + box_b.height) >= f32(rl.GetScreenHeight()) do box_b.y = f32(rl.GetScreenHeight()) - box_b.height
    else if (box_b.y <= UPPER_LIM) do  box_b.y = UPPER_LIM
    
    // Check box collisions
    collision = rl.CheckCollisionRecs(box_a, box_b)
    if collision do box_collision = rl.GetCollisionRec(box_a, box_b)

    // Pause box movement
    if rl.IsKeyPressed(.SPACE) do pause = !pause
}


draw :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.WHITE)

    rl.DrawRectangle(0, 0, WIDTH, i32(UPPER_LIM), collision ? rl.RED : rl.BLACK)
    rl.DrawRectangleRec(box_a, rl.GOLD)
    rl.DrawRectangleRec(box_b, rl.BLUE)
    
    if collision {
        // Draw collision area
        rl.DrawRectangleRec(box_collision, rl.LIME)
        // Draw message
        rl.DrawText("COLLISION!", 
                     rl.GetScreenWidth() / 2 - rl.MeasureText("COLLISION!", 20) / 2, 
                     i32(UPPER_LIM / 2) - 10, 
                     20, 
                     rl.BLACK);
        rl.DrawText(rl.TextFormat("Collision Area: %v", box_collision.width * box_collision.height), 
                                   rl.GetScreenWidth() / 2 - 100, 
                                   i32(UPPER_LIM) + 10, 
                                   20, 
                                   rl.BLACK)
    }
    rl.DrawText("Press SPACE to PAUSE/RESUME", 
                 20, 
                 HEIGHT - 35, 
                 20, 
                 rl.LIGHTGRAY);
    rl.DrawFPS(10, 10);
}

update :: proc() {
    logic()
    draw()
}