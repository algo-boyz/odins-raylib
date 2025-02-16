// MIT (c) 2025 by Chris
// https://github.com/ChrisPHP/odin-lsystem
package main

import rl "vendor:raylib"

main :: proc() {
    lsystem := create_lsystem(6, "X")
    defer delete(lsystem)
    meshes := draw_lystem(lsystem, 0.2, 35, {0,0,0}, {90,90})
    defer delete(meshes)

    rl.InitWindow(1920, 1080, "L-System")
    rl.SetTargetFPS(60)

    cam := rl.Camera3D{
        position ={10,20,10}, 
        target = {0, 15,0},
        up =  {0,1,0},
        fovy =  90,
    }

    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&cam, .ORBITAL);

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(cam)

        rl.DrawGrid(10, 1)

        for mesh in meshes {
            rl.DrawCylinderEx(mesh.start, mesh.end, 0.1, 0.1, 6, rl.GREEN)
        }

	    rl.EndMode3D()
        rl.EndDrawing()
    }

    rl.CloseWindow()
}