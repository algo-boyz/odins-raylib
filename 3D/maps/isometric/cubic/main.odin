package isometric

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

import "core:math/linalg"

TILE_SIZE :: 32
GRID_SIZE :: 32  // Configurable grid size
SCREEN_OFFSET :: 450

ISO_MATRIX :: linalg.Matrix2f32 {
    1 * 0.5 * TILE_SIZE, -1 * 0.5 * TILE_SIZE,
    0.5 * 0.5 * TILE_SIZE, 0.5 * 0.5 * TILE_SIZE
}

to_screen_coordinate :: proc(tile: rl.Vector2) -> rl.Vector2 {
    return ISO_MATRIX * tile
}

to_grid_coordinate :: proc(screen: rl.Vector2) -> rl.Vector2 {    
    inv := linalg.matrix2_inverse_f32(ISO_MATRIX)
    return screen * inv
}

main :: proc() {
    rl.InitWindow(1280, 720, "Isometric Grid")
    defer rl.CloseWindow()

    rl.SetTargetFPS(144)

    image := rl.LoadImage("assets/grass.png")
    hl := rl.LoadImage("assets/highlight.png")

    texture := rl.LoadTextureFromImage(image)
    defer rl.UnloadTexture(texture)
    
    hl_texture := rl.LoadTextureFromImage(hl)
    defer rl.UnloadTexture(hl_texture)

    rl.UnloadImage(image)
    rl.UnloadImage(hl)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.BLACK)

        mouse := rl.GetMousePosition()
        mouse.x -= SCREEN_OFFSET

        grid_pos := to_grid_coordinate(mouse)

        rl.DrawText(
            rl.TextFormat("Grid Position: %d, %d", int(grid_pos.x), int(grid_pos.y)), 
            5, 
            5, 
            14, 
            rl.WHITE,
        )
        
        // Draw the grid
        for y in 0..<GRID_SIZE {
            for x in 0..<GRID_SIZE {
                iso_pos := to_screen_coordinate({f32(x), f32(y)})
                iso_pos.x -= TILE_SIZE * 0.5
                iso_pos.x += SCREEN_OFFSET

                // Check if mouse is over current tile
                if int(grid_pos.x) == x && int(grid_pos.y) == y {
                    rl.DrawTexture(
                        texture,
                        i32(iso_pos.x),
                        i32(iso_pos.y - 5),  // Slight lift for hover effect
                        rl.WHITE,
                    )
                    rl.DrawTexture(
                        hl_texture,
                        i32(iso_pos.x),
                        i32(iso_pos.y - 5),
                        rl.WHITE,
                    )
                } else {
                    rl.DrawTexture(texture, i32(iso_pos.x), i32(iso_pos.y), rl.WHITE)
                }
                // Draw grid lines (optional)
                next_pos := to_screen_coordinate({f32(x + 1), f32(y)})
                next_pos.x += SCREEN_OFFSET
                rl.DrawLineV(
                    {f32(iso_pos.x), f32(iso_pos.y)},
                    {f32(next_pos.x), f32(next_pos.y)},
                    {100, 100, 100, 100},
                )
            }
        }
    }
}