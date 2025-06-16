package main

import "core:fmt"

import rl "vendor:raylib"

main :: proc() {
    GREY := rl.Color{29, 29, 29, 255}
    WINDOW_WIDTH :: 750
    WINDOW_HEIGHT :: 750
    CELL_SIZE :: 25
    fps:i32 = 12

    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Game of Life")
    rl.SetTargetFPS(fps)
    
    simulation := create_simulation(WINDOW_WIDTH, WINDOW_HEIGHT, CELL_SIZE)

    for !rl.WindowShouldClose() {
        // Event Handling
        if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
            mouse_pos := rl.GetMousePosition()
            row := int(mouse_pos.y) / CELL_SIZE
            column := int(mouse_pos.x) / CELL_SIZE
            toggle_cell(&simulation, row, column)
        }

        if rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
            start(&simulation)
            rl.SetWindowTitle("Game of Life is running ...")
        } else if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            stop(&simulation)
            rl.SetWindowTitle("Game of Life has stopped.")
        } else if rl.IsKeyPressed(rl.KeyboardKey.F) {
            fps += 2
            rl.SetTargetFPS(fps)
        } else if rl.IsKeyPressed(rl.KeyboardKey.S) {
            if fps > 5 {
                fps -= 2
                rl.SetTargetFPS(fps)
            }
        } else if rl.IsKeyPressed(rl.KeyboardKey.R) {
            create_random_state(&simulation)
        } else if rl.IsKeyPressed(rl.KeyboardKey.C) {
            clear_grid(&simulation)
        }

        // Updating State
        update(&simulation)

        // Drawing
        rl.BeginDrawing()
        rl.ClearBackground(GREY)
        draw(&simulation.grid)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}