package main

import "core:math"
import "core:math/rand"
import "core:slice"

import rl "vendor:raylib"

WINDOW_WIDTH  :: 2560
WINDOW_HEIGHT :: 1440
MAX_FRAMERATE :: 144
DT           :: 1.0 / f32(MAX_FRAMERATE)

// Star configuration
STAR_COUNT :: 10000
STAR_RADIUS :: 40.0
STAR_FAR :: 10.0
STAR_NEAR :: 0.1
STAR_SPEED :: 0.5

Star :: struct {
    position: rl.Vector2,
    z: f32,
}

create_stars :: proc(count: int, scale: f32) -> []Star {
    stars := make([]Star, count)
    // Define a star free zone
    window_world_size := rl.Vector2{f32(WINDOW_WIDTH) * STAR_NEAR, f32(WINDOW_HEIGHT) * STAR_NEAR}
    star_free_zone := rl.Rectangle{
        -window_world_size.x * 0.25,
        -window_world_size.y * 0.25,
        window_world_size.x * 0.5,
        window_world_size.y * 0.5,
    }
    i := 0
    for i < count {
        x := (rand.float32() - 0.5) * f32(WINDOW_WIDTH) * scale
        y := (rand.float32() - 0.5) * f32(WINDOW_HEIGHT) * scale
        z := (STAR_FAR - STAR_NEAR) * rand.float32() + STAR_NEAR
        // Discard any star that falls in the zone
        if rl.CheckCollisionPointRec(rl.Vector2{x, y}, star_free_zone) {
            continue
        }
        stars[i] = Star{rl.Vector2{x, y}, z}
        i += 1
    }
    // Depth ordering
    slice.sort_by(stars[:], proc(a, b: Star) -> bool {
        return a.z > b.z
    })
    return stars
}

fast_pow :: proc(x: f32, p: int) -> f32 {
    res:f32 = 1.0
    for i := 0; i < p; i += 1 {
        res *= x
    }
    return res
}

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "star field")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(MAX_FRAMERATE)
    rl.HideCursor()
    
    // Load star texture
    star_texture := rl.LoadTexture("assets/star.png")
    defer rl.UnloadTexture(star_texture)
    
    stars := create_stars(STAR_COUNT, STAR_FAR)
    defer delete(stars)
    
    first := 0
    for !rl.WindowShouldClose() {
        // Update
        if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
            break
        }
        // Fake travel toward increasing Z
        for i := 0; i < STAR_COUNT; i += 1 {
            stars[i].z -= STAR_SPEED * DT
            if stars[i].z < STAR_NEAR {
                stars[i].z = STAR_FAR - (STAR_NEAR - stars[i].z)
                first = i
            }
        }
        // Render
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        // Draw from furthest to nearest
        for i := 0; i < STAR_COUNT; i += 1 {
            idx := (i + first) % STAR_COUNT
            star := stars[idx]
            
            scale := 1.0 / star.z
            depth_ratio := (star.z - STAR_NEAR) / (STAR_FAR - STAR_NEAR)
            color_ratio := 1.0 - depth_ratio
            c := u8(fast_pow(color_ratio, 1) * 255.0)
            
            position := star.position * scale
            radius := STAR_RADIUS * scale
            
            screen_pos := rl.Vector2{
                position.x + f32(WINDOW_WIDTH) * 0.5,
                position.y + f32(WINDOW_HEIGHT) * 0.5,
            }
            rl.DrawTexturePro(
                star_texture,
                rl.Rectangle{0, 0, f32(star_texture.width), f32(star_texture.height)},
                rl.Rectangle{
                    screen_pos.x - radius,
                    screen_pos.y - radius,
                    radius * 2,
                    radius * 2,
                },
                rl.Vector2{0, 0},
                0,
                rl.Color{c, c, c, 255},
            )
        }
        rl.EndDrawing()
    }
}