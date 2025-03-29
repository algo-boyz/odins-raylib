package main

import "core:math"
import "core:fmt"
import rl "vendor:raylib"

GridTile :: struct {
    screen_coordinates: rl.Vector2,
    is_visible: bool,
}

generate_hex_grid :: proc(radius: f64, grid_width: f64, grid_height: f64, grid: [][]GridTile) {
    offset_x := -((radius * 2)) * ((grid_height) * 0.25)
    offset_y := 100.0
    horiz := f32(math.sqrt_f64(3) * radius)
    vert := f32((3.0 / 2.0) * radius)

    for y in 0..<int(grid_height) {
        for x := -(int)((grid_height - f64(y)) + 8); x < int(grid_width) - int(f64(y) * 0.5); x += 1 {
            grid_x := x - int((grid_height - f64(y)) * 0.5)
            if grid_x >= 0 {
                hex_x := (horiz * (f32(x) + (f32(y) * 0.5))) + f32(offset_x)
                hex_y := f32((vert * f32(y)) + f32(offset_y))
                // set coordinates
                grid[x][y].screen_coordinates.x = hex_x
                grid[x][y].screen_coordinates.y = hex_y
                grid[x][y].is_visible = true
                // set visibility for right edge to be symmetrical
                if (y % 2 == 1) && (x + 1 == int(grid_width) - int(f64(y) * 0.5)) {
                    grid[x][y].is_visible = false
                }
            }
        }
    }
}

draw_visible_fields :: proc(radius: f64, grid_width: f64, grid_height: f64, grid: [][]GridTile) {
    for y in 0..<int(grid_height) {
        for x in 0..<int(grid_width) {
            if grid[x][y].is_visible {
                rl.DrawPoly(
                    {grid[x][y].screen_coordinates.x, grid[x][y].screen_coordinates.y},
                    6,
                    f32(radius),
                    90,
                    rl.BEIGE,
                )
            }
        }
    }
}

debug_draw_coordinates_on_hex_grid :: proc(radius: f64, grid_width: f64, grid_height: f64, grid: [][]GridTile) {
    for y in 0..<int(grid_height) {
        for x in 0..<int(grid_width) {
            if grid[x][y].is_visible {
                hex_x := grid[x][y].screen_coordinates.x
                hex_y := grid[x][y].screen_coordinates.y
                
                y_text := fmt.ctprintf("y: %d", y)
                x_text := fmt.ctprintf("x: %d", x)
                
                rl.DrawText(
                    y_text,
                    i32(hex_x - f32(radius / 2)),
                    i32(hex_y),
                    20,
                    rl.LIME,
                )
                rl.DrawText(
                    x_text,
                    i32(hex_x - f32(radius / 2)),
                    i32(hex_y - f32(radius / 2)),
                    20,
                    rl.VIOLET,
                )
            }
        }
    }
}

draw_hex_grid_outline :: proc(radius: f64, grid_width: f64, grid_height: f64, grid: [][]GridTile) {
    for y in 0..<int(grid_height) {
        for x in 0..<int(grid_width) {
            if grid[x][y].is_visible {
                hex_x := grid[x][y].screen_coordinates.x
                hex_y := grid[x][y].screen_coordinates.y
                rl.DrawPolyLines(
                    {hex_x, hex_y},
                    6,
                    f32(radius),
                    90,
                    rl.BROWN,
                )
            }
        }
    }
}

main :: proc() {
    // Initialization
    // Constants
    screen_width : i32 = 1280
    screen_height : i32 = 720
    radius : f64 = 40
    width : i32 = 16
    height : i32 = 9
    range_in_hexes : i32 = 2  // Unused in the original code but kept for reference
    grid_width := i32(f64(width) + (f64(height) * 0.5))
    grid_height := height
    
    // Memory allocation
    grid := make([][]GridTile, grid_width)
    for x in 0..<grid_width {
        grid[x] = make([]GridTile, grid_height)
    }
    
    // Setup
    for y in 0..<grid_height {
        for x in 0..<grid_width {
            // toggle off visibility
            grid[x][y].is_visible = false
        }
    }
    
    generate_hex_grid(radius, f64(grid_width), f64(grid_height), grid)
    
    rl.InitWindow(screen_width, screen_height, "Hex Grid Demo")
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        // Update
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BROWN)
        
        draw_visible_fields(radius, f64(grid_width), f64(grid_height), grid)
        draw_hex_grid_outline(radius, f64(grid_width), f64(grid_height), grid)
        debug_draw_coordinates_on_hex_grid(radius, f64(grid_width), f64(grid_height), grid)
        
        rl.EndDrawing()
    }
    
    // Cleanup
    for x in 0..<grid_width {
        delete(grid[x])
    }
    delete(grid)
    
    rl.CloseWindow()
}