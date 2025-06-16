package main

import "core:math"
import "../../../rlutil/blender"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

main :: proc() {
    screen_width :: 800
    screen_height :: 450

    rl.InitWindow(screen_width, screen_height, "Blender Camera")
    defer rl.CloseWindow()

    bl := blender.camera_init()
    cube_position := rl.Vector3{0, 0, 0}

    rl.SetTargetFPS(60)
    rl.DisableCursor()

    for !rl.WindowShouldClose() {
        blender.camera_update(&bl)

        rl.BeginDrawing()
        rl.ClearBackground(blender.BLENDER_DARK_GREY)

        rl.BeginMode3D(bl.camera)
        {
            rl.DrawCube(cube_position, 2, 2, 2, blender.BLENDER_GREY)
            rl.DrawCubeWires(cube_position, 2, 2, 2, rl.ORANGE)
            blender.draw_grid_ex(20, 1)
        }
        rl.EndMode3D()

        if bl.free_fly {
            rl.DrawText("Blender Camera Mode: FREE_FLY", 10, 10, 20, blender.BLENDER_GREY)
        } else {
            rl.DrawText("Blender Camera Mode: GIMBAL_ORBIT", 10, 10, 20, blender.BLENDER_GREY)
        }
        rl.DrawFPS(10, screen_height - 30)
        rl.EndDrawing()
    }
}
