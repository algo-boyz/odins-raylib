package marching

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

// Lookup table contour patterns
CONTOURS := [16]u8{
    0b00000000,
    0b00001010,
    0b10000010,
    0b10001000,
    0b10100000,
    0b10101010,
    0b00100010,
    0b00101000,
    0b00101000,
    0b00100010,
    0b10101010,
    0b10100000,
    0b10001000,
    0b10000010,
    0b00001010,
    0b00000000,
}

Grid :: struct {
    num_rows, num_cols: u32,
    field: [][]f32,
    binary_idx: [][]u32,
    threshold, max_threshold: f32,
}

new_grid :: proc(rows_count, cols_count: u32, max_threshold: f32) -> ^Grid {
    grid := new(Grid)
    grid.num_rows = rows_count
    grid.num_cols = cols_count
    grid.max_threshold = max_threshold
    grid.threshold = max_threshold / 2
    
    // Allocate field
    grid.field = make([][]f32, rows_count)
    for i in 0..<rows_count {
        grid.field[i] = make([]f32, cols_count)
    }
    // Allocate binary_index
    grid.binary_idx = make([][]u32, rows_count - 1)
    for i in 0..<(rows_count - 1) {
        grid.binary_idx[i] = make([]u32, cols_count - 1)
    }
    return grid
}

destroy :: proc(grid: ^Grid) {
    if grid == nil do return
    
    for row in grid.field {
        delete(row)
    }
    delete(grid.field)
    
    for row in grid.binary_idx {
        delete(row)
    }
    delete(grid.binary_idx)
    
    free(grid)
}

above_threshold :: proc(threshold, value: f32) -> u32 {
    return value > threshold ? 1 : 0
}

get_index :: proc(grid: ^Grid, i, j: u32) -> u32 {
    idx: u32
    idx |= above_threshold(grid.threshold, grid.field[i - 1][j])
    idx <<= 1
    idx |= above_threshold(grid.threshold, grid.field[i - 1][j + 1])
    idx <<= 1
    idx |= above_threshold(grid.threshold, grid.field[i][j + 1])
    idx <<= 1
    idx |= above_threshold(grid.threshold, grid.field[i][j])
    return idx
}

get_indices :: proc(grid: ^Grid) {
    for i in 1..<grid.num_rows {
        for j in 0..<(grid.num_cols - 1) {
            grid.binary_idx[i - 1][j] = get_index(grid, i, j)
        }
    }
}

lerp :: proc(threshold, pos_a, pos_b, grid_a, grid_b: f32) -> f32 {
    norm_a := grid_a / threshold
    norm_b := grid_b / threshold
    return pos_a + (pos_b - pos_a) * (1 - norm_a) / (norm_b - norm_a)
}

march :: proc(grid: ^Grid, color: rl.Color, line_width: f32) {
    width := i32(rl.GetScreenWidth()) / i32(grid.num_cols)
    half_width := width / 2
    
    height := i32(rl.GetScreenHeight()) / i32(grid.num_rows)
    half_height := height / 2
    
    for i in 0..<(grid.num_rows - 1) {
        for j in 0..<(grid.num_cols - 1) {
            cell_x := f32(i32(j) * width + half_width)
            cell_y := f32(i32(i) * height + half_height)
            
            lut_idx := grid.binary_idx[i][j]
            if lut_idx == 0 || lut_idx == 15 {
                continue
            }
            vertices: [4]rl.Vector2
            idx: int
            // Check each bit in lookup table and add vertices
            if CONTOURS[lut_idx] & 128 != 0 {
                vertices[idx].x = cell_x + f32(width)
                vertices[idx].y = lerp(grid.threshold, cell_y, cell_y + f32(height), 
                                       grid.field[i][j + 1], grid.field[i + 1][j + 1])
                idx += 1
            }
            if CONTOURS[lut_idx] & 64 != 0 {
                vertices[idx].x = cell_x + f32(width)
                vertices[idx].y = cell_y
                idx += 1
            }
            if CONTOURS[lut_idx] & 32 != 0 {
                vertices[idx].x = lerp(grid.threshold, cell_x, cell_x + f32(width),
                                       grid.field[i][j], grid.field[i][j + 1])
                vertices[idx].y = cell_y
                idx += 1
            }
            if CONTOURS[lut_idx] & 16 != 0 {
                vertices[idx].x = cell_x
                vertices[idx].y = cell_y
                idx += 1
            }
            if CONTOURS[lut_idx] & 8 != 0 {
                vertices[idx].x = cell_x
                vertices[idx].y = lerp(grid.threshold, cell_y, cell_y + f32(height),
                                       grid.field[i][j], grid.field[i + 1][j])
                idx += 1
            }
            if CONTOURS[lut_idx] & 4 != 0 {
                vertices[idx].x = cell_x
                vertices[idx].y = cell_y + f32(height)
                idx += 1
            }
            if CONTOURS[lut_idx] & 2 != 0 {
                vertices[idx].x = lerp(grid.threshold, cell_x, cell_x + f32(width),
                                       grid.field[i + 1][j], grid.field[i + 1][j + 1])
                vertices[idx].y = cell_y + f32(height)
                idx += 1
            }
            if CONTOURS[lut_idx] & 1 != 0 {
                vertices[idx].x = cell_x + f32(width)
                vertices[idx].y = cell_y + f32(height)
                idx += 1
            }
            // Handle saddle points
            if idx == 4 {
                avg_value := (grid.field[i][j] + grid.field[i][j + 1] + 
                             grid.field[i + 1][j] + grid.field[i + 1][j + 1]) / 4
                
                if above_threshold(grid.threshold, avg_value) == 1 {
                    rl.DrawLineEx(vertices[0], vertices[3], line_width, color)
                    rl.DrawLineEx(vertices[1], vertices[2], line_width, color)
                } else {
                    rl.DrawLineEx(vertices[0], vertices[1], line_width, color)
                    rl.DrawLineEx(vertices[2], vertices[3], line_width, color)
                }
                continue
            }
            if idx >= 2 {
                rl.DrawLineEx(vertices[0], vertices[1], line_width, color)
            }
        }
    }
}