package tetris

import rl "vendor:raylib"
import "core:fmt"

Grid :: struct {
    num_rows: i32,
    num_cols: i32,
    cell_size: i32,
    grid: [20][10]i32,
    colors: []rl.Color,
}

init_grid :: proc() -> (g: Grid) {
    g.num_rows = 20
    g.num_cols = 10
    g.cell_size = 30
    g.colors = get_cell_colors()
    for row:i32; row < g.num_rows; row += 1 {
        for col:i32; col < g.num_cols; col += 1 {
            g.grid[row][col] = 0
        }
    }
    return g
}

grid_print :: proc(g: ^Grid) {
    for row:i32; row < g.num_rows; row += 1 {
        for col:i32; col < g.num_cols; col += 1 {
            fmt.printf("%d ", g.grid[row][col])
        }
        fmt.println()
    }
}

grid_draw :: proc(g: ^Grid) {
    for row:i32; row < g.num_rows; row += 1 {
        for col:i32; col < g.num_cols; col += 1 {
            cell_value := g.grid[row][col]
            rl.DrawRectangle(
                i32(col * g.cell_size + 11),
                i32(row * g.cell_size + 11),
                i32(g.cell_size - 1),
                i32(g.cell_size - 1),
                g.colors[cell_value],
            )
        }
    }
}

grid_is_cell_outside :: proc(g: ^Grid, row, col: i32) -> bool {
    return row < 0 || row >= g.num_rows || col < 0 || col >= g.num_cols
}

grid_is_cell_empty :: proc(g: ^Grid, row, col: i32) -> bool {
    return g.grid[row][col] == 0
}

grid_clear_full_rows :: proc(g: ^Grid) -> i32 {
    completed:i32
    row := g.num_rows - 1
    for row >= 0 {
        if grid_is_row_full(g, row) {
            grid_clear_row(g, row)
            completed += 1
        } else if completed > 0 {
            grid_move_row_down(g, row, completed)
        }
        row -= 1
    }
    return completed
}

grid_is_row_full :: proc(g: ^Grid, row: i32) -> bool {
    for col:i32; col < g.num_cols; col += 1 {
        if g.grid[row][col] == 0 {
            return false
        }
    }
    return true
}

grid_clear_row :: proc(g: ^Grid, row: i32) {
    for col:i32; col < g.num_cols; col += 1 {
        g.grid[row][col] = 0
    }
}

grid_move_row_down :: proc(g: ^Grid, row, num_rows: i32) {
    for col:i32; col < g.num_cols; col += 1 {
        g.grid[row + num_rows][col] = g.grid[row][col]
        g.grid[row][col] = 0
    }
}