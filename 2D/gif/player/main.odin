package main

import "core:fmt"
import rl "vendor:raylib"
import gif "../../../rlutil/gif"

WIDTH  :: 1000
HEIGHT :: 900

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "GIF Player Demo")
    defer rl.CloseWindow()
    // Create GIF players
    player := gif.new_player()
    defer gif.player_unload(&player)
    // Load GIF files
    if !gif.player_load(&player, "../../assets/universe.gif") {
        return
    }
    // Set up player 1 (full screen)
    gif.player_set_dest_rect(&player, rl.Rectangle{0, 0, f32(WIDTH), f32(HEIGHT)})
    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose() {
        // Handle input for player 1
        if rl.IsKeyPressed(.RIGHT) {
            current_delay := player.frame_delay
            gif.player_set_speed(&player, current_delay + 1)
        } else if rl.IsKeyPressed(.LEFT) {
            current_delay := player.frame_delay
            gif.player_set_speed(&player, current_delay - 1)
        }
        if rl.IsKeyPressed(.SPACE) {
            if gif.player_is_playing(&player) {
                gif.player_pause(&player)
            } else {
                gif.player_play(&player)
            }
        }
        // Update players
        gif.player_update(&player)
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        // Draw players
        gif.player_draw(&player)
        // Draw UI
        rl.DrawText(fmt.ctprintf("TOTAL FRAMES: %02d", gif.player_get_total_frames(&player)), 50, 30, 20, rl.LIGHTGRAY)
        rl.DrawText(fmt.ctprintf("CURRENT FRAME: %02d", gif.player_get_current_frame(&player)), 50, 60, 20, rl.GRAY)
        rl.DrawText(fmt.ctprintf("FPS: %02d", gif.player_get_fps(&player)), 50, 90, 20, rl.GRAY)
        rl.DrawText("LEFT/RIGHT: Speed | SPACE: Play/Pause", 50, HEIGHT - 30, 16, rl.LIGHTGRAY)
        rl.EndDrawing()
    }
}