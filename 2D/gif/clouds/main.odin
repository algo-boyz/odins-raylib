package main

import "core:fmt"
import rl "vendor:raylib"
import gif "../../../rlutil/gif"

WIDTH  :: 800
HEIGHT :: 600

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Clouds from Gif Directory")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    // Create and Load the GIF Player
    
    // 1. Create a player instance
    player := gif.new_player()
    defer gif.player_unload(&player) // Ensure resources are freed on exit

    // 2. Load the animation from a directory of images
    //    Replace this path with the path to YOUR image sequence directory.
    ANIMATION_PATH :: "../assets/clouds"
    
    if !gif.player_load_dir(&player, ANIMATION_PATH) {
        // If loading fails, we can't run the demo.
        // The error will be printed to the console by the loader.
        // We'll just wait here so the user can see the empty window and console output.
        for !rl.WindowShouldClose() {
            rl.BeginDrawing()
            rl.ClearBackground(rl.DARKGRAY)
            rl.DrawText("Failed to load animation. Check console for errors.", 10, 10, 20, rl.RED)
            rl.EndDrawing()
        }
        return // Exit the main procedure
    }
    // 3. (Optional) Configure the player
    gif.player_set_speed(&player, 4) // Set animation speed (lower is faster)
    
    // 4. Define the drawing area on the screen.
    //    Let's calculate a destination rectangle to center the animation.
    texture_width := player.current_texture.width
    texture_height := player.current_texture.height
    
    dest_rect := rl.Rectangle {
        x = f32(WIDTH / 2) - f32(texture_width / 2),
        y = f32(HEIGHT / 2) - f32(texture_height / 2),
        width = f32(texture_width),
        height = f32(texture_height),
    }
    gif.player_set_dest_rect(&player, dest_rect)

    for !rl.WindowShouldClose() {
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
        gif.player_update(&player)
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        // Draw current frame of the animation
        gif.player_draw(&player)
        // Draw info text
        rl.DrawText("Playing animation from directory!", 20, 20, 20, rl.DARKGRAY)
        current_frame := gif.player_get_current_frame(&player)
        total_frames := gif.player_get_total_frames(&player)
        info_text := fmt.ctprintf("Frame: %d / %d", current_frame + 1, total_frames)
        rl.DrawText(info_text, 20, 50, 20, rl.DARKGRAY)
        rl.DrawFPS(WIDTH - 100, 20)
        rl.EndDrawing()
    }
}