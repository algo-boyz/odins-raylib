package main

import "core:fmt"
import "core:math"
import "core:sync"
import "core:thread"
import "core:time"
import "core:sync/chan"
import rl "vendor:raylib"

// Progress channel data structure
Progress_Data :: struct {
    progress: f32,
    is_finished: bool,
}

load_data :: proc(progress_channel: ^chan.Chan(Progress_Data, chan.Direction.Send)) {
    total_duration := 5.0 * time.Second
    start_time := time.now()

    for time.since(start_time) < total_duration {
        elapsed := time.since(start_time)
        progress := f32(time.duration_seconds(elapsed) / time.duration_seconds(total_duration))

        // Send progress update through channel
        chan.send(progress_channel^, Progress_Data{
            progress = progress * 500,
            is_finished = false,
        })

        // Small sleep to prevent busy waiting and ensure smooth updates
        time.sleep(16 * time.Millisecond)
    }

    // Send final completion message
    chan.send(progress_channel^, Progress_Data{
        progress = 500,
        is_finished = true,
    })
}

main :: proc() {
    // Initialization
    screen_width  :: 800
    screen_height :: 450
    rl.InitWindow(screen_width, screen_height, "Odin Raylib Threading Example")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    // State management
    State :: enum {
        WAITING,
        LOADING,
        FINISHED,
    }

    state := State.WAITING
    current_progress: f32 = 0
    load_thread: ^thread.Thread = nil

    // Create progress channel
    progress_channel, channel_err := chan.create(chan.Chan(Progress_Data), context.allocator)
    if channel_err != .None {
        fmt.eprintln("Failed to create channel")
        return
    }
    defer chan.destroy(progress_channel)

    for !rl.WindowShouldClose() {
        switch state {
        case .WAITING:
            if rl.IsKeyPressed(.ENTER) {
                // Reset progress
                current_progress = 0
                
                // Create channel for sending
                progress_send := chan.as_send(progress_channel)
                
                // Start loading thread
                load_thread = thread.create(proc(t: ^thread.Thread) {
                    progress_channel := (cast(^chan.Chan(Progress_Data, chan.Direction.Send))t.data)
                    load_data(progress_channel)
                })
                
                // Pass progress send channel to the thread
                load_thread.data = &progress_send
                thread.start(load_thread)
                
                state = .LOADING
            }
        case .LOADING:
            // Continuously receive progress updates
            for {
                progress_data, ok := chan.try_recv(progress_channel)
                if !ok do break

                current_progress = progress_data.progress
                
                if progress_data.is_finished {
                    // Clean up thread
                    if load_thread != nil {
                        thread.destroy(load_thread)
                        load_thread = nil
                    }
                    state = .FINISHED
                    break
                }
            }
        case .FINISHED:
            if rl.IsKeyPressed(.ENTER) {
                // Reset to waiting state
                state = .WAITING
            }
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        switch state {
        case .WAITING:
            rl.DrawText("PRESS ENTER to START LOADING DATA", 150, 170, 20, rl.DARKGRAY)
        case .LOADING:
            // Draw progress bar with exact progress
            rl.DrawRectangle(150, 200, i32(current_progress), 60, rl.SKYBLUE)
            
            // Blinking text
            if math.mod(rl.GetTime() * 2, 2) >= 1 {
                rl.DrawText("LOADING DATA...", 240, 210, 40, rl.DARKBLUE)
            }
        case .FINISHED:
            rl.DrawRectangle(150, 200, 500, 60, rl.LIME)
            rl.DrawText("DATA LOADED!", 250, 210, 40, rl.GREEN)
        }

        rl.DrawRectangleLines(150, 200, 500, 60, rl.DARKGRAY)
    }
}