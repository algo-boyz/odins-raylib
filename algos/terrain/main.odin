package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH  :: 1200
SCREEN_HEIGHT :: 800
TILE_SIZE     :: 32

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Natural Terrain Demo")
    rl.SetTargetFPS(60)

    // ---------- distribution ----------
    dist := TerrainDistribution{
        hills     = 0.10,
        mountains = 0.05,
        marsh     = 0.08,
        forest    = 0.20,
        water     = 0.07,
        urban     = 0.02,
        plains    = 0.0,
    }

    // ---------- map ----------
    map_rows := i32(SCREEN_HEIGHT / TILE_SIZE)
    map_cols := i32(SCREEN_WIDTH  / TILE_SIZE)

    current_k : i32 = 3
    game_map := map_create(map_rows, map_cols, dist, current_k)

    // ---------- camera ----------
    cam := rl.Camera2D{}
    cam.zoom = 1.0

    // ---------- UI ----------
    slider_rect := rl.Rectangle{10, 70, 200, 20}
    slider_label := "Cluster level (k): %d"

    for !rl.WindowShouldClose() {
        // ---- camera panning ----
        if rl.IsKeyDown(.LEFT)  do cam.target.x -= 400 * rl.GetFrameTime()
        if rl.IsKeyDown(.RIGHT) do cam.target.x += 400 * rl.GetFrameTime()
        if rl.IsKeyDown(.UP)    do cam.target.y -= 400 * rl.GetFrameTime()
        if rl.IsKeyDown(.DOWN)  do cam.target.y += 400 * rl.GetFrameTime()

        // ---- cluster slider ----
        mouse := rl.GetMousePosition()
        if rl.IsMouseButtonDown(.LEFT) && rl.CheckCollisionPointRec(mouse, slider_rect) {
            ratio := (mouse.x - slider_rect.x) / slider_rect.width
            new_k := i32(math.round(ratio * 15))  // 0..15
            new_k = max(0, min(15, new_k))

            if new_k != current_k {
                current_k = new_k
                map_destroy(&game_map)
                game_map = map_create(map_rows, map_cols, dist, current_k)
            }
        }

        // ---- drawing ----
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.BeginMode2D(cam)

        for col in 0..<game_map.cols {
            for row in 0..<game_map.rows {
                tile := &game_map.tiles[col][row]
                terr := tile.terrain
                dst := rl.Rectangle{
                    f32(col) * TILE_SIZE,
                    f32(row) * TILE_SIZE,
                    TILE_SIZE,
                    TILE_SIZE,
                }
                src := rl.Rectangle{0, 0, f32(terr.texture.width), f32(terr.texture.height)}
                rl.DrawTexturePro(terr.texture, src, dst, {0, 0}, 0, rl.WHITE)
            }
        }

        rl.EndMode2D()

        // ---- UI ----
        rl.DrawFPS(10, 10)
        rl.DrawText("Arrows: Pan | Drag: Cluster | R: Regenerate", 10, 10, 20, rl.LIGHTGRAY)

        rl.DrawRectangleRec(slider_rect, rl.DARKGRAY)
        fill_w := (f32(current_k) / 15) * slider_rect.width
        rl.DrawRectangle(i32(slider_rect.x), i32(slider_rect.y), i32(fill_w), i32(slider_rect.height), rl.GREEN)
        knob_x := i32(slider_rect.x + fill_w - 6)
        rl.DrawRectangle(knob_x, i32(slider_rect.y)-4, 12, i32(slider_rect.height)+8, rl.WHITE)
        rl.DrawText(fmt.ctprintf(slider_label, current_k), i32(slider_rect.x), i32(slider_rect.y)-30, 20, rl.LIGHTGRAY)

        rl.EndDrawing()
    }

    map_destroy(&game_map)
    rl.CloseWindow()
}