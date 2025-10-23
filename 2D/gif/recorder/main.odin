package main

import "core:fmt"
import rl "vendor:raylib"
import gif "../../../rlutil/gif"

main :: proc() {
    rl.InitWindow(800, 600, "GIF Recorder")
    defer rl.CloseWindow()
    
    rec := gif.new_recorder("../assets/preview.gif", 12, 600) // 12 fps
    defer gif.recorder_cleanup(&rec)
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        // Update captures frames automagically
        gif.recorder_update(&rec)
        // Recording status
        if gif.is_recording(&rec) {
            rl.DrawText("RECORDING...", 10, 10, 20, rl.RED)
            rl.DrawText(fmt.ctprintf("Captured Frames: %d", gif.get_frame_count(&rec)), 10, 40, 20, rl.RED)
        }
        rl.EndDrawing()
    }
}