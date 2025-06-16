package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import rl "vendor:raylib"
import "mini" // Assuming the audio wrapper is in fx package

// Demo state
Demo :: struct {
    audio_clip: mini.Audio,
    loaded: bool,
    show_help: bool,
    last_update: time.Time,
    playback_speed: f32,
    volume: f32,
}

main :: proc() {
    demo := Demo{
        show_help = true,
        playback_speed = 1.0,
        volume = 0.8,
        last_update = time.now(),
    }

    // Initialize Raylib for GUI
    rl.InitWindow(800, 600, "Audio Wrapper Demo")
    rl.SetTargetFPS(60)
    
    // Enable file dropping
    fmt.println("Initializing window with file drop support...")
    
    defer rl.CloseWindow()

    // Initialize audio engine
    success, err := mini.init_audio()
    if !success {
        fmt.printf("Failed to initialize audio: %v\n", err)
        return
    }
    defer mini.cleanup_audio_engine()

    // Try to load a default audio file if provided as command line argument
    if len(os.args) > 1 {
        load_audio_file(&demo, os.args[1])
    }

    // Main loop
    for !rl.WindowShouldClose() {
        update_demo(&demo)
        draw_demo(&demo)
    }

    // Cleanup
    if demo.loaded {
        mini.unload_audio(&demo.audio_clip)
    }
}

update_demo :: proc(demo: ^Demo) {
    // Handle keyboard input
    if rl.IsKeyPressed(.H) {
        demo.show_help = !demo.show_help
    }

    // Enhanced file drop debugging
    if rl.IsFileDropped() {
        fmt.println("=== FILE DROP DETECTED ===")
        files := rl.LoadDroppedFiles()
        defer rl.UnloadDroppedFiles(files)
        
        fmt.printf("Number of files dropped: %d\n", files.count)
        fmt.printf("Files struct: %#v\n", files)
        
        if files.count > 0 {
            for i in 0..<files.count {
                // Debug: Print raw pointer and C string
                fmt.printf("File %d - Raw pointer: %p\n", i, files.paths[i])
                if files.paths[i] != nil {
                    // Convert the C string to Odin string properly
                    filepath := string(cstring(files.paths[i]))
                    fmt.printf("File %d - Converted path: '%s'\n", i, filepath)
                    fmt.printf("File %d - String length: %d\n", i, len(filepath))
                    
                    // Try to load the first valid file
                    if i == 0 {
                        load_audio_file(demo, filepath)
                    }
                }
            }
        } else {
            fmt.println("WARNING: File drop detected but no files in array!")
        }
        fmt.println("=== END FILE DROP ===")
    }
    
    // Additional debugging - check every frame for file drop status
    // Remove this after debugging to avoid spam
    /*
    if rl.IsKeyPressed(.F) {
        fmt.printf("Manual file drop check - IsFileDropped(): %v\n", rl.IsFileDropped())
    }
    */

    if !demo.loaded {
        return
    }

    // Playback controls
    if rl.IsKeyPressed(.SPACE) {
        state := mini.get_playback_state(&demo.audio_clip)
        switch state {
        case "playing":
            mini.pause_audio(&demo.audio_clip)
        case "paused":
            mini.resume_audio(&demo.audio_clip)
        case "stopped":
            mini.play_audio(&demo.audio_clip)
        }
    }

    if rl.IsKeyPressed(.S) {
        mini.stop_audio(&demo.audio_clip)
    }

    if rl.IsKeyPressed(.R) {
        mini.restart_audio(&demo.audio_clip)
    }

    if rl.IsKeyPressed(.L) {
        current_loop := mini.is_looping(&demo.audio_clip)
        mini.set_looping(&demo.audio_clip, !current_loop)
    }

    // Volume control
    if rl.IsKeyDown(.UP) {
        demo.volume = clamp(demo.volume + 0.02, 0.0, 1.0)
        mini.set_volume(&demo.audio_clip, demo.volume)
    }
    if rl.IsKeyDown(.DOWN) {
        demo.volume = clamp(demo.volume - 0.02, 0.0, 1.0)
        mini.set_volume(&demo.audio_clip, demo.volume)
    }

    // Playback speed control
    if rl.IsKeyDown(.RIGHT) {
        demo.playback_speed = clamp(demo.playback_speed + 0.02, 0.25, 4.0)
        mini.set_playback_rate(&demo.audio_clip, demo.playback_speed)
    }
    if rl.IsKeyDown(.LEFT) {
        demo.playback_speed = clamp(demo.playback_speed - 0.02, 0.25, 4.0)
        mini.set_playback_rate(&demo.audio_clip, demo.playback_speed)
    }

    // Seeking
    if rl.IsKeyPressed(.ONE) {
        duration := mini.get_duration(&demo.audio_clip)
        mini.set_time(&demo.audio_clip, duration * 0.1)
    }
    if rl.IsKeyPressed(.TWO) {
        duration := mini.get_duration(&demo.audio_clip)
        mini.set_time(&demo.audio_clip, duration * 0.2)
    }
    if rl.IsKeyPressed(.THREE) {
        duration := mini.get_duration(&demo.audio_clip)
        mini.set_time(&demo.audio_clip, duration * 0.3)
    }
    if rl.IsKeyPressed(.FOUR) {
        duration := mini.get_duration(&demo.audio_clip)
        mini.set_time(&demo.audio_clip, duration * 0.4)
    }
    if rl.IsKeyPressed(.FIVE) {
        duration := mini.get_duration(&demo.audio_clip)
        mini.set_time(&demo.audio_clip, duration * 0.5)
    }

    // Reset controls
    if rl.IsKeyPressed(.ZERO) {
        demo.playback_speed = 1.0
        demo.volume = 0.8
        mini.set_playback_rate(&demo.audio_clip, demo.playback_speed)
        mini.set_volume(&demo.audio_clip, demo.volume)
    }

    // Unload current audio
    if rl.IsKeyPressed(.U) {
        mini.unload_audio(&demo.audio_clip)
        demo.loaded = false
    }
}

