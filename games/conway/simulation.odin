package main

Simulation :: struct {
    grid: Grid,
    temp_grid: Grid,
    is_running: bool,
}

create_simulation :: proc(width, height, cell_size: int) -> Simulation {
    return Simulation{
        grid = create_grid(width, height, cell_size),
        temp_grid = create_grid(width, height, cell_size),
        is_running = false,
    }
}

start :: proc(using simulation: ^Simulation) {
    is_running = true
}

stop :: proc(using simulation: ^Simulation) {
    is_running = false
}

is_running :: proc(using simulation: ^Simulation) -> bool {
    return is_running
}

count_live_neighbors :: proc(using simulation: ^Simulation, row, column: int) -> int {
    neighbor_offsets := [][2]int{
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
        {-1, -1}, {-1, 1}, {1, -1}, {1, 1},
    }
    
    live_neighbors := 0
    for offset in neighbor_offsets {
        neighbor_row := (row + offset[0] + grid.rows) % grid.rows
        neighbor_column := (column + offset[1] + grid.columns) % grid.columns
        live_neighbors += get_value(&grid, neighbor_row, neighbor_column)
    }
    return live_neighbors
}

update :: proc(using simulation: ^Simulation) {
    if !is_running do return
    
    for row in 0..<grid.rows {
        for column in 0..<grid.columns {
            live_neighbors := count_live_neighbors(simulation, row, column)
            cell_value := get_value(&grid, row, column)
            
            if cell_value == 1 {
                if live_neighbors > 3 || live_neighbors < 2 {
                    set_value(&temp_grid, row, column, 0)
                } else {
                    set_value(&temp_grid, row, column, 1)
                }
            } else {
                if live_neighbors == 3 {
                    set_value(&temp_grid, row, column, 1)
                } else {
                    set_value(&temp_grid, row, column, 0)
                }
            }
        }
    }
    grid = temp_grid
}

clear_grid :: proc(using simulation: ^Simulation) {
    if !is_running {
        clear(&grid)
    }
}

create_random_state :: proc(using simulation: ^Simulation) {
    if !is_running {
        fill_random(&grid)
    }
}

toggle_cell :: proc(using simulation: ^Simulation, row, column: int) {
    if !is_running {
        grid_toggle_cell(&grid, row, column)
    }
}