package main

import "core:math/linalg"
import rl "vendor:raylib"

Tex :: struct {
    pos: [2]f32,
    rotation: f32,
    origin: [2]f32,
    texture: rl.Texture,
}

get_rotation :: proc(tex: ^Tex) -> f32 {
    mouse_pos := rl.GetMousePosition()
    rad := linalg.atan2(mouse_pos.y - tex.pos.y, mouse_pos.x - tex.pos.x)
    return linalg.to_degrees(rad) + 90
}

main :: proc() {
    rl.InitWindow(1000, 1000, "follow mouse")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    tex: Tex
    tex.pos = {500, 500}
    tex.origin = {50, 50}
    tex.texture = rl.LoadTexture("assets/arrow.png")

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)
    
        rl.DrawTexturePro(
            tex.texture, 
            {0, 0, 100, 100},
            {500, 500, 100, 100},
            tex.origin,
            get_rotation(&tex),
            rl.WHITE,
        )
        rl.EndDrawing()
    }
}