draw_demo :: proc(demo: ^Demo) {
    rl.BeginDrawing()
    defer rl.EndDrawing()

    rl.ClearBackground(rl.DARKGRAY)

    y_offset: i32 = 20

    // Title
    rl.DrawText("Audio Wrapper Demo", 20, y_offset, 24, rl.WHITE)
    y_offset += 40

    if !demo.loaded {
        // Instructions for loading
        rl.DrawText("Drop an audio file (.mp3/.wav) here or run with:", 20, y_offset, 16, rl.LIGHTGRAY)
        y_offset += 25
        rl.DrawText("./demo path/to/audio.mp3", 20, y_offset, 16, rl.LIGHTGRAY)
        y_offset += 40
        rl.DrawText("Supported formats: MP3, WAV", 20, y_offset, 16, rl.YELLOW)
        y_offset += 25
        rl.DrawText("(Make sure to drag files directly onto this window)", 20, y_offset, 12, rl.GRAY)
    } else {
        // Audio information
        draw_audio_info(demo, &y_offset)
        
        // Playback controls visualization
        draw_playback_controls(demo, &y_offset)
        
        // Progress bar
        draw_progress_bar(demo, &y_offset)
    }

    // Help overlay
    if demo.show_help {
        draw_help_overlay()
    } else {
        rl.DrawText("Press H for help", 20, i32(rl.GetScreenHeight()) - 30, 14, rl.LIGHTGRAY)
    }
}

draw_audio_info :: proc(demo: ^Demo, y_offset: ^i32) {
    rl.DrawText("Audio Information:", 20, y_offset^, 18, rl.WHITE)
    y_offset^ += 30

    // Format information
    sample_rate := mini.get_sample_rate(&demo.audio_clip)
    channels := mini.get_channels(&demo.audio_clip)
    bitrate := mini.get_bitrate(&demo.audio_clip)
    duration := mini.get_duration(&demo.audio_clip)

    info_text := fmt.ctprintf("Sample Rate: %d Hz | Channels: %d | Bitrate: ~%d bps", 
                              sample_rate, channels, bitrate)
    rl.DrawText(info_text, 20, y_offset^, 14, rl.LIGHTGRAY)
    y_offset^ += 25

    duration_text := fmt.ctprintf("Duration: %.2f seconds", duration)
    rl.DrawText(duration_text, 20, y_offset^, 14, rl.LIGHTGRAY)
    y_offset^ += 40
}

draw_playback_controls :: proc(demo: ^Demo, y_offset: ^i32) {
    rl.DrawText("Playback Status:", 20, y_offset^, 18, rl.WHITE)
    y_offset^ += 30

    // Current state
    state := mini.get_playback_state(&demo.audio_clip)
    state_color := rl.GRAY
    switch state {
    case "playing": state_color = rl.GREEN
    case "paused": state_color = rl.YELLOW
    case "stopped": state_color = rl.RED
    }
    
    state_text := fmt.ctprintf("State: %s", strings.to_upper(state))
    rl.DrawText(state_text, 20, y_offset^, 16, state_color)
    y_offset^ += 25

    // Current time
    current_time := mini.get_time(&demo.audio_clip)
    duration := mini.get_duration(&demo.audio_clip)
    time_text := fmt.ctprintf("Time: %.2f / %.2f seconds", current_time, duration)
    rl.DrawText(time_text, 20, y_offset^, 14, rl.LIGHTGRAY)
    y_offset^ += 25

    // Volume and speed
    volume := mini.get_volume(&demo.audio_clip)
    speed := mini.get_playback_rate(&demo.audio_clip)
    controls_text := fmt.ctprintf("Volume: %.0f%% | Speed: %.2fx", volume * 100, speed)
    rl.DrawText(controls_text, 20, y_offset^, 14, rl.LIGHTGRAY)
    y_offset^ += 25

    // Looping status
    is_loop := mini.is_looping(&demo.audio_clip)
    loop_text := fmt.ctprintf("Looping: %s", is_loop ? "ON" : "OFF")
    loop_color := is_loop ? rl.GREEN : rl.RED
    rl.DrawText(loop_text, 20, y_offset^, 14, loop_color)
    y_offset^ += 40
}

