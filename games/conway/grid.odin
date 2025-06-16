package main

import "core:math/rand"

import rl "vendor:raylib"

Grid :: struct {
    cells: [][]int,
    rows: int,
    columns: int,
    cell_size: int,
}

create_grid :: proc(width, height, cell_size: int) -> Grid {
    rows := height / cell_size
    columns := width / cell_size
    
    cells := make([][]int, rows)
    for i in 0..<rows {
        cells[i] = make([]int, columns)
    }
    
    return Grid{
        cells = cells,
        rows = rows,
        columns = columns,
        cell_size = cell_size,
    }
}

draw :: proc(using grid: ^Grid) {
    for row in 0..<rows {
        for column in 0..<columns {
            color := rl.Color{55, 55, 55, 255} if cells[row][column] == 0 else rl.Color{0, 255, 0, 255}
            rl.DrawRectangle(
                i32(column * cell_size), 
                i32(row * cell_size), 
                i32(cell_size - 1), 
                i32(cell_size - 1), 
                color
            )
        }
    }
}

set_value :: proc(using grid: ^Grid, row, column, value: int) {
    if is_within_bounds(grid, row, column) {
        cells[row][column] = value
    }
}

get_value :: proc(using grid: ^Grid, row, column: int) -> int {
    if is_within_bounds(grid, row, column) {
        return cells[row][column]
    }
    return 0
}

is_within_bounds :: proc(using grid: ^Grid, row, column: int) -> bool {
    return row >= 0 && row < rows && column >= 0 && column < columns
}

fill_random :: proc(using grid: ^Grid) {
    for row in 0..<rows {
        for column in 0..<columns {
            random_value := rand.int_max(4)
            cells[row][column] = 1 if random_value == 4 else 0
        }
    }
}

clear :: proc(using grid: ^Grid) {
    for row in 0..<rows {
        for column in 0..<columns {
            cells[row][column] = 0
        }
    }
}

grid_toggle_cell :: proc(using grid: ^Grid, row, column: int) {
    if is_within_bounds(grid, row, column) {
        cells[row][column] = 1 - cells[row][column]
    }
}