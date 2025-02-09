package rayThing

import rand "core:math/rand"

import rl "vendor:raylib"

WINDOW_SIZE :: 900
GRID_WIDTH :: 90
GRID_HEIGHT :: 100

CELL_SIZE :: WINDOW_SIZE / GRID_WIDTH

Cell :: struct {
    value: int
}

main :: proc(){
    // Raylib setup
    rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "2D Flame");
    rl.SetTargetFPS(60);

    grid := make([][GRID_WIDTH]Cell, GRID_HEIGHT)
    defer delete(grid)
   
    counter := 0
    for !rl.WindowShouldClose(){       

        update_flame(grid);
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);    
        draw_flame(grid);    
        rl.EndDrawing();       
    }

    rl.CloseWindow();
}

update_flame :: proc(grid: [][GRID_WIDTH]Cell) {    

    // x is the row, Under skjørtet
    // y is the column, Og så oppover

    // y     5
    // y    4
    // y   3
    // y  2
    // y 1
    // y0
    //  xxxxxxxxx  
    
    // fill bottom row with random values    
    for x in 0..<GRID_WIDTH {
        grid[GRID_HEIGHT-1][x].value = rand.int_max(256)
    }    
    // Update cells
    for y in 1..<GRID_HEIGHT {
        for x in 0..<GRID_WIDTH {
             /* 
               Calculate new value with heat diffusion algorithm
               this is a kind of cellular automata
               we are updating the value of the cell based on the values of the cells around it
               the new value is the average of the cell and its neighbors  
               4 cells in total, 1 above and 3 to the sides     
           
               The neighbors considered are:

                    The cell to the left
                    The cell itself
                    The cell to the right
                    The cell below
            */   

            index := GRID_HEIGHT - y
            left := max(x - 1, 0)
            right := min(x + 1, GRID_WIDTH - 1)

            new_value := (
                grid[index][left].value +
                grid[index][x].value +
                grid[index][right].value +
                grid[index-1][x].value) / 4
      
            grid[index-1][x].value = max(0, new_value - rand.int_max(3))
        }
    }
}

draw_flame :: proc(grid: [][GRID_WIDTH]Cell) {
    for y in 0..<GRID_HEIGHT {
        for x in 0..<GRID_WIDTH {
            cell := grid[y][x]
            
            //purple tones
            color := rl.Color{u8(cell.value), u8(cell.value/2), u8(cell.value), 255}
            rl.DrawRectangle(
                i32(x * CELL_SIZE), 
                i32(y * CELL_SIZE), 
                i32(CELL_SIZE), 
                i32(CELL_SIZE), 
                color
            )
        }
    }
}

// PickColor :: proc() -> rl.Color {   
//     return rl.Color{
//         u8(rand.int_max(256)),
//         u8(rand.int_max(256)),
//         u8(rand.int_max(256)),
//         255,
//     }
// }