package floodfill

import rl "vendor:raylib"

ROWS :: 32
COLS :: 32
CELL_SIZE :: 32
EMPTY :: 0
FILLED :: 1
OBSTACLE :: 2

WINDOW_W :: COLS * CELL_SIZE
WINDOW_H :: ROWS * CELL_SIZE

cells: [ROWS][COLS]int

empty_cells :: proc() {
    for i in 0..<ROWS {
        for j in 0..<COLS {
            cells[i][j] = EMPTY
        }
    }
}

render_cells :: proc() {
    // Draw filled and obstacle cells
    for i in 0..<ROWS {
        for j in 0..<COLS {
            if cells[i][j] == FILLED {
                rl.DrawRectangle(
                    i32(j * CELL_SIZE), 
                    i32(i * CELL_SIZE), 
                    CELL_SIZE, 
                    CELL_SIZE, 
                    rl.GRAY
                )
            }
            if cells[i][j] == OBSTACLE {
                rl.DrawRectangle(
                    i32(j * CELL_SIZE), 
                    i32(i * CELL_SIZE), 
                    CELL_SIZE, 
                    CELL_SIZE, 
                    rl.WHITE
                )
            }
        }
    }
    // Draw grid lines
    for i in 0..<ROWS {
        rl.DrawLine(
            0, 
            i32(i * CELL_SIZE), 
            WINDOW_W, 
            i32(i * CELL_SIZE), 
            rl.WHITE
        )
        rl.DrawLine(
            i32(i * CELL_SIZE), 
            0, 
            i32(i * CELL_SIZE), 
            WINDOW_H, 
            rl.WHITE
        )
    }
}

flood_fill :: proc(x, y: int) {
    // Base cases
    if x < 0 || x >= COLS do return
    if y < 0 || y >= ROWS do return
    if cells[y][x] == OBSTACLE do return
    if cells[y][x] == FILLED do return
    
    cells[y][x] = FILLED
    flood_fill(x - 1, y)
    flood_fill(x + 1, y)
    flood_fill(x, y + 1)
    flood_fill(x, y - 1)
}

main :: proc() {
    rl.InitWindow(WINDOW_W, WINDOW_H, "FloodFill")
    rl.SetTargetFPS(30)
    
    for !rl.WindowShouldClose() {
        mouse_pos := rl.GetMousePosition()
        row := int(mouse_pos.y / CELL_SIZE)
        col := int(mouse_pos.x / CELL_SIZE)
        
        if rl.IsKeyPressed(.ENTER) {
            empty_cells()
        }
        if rl.IsMouseButtonPressed(.LEFT) {
            if row >= 0 && row < ROWS && col >= 0 && col < COLS {
                if cells[row][col] == EMPTY {
                    flood_fill(col, row)
                }
            }
        } else if rl.IsMouseButtonPressed(.RIGHT) {
            if row >= 0 && row < ROWS && col >= 0 && col < COLS {
                if cells[row][col] == OBSTACLE {
                    cells[row][col] = EMPTY
                } else {
                    cells[row][col] = OBSTACLE
                }
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        render_cells()
        rl.EndDrawing()
    }
    rl.CloseWindow()
}