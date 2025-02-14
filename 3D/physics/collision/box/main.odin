package main

import rl "vendor:raylib"

TILE_SIZE :: 1.0

Unit :: struct {
    position: rl.Vector3,
    rotation: rl.Vector3,
    size: rl.Vector3,
    velocity: rl.Vector3,
    speed: f32,
    max_speed: f32,
    health: int,
    max_health: int,
    damage: int,
    is_active: bool,
    cooldown: int,
    can_attack: bool,
    attack_timer: int,
    colour: rl.Color,
}

Wall :: struct {
    position: rl.Vector3,
    size: int,
    health: int,
    is_active: bool,
    colour: rl.Color,
}

resolve_collision :: proc(unit: ^Unit, obstacle: rl.Vector3) {
    // Collision resolution logic
    if unit.position.z < obstacle.z - 1 { // player above
        unit.position.z -= unit.speed
    }
    if unit.position.z > obstacle.z + 1 { // player below
        unit.position.z += unit.speed
    }
    if unit.position.x < obstacle.x - 1 { // player on left
        unit.position.x -= unit.speed
    }
    if unit.position.x > obstacle.x + 1 { // player on right
        unit.position.x += unit.speed
    }
}

main :: proc() {
    screen_width :: 1400
    screen_height :: 850

    rl.InitWindow(screen_width, screen_height, "quadtree based collision detection")
    defer rl.CloseWindow()

    camera := rl.Camera{
        position = {0.0, 10.0, 10.0},
        target = {0.0, 0.0, 0.0},
        up = {0.0, 1.0, 0.0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }

    player_unit := Unit{
        position = {-4.0, 1.0, -4.0},
        size = {1.0, 2.0, 1.0},
        speed = 0.1,
        max_speed = 0.5,
        health = 40,
        max_health = 40,
        damage = 6,
        colour = rl.RED,
    }

    wall := Wall{
        position = {0.0, 1.0, 0.0},
        size = 1,
        health = 20,
        colour = rl.GRAY,
    }

    collision := false

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Move player
        if rl.IsKeyDown(.RIGHT) do player_unit.position.x += player_unit.speed
        if rl.IsKeyDown(.LEFT) do player_unit.position.x -= player_unit.speed
        if rl.IsKeyDown(.DOWN) do player_unit.position.z += player_unit.speed
        if rl.IsKeyDown(.UP) do player_unit.position.z -= player_unit.speed

        collision = false

        // Check collisions player vs wall
        player_box := rl.BoundingBox{
            min = {
                player_unit.position.x - player_unit.size.x/2,
                player_unit.position.y - player_unit.size.y/2,
                player_unit.position.z - player_unit.size.z/2,
            },
            max = {
                player_unit.position.x + player_unit.size.x/2,
                player_unit.position.y + player_unit.size.y/2,
                player_unit.position.z + player_unit.size.z/2,
            },
        }

        wall_box := rl.BoundingBox{
            min = {
                wall.position.x - 2.0/2,
                wall.position.y - 2.0/2,
                wall.position.z - 2.0/2,
            },
            max = {
                wall.position.x + 2.0/2,
                wall.position.y + 2.0/2,
                wall.position.z + 2.0/2,
            },
        }

        collision = rl.CheckCollisionBoxes(player_box, wall_box)

        if collision {
            player_unit.colour = rl.RED
            resolve_collision(&player_unit, wall.position)
        } else {
            player_unit.colour = rl.GREEN
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)
        {
            // Draw wall
            rl.DrawCube(wall.position, 2.0, 2.0, 2.0, rl.GRAY)
            rl.DrawCubeWires(wall.position, 2.0/2, 2.0/2, 2.0/2, rl.DARKGRAY)

            // Draw player
            rl.DrawCubeV(player_unit.position, player_unit.size, player_unit.colour)

            rl.DrawGrid(10, TILE_SIZE)
        }
        rl.EndMode3D()

        rl.DrawFPS(10, 10)
        
        // Draw position text
        player_pos_text := rl.TextFormat(
            "player pos X = %f\n\nY = %f\n\nZ = %f",
            player_unit.position.x,
            player_unit.position.y,
            player_unit.position.z,
        )
        rl.DrawText(player_pos_text, 30, 30, 30, rl.DARKGRAY)
    }
}