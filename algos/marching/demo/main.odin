package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import ms "../"

WIDTH  :: 800
HEIGHT :: 600
GRID_ROWS :: 100
GRID_COLS :: 100 * WIDTH / HEIGHT
MAX_THRESHOLD :: 16
NUM_BALLS :: 5
MAX_SPEED :: 5
MIN_RADIUS :: 3
MAX_RADIUS :: 15

Metaballs :: struct { pos_x, pos_y, vel_x, vel_y, rad: [NUM_BALLS]f32 }

create_balls :: proc(balls: ^Metaballs) {
    for i in 0..<NUM_BALLS {
        balls.rad[i] = f32(rl.GetRandomValue(MIN_RADIUS, MAX_RADIUS))
        balls.pos_x[i] = f32(rl.GetRandomValue(i32(balls.rad[i]), GRID_COLS - i32(balls.rad[i])))
        balls.pos_y[i] = f32(rl.GetRandomValue(i32(balls.rad[i]), GRID_ROWS - i32(balls.rad[i])))
        balls.vel_x[i] = f32(rl.GetRandomValue(-MAX_SPEED, MAX_SPEED))
        balls.vel_y[i] = f32(rl.GetRandomValue(-MAX_SPEED, MAX_SPEED))
    }
}

put_balls :: proc(grid: ^ms.Grid, balls: ^Metaballs) {
    for i in 0..<grid.num_rows {
        for j in 0..<grid.num_cols {
            grid.field[i][j] = 0
            for k in 0..<NUM_BALLS {
                dx := f32(i) - balls.pos_y[k]
                dy := f32(j) - balls.pos_x[k]
                dist_sq := dx * dx + dy * dy + 0.0001
                grid.field[i][j] += (balls.rad[k] * balls.rad[k]) / dist_sq
            }
        }
    }
}

move_balls :: proc(balls: ^Metaballs) {
    dt := rl.GetFrameTime()
    
    for i in 0..<NUM_BALLS {
        // Bounce off walls
        if balls.pos_x[i] <= balls.rad[i] || balls.pos_x[i] >= GRID_COLS - balls.rad[i] {
            balls.vel_x[i] *= -1
        }
        if balls.pos_y[i] <= balls.rad[i] || balls.pos_y[i] >= GRID_ROWS - balls.rad[i] {
            balls.vel_y[i] *= -1
        }
        // Update positions
        balls.pos_x[i] += balls.vel_x[i] * dt
        balls.pos_y[i] += balls.vel_y[i] * dt
    }
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Marching Squares")
    rl.SetTraceLogLevel(.INFO)
    rl.SetTargetFPS(60)
    
    grid := ms.new_grid(GRID_ROWS, GRID_COLS, MAX_THRESHOLD)
    defer ms.destroy(grid)
    
    balls: Metaballs
    create_balls(&balls)
    
    for !rl.WindowShouldClose() {
        // Update
        move_balls(&balls)
        put_balls(grid, &balls)
        
        if rl.IsKeyPressed(.N) {
            create_balls(&balls)
        }
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        // Draw first isoline (threshold = 1)
        grid.threshold = 1
        ms.get_indices(grid)
        ms.march(grid, rl.RAYWHITE, 1)
        
        // Draw second isoline (threshold = 1.4)
        grid.threshold = 1.4
        ms.get_indices(grid)
        ms.march(grid, rl.GREEN, 2)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}