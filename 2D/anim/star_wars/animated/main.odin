package main

import "core:fmt"
import "core:slice"

import rl "vendor:raylib"
import "vendor:raylib/rlgl"

import "../gif"
import "../buf"
import "../../../../rlutil"

bg_music_path ::  "assets/luis-humanoid_march-of-the-troopers.ogg"
// https://pixabay.com/music/main-title-march-of-the-troopers-star-wars-style-cinematic-music-207056/

init_stream :: proc() -> (bg_music: rl.Music) {
    rl.SetAudioStreamBufferSizeDefault(2048)
    rl.InitAudioDevice()
    if !rl.IsAudioDeviceReady() {
        fmt.eprintf("ERROR: Audio device not ready\n")
        return {}
    }
    bg_music = rl.LoadMusicStream(bg_music_path)
    if !rl.IsMusicReady(bg_music) {
        fmt.eprintf("ERROR: Music not ready\n")
        return bg_music
    }
    rl.SetMusicVolume(bg_music, 15)
    rl.PlayMusicStream(bg_music)  // Start playback
    return bg_music
}

destroy_stream :: proc(bg_music: rl.Music) {
    rl.UnloadMusicStream(bg_music)
    rl.CloseAudioDevice()
}

main :: proc() {
    WIDTH:  f32 = 600
    HEIGHT: f32 = 350
    font_size:     f32 = 24

    // Remove MSAA hint since we're using our own AA buffer
    rl.SetConfigFlags({.VSYNC_HINT})

    rl.InitWindow(i32(WIDTH), i32(HEIGHT), "Odin - Star Wars Text with AA Buffer")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    font_path :: "assets/trueno.otf"
    font := rl.LoadFontEx(font_path, i32(font_size), nil, 0)
    if font.texture.id == 0 {
        fmt.eprintf("ERROR: FAILED TO LOAD FONT: '%s'\n", font_path)
        return
    }
    rl.GenTextureMipmaps(&font.texture)
    rl.SetTextureFilter(font.texture, .TRILINEAR)

    bg_music := init_stream()
    defer destroy_stream(bg_music)

    // GIF player Setup
    player := gif.player_create()
    defer gif.player_unload(&player) 

    gif_path :: "assets/universe.gif"
    if !gif.player_load(&player, gif_path) {
        fmt.eprintf("ERROR: FAILED TO LOAD GIF: '%s'\n", gif_path)
        return
    }
    gif.player_set_speed(&player, 10)
    gif.player_play(&player)
    gif.player_set_dest_rect(&player, {0, 0, WIDTH, HEIGHT})

    // Anti-Alias Buffer Setup
    fmt.println("Initializing AA buffer for text rendering...")
    aa_buf_result := buf.init_with_postprocessing(i32(WIDTH), i32(HEIGHT), buf.AAMethod.TRILINEAR)
    
    aa_buffer: buf.FrameBuffer
    switch result in aa_buf_result {
    case buf.FrameBuffer:
        aa_buffer = result
        fmt.println("AA buffer initialized successfully")
    case buf.FrameBufferError:
        fmt.eprintf("ERROR: Failed to create AA buffer: %v\n", result)
        return
    }
    defer buf.destroy(&aa_buffer)

    msg := `A long time ago in a galaxy
far, far away....

A period ravaged by civil war.
Rebel spaceships, striking
from a hidden base, have won
their first major victory against
the Galactic Empire.
`
    text_lines := rlutil.text_split_by_newlines(msg)
    slice.reverse(text_lines[:])

    total_text_length: f32 = 0
    line_spacing: f32 = 1.8
    for &text_line in text_lines {
        line_text_measure := rl.MeasureTextEx(font, text_line.line, font_size, 0)
        text_line.line_width = line_text_measure.x
        text_line.line_height = line_text_measure.y
        total_text_length += text_line.line_height * line_spacing
    }

    camera: rl.Camera3D
    camera.position = {0.0, 100.0, -25.0}
    camera.target = {0.0, -50.0, 200.0}
    camera.up = {0.0, 1.0, 0.0}
    camera.fovy = 75.0
    camera.projection = .PERSPECTIVE

    scroll_offset: f32 = 0.0
    scroll_speed: f32 = 25.0

    // AA method cycling
    aa_methods := []buf.AAMethod{buf.AAMethod.NONE, buf.AAMethod.BILINEAR, buf.AAMethod.TRILINEAR, buf.AAMethod.MANUAL_MSAA}
    aa_names := []string{"NONE", "BILINEAR", "TRILINEAR", "MANUAL_MSAA"}
    current_aa_index := 2 // Start with TRILINEAR
    buf.set_aa_method(&aa_buffer, aa_methods[current_aa_index])

    for !rl.WindowShouldClose() {
        
        rl.UpdateMusicStream(bg_music)
        gif.player_update(&player)

        delta_time := rl.GetFrameTime()
        scroll_offset += scroll_speed * delta_time

        if scroll_offset > total_text_length + 250.0 {
            scroll_offset = 0.0
        }

        // Handle AA method switching
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            current_aa_index = (current_aa_index + 1) % len(aa_methods)
            buf.set_aa_method(&aa_buffer, aa_methods[current_aa_index])
            fmt.printf("Switched to AA method: %s\n", aa_names[current_aa_index])
        }
        
        // Draw 3D text to AA buffer
        buf.begin(&aa_buffer)
        {
            rl.ClearBackground(rl.BLANK) // Use transparent background

            rl.BeginMode3D(camera)
            {
                current_line_offset: f32 = 0.0
                for i in 0 ..< len(text_lines) {
                    line := &text_lines[i]
                    line_z_pos := scroll_offset - total_text_length + current_line_offset

                    if len(line.line) == 0 {
                        current_line_offset += line.line_height * line_spacing
                        continue
                    }

                    world_pos := rl.Vector3{0, 0, line_z_pos}
                    screen_pos := rl.GetWorldToScreen(world_pos, camera)
                    alpha: f32 = 1.0
                    if screen_pos.y < HEIGHT * 0.3 {
                        alpha = clamp(screen_pos.y / (HEIGHT * 0.3), 0.0, 1.0)
                    }
                    if alpha <= 0.01 || screen_pos.y > HEIGHT {
                        current_line_offset += line.line_height * line_spacing
                        continue
                    }
                    
                    rlgl.PushMatrix()
                    {
                        // Position the text in 3D space
                        rlgl.Translatef(line.line_width / 2, 0.0, line_z_pos)
                        
                        // Create the classic Star Wars crawl angle
                        rlgl.Rotatef(75.0, 1.0, 0.0, 0.0) // 75 degrees for perspective
                        rlgl.Rotatef(180.0, 0.0, 0.0, 1.0) // flip 180 degrees around Z-axis

                        // Create color with smooth fade
                        text_color := rl.Color{255, 255, 0, u8(alpha * 255)} // Yellow with fade
                        
                        // Single high-quality render instead of multiple hack renders
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                        rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                    }
                    rlgl.PopMatrix()
                    
                    current_line_offset += line.line_height * line_spacing
                }
            }
            rl.EndMode3D()
        }
        buf.end(&aa_buffer)

        rl.BeginDrawing()
        {
            rl.ClearBackground(rl.BLACK)

            // Draw the GIF background
            gif.player_draw(&player)
            // Draw the AA buffer with anti-aliasing
            buf.draw_current(&aa_buffer)

            rl.DrawFPS(10, 10)
            
            // Show current AA method
            aa_info := fmt.ctprintf("AA: %s (SPACE to cycle)", aa_names[current_aa_index])
            rl.DrawText(aa_info, 10, 30, 16, rl.WHITE)
            
            // Show buffer info
            width, height, samples, method := buf.get_info(&aa_buffer)
            buffer_info := fmt.ctprintf("Buffer: %dx%d, Method: %v", width, height, method)
            rl.DrawText(buffer_info, 10, 50, 12, rl.LIGHTGRAY)
        }
        rl.EndDrawing()
    }
    rl.UnloadFont(font)
}