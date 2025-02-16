# Jump Point Search
![Screenshot of the path made with JPS](assets/preview.png)

An implementation of Jump Point Search in odin based on [Viktor Rubenko's Jump-Point-Search](https://github.com/ViktorRubenko/Jump-Point-Search)



## Example Usage

A more advanced version using raylib to display the path is available in `example.odin`.

```odin
package main

import "core:fmt"
import "core:time"
import "core:math/rand"
import jps "jps"

GRID_SIZE :: 25
CELL_SIZE :: 25

START_POS := [2]int{1,1}
END_POS := [2]int{23,23}

grid := [GRID_SIZE*GRID_SIZE]int{}

//Generate a grid of random 0s and 1s
generate_grid :: proc() {
    for i in 0..<GRID_SIZE {
        for j in 0..<GRID_SIZE {
            size := j * GRID_SIZE + i
            if i == START_POS[0] && j == START_POS[1] {
                grid[size] = 0
            } else if i == END_POS[0] && j == END_POS[1] {
                grid[size] = 0
            } else {
                random_value := rand.float32()
                
                if random_value < 0.2 {
                    grid[size] = 1
                } else {
                    grid[size] = 0
                }
            }
        }
    }
}

main :: proc() {
    generate_grid()  

    start := time.now()
    //Initialise the jump point search with width, height and heuristics algorithm to use
    jps.jps_init(GRID_SIZE, GRID_SIZE, .manhatten)
    //Find optimal path with jps using 1d slice array and start and end position
    path := jps.jps(grid[:], START_POS, END_POS)
    duration := time.since(start)

    seconds := f64(duration) / f64(time.Second)
    fmt.printf("Manhatten execution time: %v\n", seconds)
    fmt.printf("Path: %v\n", path)
}

```
