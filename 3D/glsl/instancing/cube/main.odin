package main

import "core:math/rand"
import "core:fmt"
import rl "vendor:raylib"

MAX_INSTANCES :: 30000
BOX_SIZE :: 0.1

random :: proc(min, max: f32) -> f32 {
    return min + (max - min) * rand.float32()
}

main :: proc() {
    rl.InitWindow(1200, 700, "Mesh GPU Instancing")

    camera := rl.Camera{}
    camera.position = rl.Vector3{0.0, 0.0, 40.0}
    camera.target = rl.Vector3{0.0, 0.0, 0.0}
    camera.up = rl.Vector3{0.0, 1.0, 0.0}
    camera.fovy = 45.0
    camera.projection = rl.CameraProjection.PERSPECTIVE

    // Setup instances mesh and positions
    mesh := rl.GenMeshCube(BOX_SIZE, BOX_SIZE, BOX_SIZE)
    transforms := make([]rl.Matrix, MAX_INSTANCES)
    defer delete(transforms)

    for i in 0..<MAX_INSTANCES {
        randomPos := rl.Vector3{
            random(-10.0, 10.0),
            random(-10.0, 10.0),
            random(-10.0, 10.0),
        }
        transforms[i] = rl.MatrixTranslate(randomPos.x, randomPos.y, randomPos.z)
    }

    // Setup instance shader
    dir := rl.GetApplicationDirectory()
    vs_path := fmt.ctprintf("%s/assets/shader.vs", dir)
    fs_path := fmt.ctprintf("%s/assets/shader.fs", dir)
    shader := rl.LoadShader(vs_path, fs_path)
    
    shader.locs[rl.ShaderLocationIndex.MATRIX_MVP] = rl.GetShaderLocation(shader, "projectionMatrix")
    shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocationAttrib(shader, "instanceMatrix")
    
    matInstances := rl.LoadMaterialDefault()
    matInstances.shader = shader
    matInstances.maps[rl.MaterialMapIndex.ALBEDO].color = rl.RED

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        for i in 0..<MAX_INSTANCES {
            randomOffset := rl.Vector3{
                random(-0.04, 0.04),
                random(-0.04, 0.04),
                random(-0.04, 0.04),
            }
            transforms[i] = rl.MatrixTranslate(randomOffset.x, randomOffset.y, randomOffset.z) * transforms[i]
        }

        rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL)

        rl.BeginDrawing()
        {
            rl.ClearBackground(rl.RAYWHITE)

            rl.BeginMode3D(camera)
            {
                rl.DrawMeshInstanced(mesh, matInstances, raw_data(transforms), MAX_INSTANCES)
            }
            rl.EndMode3D()

            fps_text := fmt.ctprintf("FPS: %i", rl.GetFPS())
            rl.DrawText(fps_text, 10, 10, 20, rl.RED)
        }
        rl.EndDrawing()
    }

    rl.UnloadMesh(mesh)
    rl.CloseWindow()
}