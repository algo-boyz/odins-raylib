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

// Sprite size
W :: 32.0
H :: 32.0

// These are the four numbers that define the transform, i hat and j hat
I_X :: 1.0
I_Y :: 0.5
J_X :: -1.0
J_Y :: 0.5

to_screen_coordinate :: proc(tile: rl.Vector2) -> rl.Vector2 {
    return rl.Vector2{
        tile.x * I_X * 0.5 * W + tile.y * J_X * 0.5 * W,
        tile.x * I_Y * 0.5 * H + tile.y * J_Y * 0.5 * H,
    }
}

Matrix2x2 :: struct {
    a, b, c, d: f32,
}

invert_matrix :: proc(m: Matrix2x2) -> Matrix2x2 {
    det := 1.0 / (m.a * m.d - m.b * m.c)
    return Matrix2x2{
        a = m.d * det,
        b = -m.b * det,
        c = -m.c * det,
        d = m.a * det,
    }
}

to_grid_coordinate :: proc(screen: rl.Vector2) -> rl.Vector2 {
    m := Matrix2x2{
        a = I_X * 0.5 * W,
        b = J_X * 0.5 * W,
        c = I_Y * 0.5 * H,
        d = J_Y * 0.5 * H,
    }
    m_inv := invert_matrix(m)
    x := screen.x * m_inv.a + screen.y * m_inv.b
    y := screen.x * m_inv.c + screen.y * m_inv.d
    return rl.Vector2{x, y}
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
        rl.EndDrawing()
    }
}