package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// These are the four numbers that define the transform, i hat and j hat
I_X :: 1.0
I_Y :: 0.5
J_X :: -1.0
J_Y :: 0.5

// Sprite size
W :: 32.0
H :: 32.0

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

SCREEN_WIDTH :: 1280
SCREEN_HALF_WIDTH :: SCREEN_WIDTH / 2
SCREEN_HEIGHT :: 720
TEX_SCALE :: 4.0

cartesian_to_isometric :: proc(cartesian: rl.Vector2) -> rl.Vector2 {
    return rl.Vector2{
        cartesian.x - cartesian.y,
        (cartesian.x + cartesian.y) / 2.0,
    }
}

isometric_to_cartesian :: proc(isometric: rl.Vector2) -> rl.Vector2 {
    return rl.Vector2{
        (isometric.x / 2.0) + isometric.y,
        isometric.y - (isometric.x / 2.0),
    }
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib example - isometric")
    defer rl.CloseWindow()
    
    tile := rl.LoadTexture("assets/iso.png")
    defer rl.UnloadTexture(tile)
    
    tile_width := f32(tile.width) * TEX_SCALE
    
    rl.SetTargetFPS(60)
    
    u: f32 = 0.0
    
    for !rl.WindowShouldClose() {
        mouse_screen_position := rl.GetMousePosition()
        mouse_screen_position.x -= f32(SCREEN_HALF_WIDTH)
        
        mouse_grid_position := isometric_to_cartesian(mouse_screen_position) / (tile_width / 2.0)
        
        rl.BeginDrawing()        
        rl.ClearBackground(rl.RAYWHITE)
        
        for i in 0..<10 {
            for j in 0..<10 {
                cartesian := rl.Vector2{f32(i), f32(j)}
                isometric := cartesian_to_isometric(cartesian) * (tile_width / 2.0)
                isometric.x -= tile_width / 2.0
                isometric.x += f32(SCREEN_HALF_WIDTH)
                isometric.y += math.sin((f32(i) + u + 1.0) / 2.0) * 8.0
                isometric.y += math.sin((f32(j) + u + 2.0) / 1.0) * 8.0
                
                if int(mouse_grid_position.x) == i && int(mouse_grid_position.y) == j {
                    isometric.y -= 32.0
                }
                
                source_rect := rl.Rectangle{0, 0, f32(tile.width), f32(tile.height)}
                dest_rect := rl.Rectangle{
                    isometric.x, 
                    isometric.y, 
                    f32(tile.width) * TEX_SCALE, 
                    f32(tile.height) * TEX_SCALE,
                }
                origin := rl.Vector2{0, 0}
                
                rl.DrawTexturePro(tile, source_rect, dest_rect, origin, 0.0, rl.WHITE)
            }
        }
        u += 0.05
        rl.EndDrawing()
    }
}