draw_progress_bar :: proc(demo: ^Demo, y_offset: ^i32) {
    current_time := mini.get_time(&demo.audio_clip)
    duration := mini.get_duration(&demo.audio_clip)
    
    if duration > 0 {
        progress := current_time / duration
        
        bar_width: i32 = 400
        bar_height: i32 = 20
        bar_x: i32 = 20
        bar_y: i32 = y_offset^
        
        // Background
        rl.DrawRectangle(bar_x, bar_y, bar_width, bar_height, rl.DARKGRAY)
        
        // Progress
        progress_width := i32(f32(bar_width) * progress)
        rl.DrawRectangle(bar_x, bar_y, progress_width, bar_height, rl.BLUE)
        
        // Border
        rl.DrawRectangleLines(bar_x, bar_y, bar_width, bar_height, rl.WHITE)
        
        y_offset^ += 35
    }
}

draw_help_overlay :: proc() {
    overlay_width: i32 = 400
    overlay_height: i32 = 450
    overlay_x: i32 = (rl.GetScreenWidth() - overlay_width) / 2
    overlay_y: i32 = (rl.GetScreenHeight() - overlay_height) / 2

    // Semi-transparent background
    rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), {0, 0, 0, 180})
    
    // Help box
    rl.DrawRectangle(overlay_x, overlay_y, overlay_width, overlay_height, rl.RAYWHITE)
    rl.DrawRectangleLines(overlay_x, overlay_y, overlay_width, overlay_height, rl.BLACK)

    // Help text
    help_y := overlay_y + 20
    rl.DrawText("CONTROLS", overlay_x + 20, help_y, 20, rl.BLACK)
    help_y += 35

    help_items := []string{
        "SPACE - Play/Pause/Resume",
        "S - Stop",
        "R - Restart",
        "L - Toggle Looping",
        "",
        "UP/DOWN - Volume Control",
        "LEFT/RIGHT - Speed Control",
        "",
        "1-5 - Seek to 10%, 20%, 30%, 40%, 50%",
        "0 - Reset Volume & Speed",
        "",
        "U - Unload Current Audio",
        "H - Toggle This Help",
        "",
        "Drop files to load new audio",
    }

    for item in help_items {
        if item == "" {
            help_y += 10
        } else {
            rl.DrawText(strings.clone_to_cstring(item), overlay_x + 20, help_y, 14, rl.DARKGRAY)
            help_y += 20
        }
    }
}

load_audio_file :: proc(demo: ^Demo, filepath: string) {
    fmt.printf("load_audio_file called with: '%s'\n", filepath)
    
    // Check if file exists first
    if !os.exists(filepath) {
        fmt.printf("ERROR: File does not exist: '%s'\n", filepath)
        return
    }
    
    fmt.printf("File exists, proceeding with load...\n")
    
    // Unload current audio if loaded
    if demo.loaded {
        fmt.println("Unloading previous audio...")
        mini.unload_audio(&demo.audio_clip)
        demo.loaded = false
    }

    // Load new audio
    fmt.printf("Calling mini.load_audio...\n")
    clip, err := mini.load_audio(filepath)
    if err != .NONE {
        fmt.printf("ERROR: Failed to load audio '%s': %v\n", filepath, err)
        return
    }

    demo.audio_clip = clip
    demo.loaded = true
    
    // Set initial volume and speed
    mini.set_volume(&demo.audio_clip, demo.volume)
    mini.set_playback_rate(&demo.audio_clip, demo.playback_speed)

    fmt.printf("SUCCESS: Loaded audio file '%s'\n", filepath)
    fmt.printf("Duration: %.2f seconds\n", mini.get_duration(&demo.audio_clip))
    fmt.printf("Sample Rate: %d Hz\n", mini.get_sample_rate(&demo.audio_clip))
    fmt.printf("Channels: %d\n", mini.get_channels(&demo.audio_clip))
}

format_time :: proc(seconds: f32) -> string {
    mins := int(seconds) / 60
    secs := int(seconds) % 60
    return fmt.tprintf("%d:%02d", mins, secs)
}