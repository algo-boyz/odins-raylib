
package main

import rl "vendor:raylib"
import iso "camera"

main :: proc() {
    rl.InitWindow(1280, 720, "Operation Eagle Nest - Greybox")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    camera := iso.camera_init({50, 0, 50}, 65)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        iso.camera_update(&camera, dt)

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera.camera)

        // Mission ground.
        rl.DrawPlane(
            {50, 0, 50},
            {100, 100},
            rl.LIGHTGRAY,
        )
        rl.DrawGrid(100, 5)

        // Barracks: mission rect (37, 12, 28, 19).
        rl.DrawCube(
            {51, 2, 21.5},
            28, 4, 19,
            rl.BROWN,
        )
        rl.DrawCubeWires(
            {51, 2, 21.5},
            28, 4, 19,
            rl.DARKGRAY,
        )

        // Watchtower: mission rect (78, 25, 8, 8).
        rl.DrawCube(
            {82, 5, 29},
            8, 10, 8,
            rl.GRAY,
        )
        rl.DrawCubeWires(
            {82, 5, 29},
            8, 10, 8,
            rl.DARKGRAY,
        )

        // Player spawn.
        rl.DrawSphere({12, 1, 82}, 1.5, rl.BLUE)

        // Extraction.
        rl.DrawCylinder(
            {84, 0.5, 88},
            3, 3, 1,
            16,
            rl.GREEN,
        )

        // Initial guard placeholders.
        rl.DrawSphere({30, 1, 35}, 1.2, rl.RED)
        rl.DrawSphere({55, 1, 48}, 1.2, rl.RED)
        rl.DrawSphere({76, 1, 35}, 1.2, rl.RED)

        rl.EndMode3D()

        rl.DrawText(
            "OPERATION EAGLE NEST",
            20, 20, 24,
            rl.DARKGRAY,
        )
        rl.DrawText(
            "Shift + drag: pan   Trackpad scroll: zoom",
            20, 54, 18,
            rl.DARKGRAY,
        )

        rl.EndDrawing()
    }
}
