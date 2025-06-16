package main

import rl "vendor:raylib"

main :: proc() {
    // Initialization
    SCREEN_WIDTH :: 800
    SCREEN_HEIGHT :: 450

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [models] example - box collision")

    // Define the camera to look into our 3d world
    camera := rl.Camera3D{
        position = {0.0, 10.0, 10.0},
        target = {0.0, 0.0, 0.0},
        up = {0.0, 1.0, 0.0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }

    player_position := rl.Vector3{0.0, 1.0, 2.0}
    player_size := rl.Vector3{1.0, 2.0, 1.0}
    player_color := rl.GREEN

    enemy_box_pos := rl.Vector3{-4.0, 1.0, 0.0}
    enemy_box_size := rl.Vector3{2.0, 2.0, 2.0}

    enemy_sphere_pos := rl.Vector3{4.0, 0.0, 0.0}
    enemy_sphere_size : f32 = 1.5

    collision := false

    rl.SetTargetFPS(60)

    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        // Move player
        if rl.IsKeyDown(.RIGHT) {
            player_position.x += 0.2
        } else if rl.IsKeyDown(.LEFT) {
            player_position.x -= 0.2
        } else if rl.IsKeyDown(.DOWN) {
            player_position.z += 0.2
        } else if rl.IsKeyDown(.UP) {
            player_position.z -= 0.2
        }

        collision = false

        // Check collisions player vs enemy-box
        player_bounds := rl.BoundingBox{
            min = {
                player_position.x - player_size.x/2,
                player_position.y - player_size.y/2,
                player_position.z - player_size.z/2,
            },
            max = {
                player_position.x + player_size.x/2,
                player_position.y + player_size.y/2,
                player_position.z + player_size.z/2,
            },
        }

        enemy_bounds := rl.BoundingBox{
            min = {
                enemy_box_pos.x - enemy_box_size.x/2,
                enemy_box_pos.y - enemy_box_size.y/2,
                enemy_box_pos.z - enemy_box_size.z/2,
            },
            max = {
                enemy_box_pos.x + enemy_box_size.x/2,
                enemy_box_pos.y + enemy_box_size.y/2,
                enemy_box_pos.z + enemy_box_size.z/2,
            },
        }

        if rl.CheckCollisionBoxes(player_bounds, enemy_bounds) {
            collision = true
        }

        // Check collisions player vs enemy-sphere
        if rl.CheckCollisionBoxSphere(
            player_bounds,
            enemy_sphere_pos,
            enemy_sphere_size,
        ) {
            collision = true
        }

        player_color = collision ? rl.RED : rl.GREEN

        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)
        defer rl.EndMode3D()

        // Draw enemy-box
        rl.DrawCube(enemy_box_pos, enemy_box_size.x, enemy_box_size.y, enemy_box_size.z, rl.GRAY)
        rl.DrawCubeWires(enemy_box_pos, enemy_box_size.x, enemy_box_size.y, enemy_box_size.z, rl.DARKGRAY)

        // Draw enemy-sphere
        rl.DrawSphere(enemy_sphere_pos, enemy_sphere_size, rl.GRAY)
        rl.DrawSphereWires(enemy_sphere_pos, enemy_sphere_size, 16, 16, rl.DARKGRAY)

        // Draw player
        rl.DrawCubeV(player_position, player_size, player_color)

        // Draw grid
        rl.DrawGrid(10, 1.0)

        // Draw UI text
        rl.DrawText("Move player with arrow keys to collide", 220, 40, 20, rl.GRAY)
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }

    // De-Initialization
    rl.CloseWindow()
}