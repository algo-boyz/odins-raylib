package core

import rl "vendor:raylib"
import "vendor:raylib/rlgl"

main :: proc() {
    rl.InitWindow(800, 450, "raylib [core] example - 2d camera mouse zoom")
    defer rl.CloseWindow()

    camera: rl.Camera2D
    camera.zoom = 1

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        if rl.IsMouseButtonDown(.RIGHT) {
            delta := rl.GetMouseDelta()
            delta *= -1 / camera.zoom

            camera.target += delta
        }

        wheel := rl.GetMouseWheelMove()
        if wheel != 0 {
            mouseWorldPos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

            camera.offset = rl.GetMousePosition()
            camera.target = mouseWorldPos

            zoomIncrement: f32 = 0.125

            camera.zoom += wheel * zoomIncrement
            camera.zoom = clamp(camera.zoom, zoomIncrement, 32)
        }

        {
            rl.BeginDrawing()
            defer rl.EndDrawing()

            rl.ClearBackground(rl.BLACK)

            {
                rl.BeginMode2D(camera)
                defer rl.EndMode2D()

                rlgl.PushMatrix()
                    rlgl.Translatef(0, 25*50, 0)
                    rlgl.Rotatef(90, 1, 0, 0)
                    rl.DrawGrid(100, 50)
                rlgl.PopMatrix()

                rl.DrawCircle(100, 100, 50, rl.YELLOW)
            }

            rl.DrawText("Mouse right button drag to move, mouse wheel to zoom", 10, 10, 20, rl.WHITE)
        }
    }
}