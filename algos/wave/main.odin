package main

import "core:fmt"
import "core:time"
import rl "vendor:raylib"
import "wfc"

main :: proc() {
    target_fps:i32 = 60
    rl.SetTraceLogLevel(.WARNING)
    rl.InitWindow(1200, 700, "Overlapping WFC")
    rl.SetTargetFPS(target_fps)

    // Init the wave collapse function
    wave_state: wfc.WaveState
    output_width := 64
    output_height := 64
    pattern_dim := 3
    max_depth := 128
    wfc.init(&wave_state, "assets/ColoredCity.png", output_width, output_height, pattern_dim, max_depth)

    status := 0
    tries := 1
    collapse_avg := 0.0

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        // Collapse the WFC as many times as possible in the allocated frame time
        start := time.now()
        current := time.now()
        collapse_count := 0

        for status == 0 && time.duration_seconds(time.diff(start, current)) < (1.0 / f64(target_fps) - 0.01) {
            status = wfc.collapse(&wave_state)
            current = time.now()
            collapse_count += 1
        }

        collapse_avg = (collapse_avg * 0.9) + (f64(collapse_count) * 0.1)

        // Restart on SPACE or if the WFC failed
        if rl.IsKeyPressed(.SPACE) || (status == -1) {
            wfc.restart(&wave_state)
            status = 0
            tries += 1

            if rl.IsKeyPressed(.SPACE) {
                tries = 0
            }
        }

        // Draw the WFC and information
        wfc.draw(&wave_state, false)

        rl.DrawFPS(10, 10)
        
        status_text:cstring = "Incomplete"
        if status == -1 do status_text = "Failed"
        else if status == 1 do status_text = "Complete"
        rl.DrawText(status_text, 10, 40, 20, rl.BLACK)
        
        rl.DrawText(fmt.ctprintf("Tries: %d", tries), 10, 60, 20, rl.BLACK)
        rl.DrawText(fmt.ctprintf("Total Collapses: %d", wave_state.collapse_counter), 10, 80, 20, rl.BLACK)
        
        collapses_text:cstring = "Avg Collapses / Frame: N/A"
        if status != 1 do collapses_text = fmt.ctprintf("Avg Collapses / Frame: %d", int(collapse_avg))
        rl.DrawText(collapses_text, 10, 100, 20, rl.BLACK)
        
        rl.DrawText("Press [SPACE] to restart", 10, 120, 20, rl.BLACK)

        rl.EndDrawing()
    }

    wfc.destroy(&wave_state)

    rl.CloseWindow()
}