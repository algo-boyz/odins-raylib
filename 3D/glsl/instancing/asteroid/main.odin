package main

import "core:math/rand"
import "core:math"
import "core:time"
import "core:os"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

main :: proc() {
    screen_width :: 800
    screen_height :: 450

    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(screen_width, screen_height, "Instanced Asteroids")

    rock_shader := rl.LoadShader("assets/asteroid.vs", "assets/asteroid.fs")

    rock_shader.locs[rl.ShaderLocationIndex.MATRIX_MVP] = rl.GetShaderLocation(rock_shader, "mvp")
    rock_shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocationAttrib(rock_shader, "instance")
    rock_shader.locs[rl.ShaderLocationIndex.MATRIX_VIEW] = rl.GetShaderLocation(rock_shader, "view")
    rock_shader.locs[rl.ShaderLocationIndex.MATRIX_PROJECTION] = rl.GetShaderLocation(rock_shader, "projection")

    planet := rl.LoadModel("assets/planet.obj")
    rock := rl.LoadModel("assets/rock.obj")

    asteroid_count :: 20000

    model_matrices := make([dynamic]rl.Matrix, asteroid_count)
    defer delete(model_matrices)

    // Init random seed from current time
    seed := rand.create(u64(time.now()._nsec))
    rng := rand.default_random_generator(&seed)

    radius: f32 = 150.0
    offset: f32 = 30.0

    for i in 0..<asteroid_count {
        model := rl.Matrix(1)

        // 1. Translation: displace along circle with 'radius' in range [-offset, offset]
        angle := (cast(f32)i / cast(f32)asteroid_count) * 360.0 * rl.DEG2RAD

        displacement := rand.float32_range(-offset, offset, rng)
        x := math.sin(angle) * radius + displacement

        displacement = rand.float32_range(-offset, offset, rng)
        // Keep height of rock field smaller compared to width of x and z
        y := displacement * 0.5

        displacement = rand.float32_range(-offset, offset, rng)
        z := math.cos(angle) * radius + displacement

        mat_translation := rl.MatrixTranslate(x, y, z)

        // 2. Scale: between 0.05 and 0.25
        scale := rand.float32_range(0.05, 0.25, rng)
        mat_scale := rl.MatrixScale(scale, scale, scale)

        // 3. Rotation: add random rotation around a (semi)randomly picked rotation axis vector
        rot_angle := rand.float32_range(0, 360, rng)
        // Note: angle in degrees!
        mat_rotation := rl.MatrixRotate(rl.Vector3{0.4, 0.6, 0.8}, rot_angle)

        // Combine the matrices. Order of multiplication is important.
        model = mat_scale
        model = mat_rotation * model
        model = mat_translation * model

        // 4. Now add to list of matrices
        model_matrices[i] = model
    }

    draw_instanced := true
    paused := false

    camera := load_camera()
    camera.view.position = {0.0, 14.0, 240.0}

    mouse_last_position := rl.GetMousePosition()

    rl.DisableCursor()

    angle: f32 = 0.0

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        if !paused {
            // Track mouse movement
            mouse_position := rl.GetMousePosition()
            mouse_delta := mouse_position - mouse_last_position
            mouse_last_position = mouse_position

            update_camera(&camera, mouse_delta, dt)
            angle += 0.3 * dt
        }

        if rl.IsKeyPressed(.R) {
            camera.view.position = {0.0, 14.0, 240.0}
            camera.view.target = {0.0, 0.0, 0.0}
            camera.up = {0.0, 1.0, 0.0}
        }

        if rl.IsKeyPressed(.F3) {
            paused = !paused
            if paused {
                rl.EnableCursor()
            } else {
                rl.DisableCursor()
            }
        }
        // Turn instancing on/off
        if rl.IsKeyPressed(.ONE) {
            draw_instanced = false
        }
        if rl.IsKeyPressed(.TWO) {
            draw_instanced = true
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{26, 26, 26, 255})
        {

            rl.BeginMode3D(camera.view)

            rlgl.PushMatrix()
            rlgl.Rotatef(angle * rl.RAD2DEG, 0, 1, 0)
            {
                // Draw central planet
                planet_axis: rl.Vector3 = {0.0, 1.0, 0.0} 
                planet_scale: rl.Vector3 = {5.0, 5.0, 5.0}
                rl.DrawModelEx(planet, {}, planet_axis, angle * rl.RAD2DEG, planet_scale, rl.WHITE)

                // Draw asteroids
                if draw_instanced {
                    // 1 draw call is made per mesh in the model
                    rock.transform = rl.Matrix(1)
                    rock.materials[0].shader = rock_shader
                    rl.DrawMeshInstanced(rock.meshes[0], rock.materials[0], raw_data(model_matrices), asteroid_count)
                } else {
                    // Draw each asteroid one at a time (much slower!)
                    rock.materials[0].shader.id = rlgl.GetShaderIdDefault()
                    for i in 0..<asteroid_count {
                        rock.transform = model_matrices[i]
                        rl.DrawModel(rock, {}, 1.0, rl.WHITE)
                    }
                }
            }
            rlgl.PopMatrix()
            rl.EndMode3D()

            rl.DrawRectangle(0, 0, rl.GetScreenWidth(), 40, rl.BLACK)
            rl.DrawText(rl.TextFormat("asteroids: %v", asteroid_count), 120, 10, 20, rl.GREEN)
            rl.DrawText(rl.TextFormat("instanced: %v", draw_instanced), 550, 10, 20, rl.MAROON)
            rl.DrawFPS(10, 10)
        }
        rl.EndDrawing()
    }
    rl.UnloadModel(planet)
    rl.UnloadModel(rock)
    rl.UnloadShader(rock_shader)
    rl.CloseWindow()
}
