package poly

import rl "vendor:raylib"

WIDTH :: 1280
HEIGHT :: 720

Poly :: struct {
    vel: rl.Vector2,
    center: rl.Vector2,
    side: i32,
    radius: f32,
    rotation: f32,
    color: rl.Color,
}

polys: [30]Poly
pause := false

main :: proc() {
    // create window
    rl.InitWindow(WIDTH, HEIGHT, "Prac Proj")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    init()

    // main game loop
    for !rl.WindowShouldClose() do update(); draw();
}

init :: proc() {
    for &i in &polys {

        // create poly values
        i.center = {f32(rl.GetRandomValue(100,1200)),f32(rl.GetRandomValue(100,650))}
        i.side = rl.GetRandomValue(3,8)
        i.radius = f32(rl.GetRandomValue(15,50))
        i.color = {u8(rl.GetRandomValue(0,255)), u8(rl.GetRandomValue(0,255)), u8(rl.GetRandomValue(0,255)), u8(255)}

        // set velocity to random values
        neg: rl.Vector2 = {f32(rl.GetRandomValue(0,1)), f32(rl.GetRandomValue(0,1))}
        if neg.x == 0 do neg.x = -1
        if neg.y == 0 do neg.y = -1
        i.vel = {f32(rl.GetRandomValue(1,5)), f32(rl.GetRandomValue(1,5))} * neg
    }
}

update :: proc() {
    // controls
    if rl.IsKeyPressed(.P) do pause = !pause

    if !pause {
        for &i in &polys {
            // move entities by velocity and rotate them
            i.rotation += 2
            i.center += {i.vel.x, i.vel.y}

            // reverse velocity if entity collides with a walll
            if  i.center.x - i.radius <= 0 || i.center.x + i.radius >= WIDTH do i.vel.x *= -1
            if  i.center.y - i.radius <= 0 || i.center.y + i.radius >= HEIGHT do i.vel.y *= -1
        }
    }
}

draw :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.BLACK)
    // draw polygons
    for i in &polys {
        rl.DrawPoly(i.center, i.side, i.radius, i.rotation, i.color)
    }
    // pause label
    if pause do rl.DrawText("GAME PAUSED", 
                            WIDTH / 2 - rl.MeasureText("GAME PAUSED", 40) / 2, 
                            HEIGHT / 2 - 40, 40, 
                            rl.WHITE)
    rl.DrawFPS(0,0)
}