package main

import rl "vendor:raylib"

Dino :: struct {
    image:    rl.Texture2D,
    position: rl.Vector2,
    speed:    f32,
}

create_dino :: proc() -> Dino {
    return Dino{
        image    = rl.LoadTexture("assets/dino.png"),
        position = rl.Vector2{100, 100},
        speed    = 10,
    }
}

destroy_dino :: proc(dino: ^Dino) {
    rl.UnloadTexture(dino.image)
}

draw_dino :: proc(dino: ^Dino) {
    rl.DrawTextureV(dino.image, dino.position, rl.WHITE)
}

update_dino :: proc(dino: ^Dino) {
    if rl.IsKeyDown(.RIGHT) do dino.position.x += dino.speed
    if rl.IsKeyDown(.LEFT)  do dino.position.x -= dino.speed
    if rl.IsKeyDown(.UP)    do dino.position.y -= dino.speed
    if rl.IsKeyDown(.DOWN)  do dino.position.y += dino.speed
}

get_dino_rect :: proc(dino: ^Dino) -> rl.Rectangle {
    return rl.Rectangle{
        x = dino.position.x,
        y = dino.position.y,
        width = f32(dino.image.width),
        height = f32(dino.image.height),
    }
}

draw_dino_hitbox :: proc(dino: ^Dino, is_colliding: bool) {
    if is_colliding {
        rl.DrawRectangleLinesEx(get_dino_rect(dino), 3, rl.RED)
    }
}

main :: proc() {
    rl.InitWindow(1200, 800, "Raylib Collisions")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    
    dino := create_dino()
    defer destroy_dino(&dino)
    
    obstacle := rl.Rectangle{800, 200, 200, 175}
    
    for !rl.WindowShouldClose() {
        update_dino(&dino)
        
        is_colliding := rl.CheckCollisionRecs(get_dino_rect(&dino), obstacle)
        
        rl.BeginDrawing()        
        rl.ClearBackground(rl.WHITE)
        rl.DrawRectangleLinesEx(obstacle, 5, rl.BLACK)
        draw_dino(&dino)
        draw_dino_hitbox(&dino, is_colliding)
        rl.EndDrawing()
    }
}