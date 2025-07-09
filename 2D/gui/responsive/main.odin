package main

import rl "vendor:raylib"

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 600, "Responsive Image Display")
    rl.SetTargetFPS(60)
    
    image := rl.LoadTexture("sand.png")
    src := rl.Rectangle{0, 0, f32(image.width), f32(image.height)}
    origin := rl.Vector2{0, 0}
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        if image.id != 0 {
            dest := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
            rl.DrawTexturePro(image, src, dest, origin, 0.0, rl.WHITE)
        } else {
            msg :: "Failed to load image!"
            fontSize := i32(20)
            textWidth := rl.MeasureText(msg, fontSize)
            x := (rl.GetScreenWidth() - textWidth) / 2
            y := rl.GetScreenHeight() / 2 - fontSize / 2
            rl.DrawText(msg, x, y, fontSize, rl.RED)
        }
        rl.EndDrawing()
    }
    if image.id != 0 {
        rl.UnloadTexture(image)
    }
    rl.CloseWindow()
}