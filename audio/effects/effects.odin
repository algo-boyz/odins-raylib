package audio

import c "core:c/libc"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

// Audio effect types
SoundFilter :: enum {
    NONE = 0,
    DISTORTION,
    LOWPASS,
    DELAY,
    ECHO,
}

// Global state for audio effects
@(private = "file")
AudioState :: struct {
    // Delay effect state
    delay_buffer: [^]f32,
    delay_buffer_size: u32,
    delay_read_index: u32,
    delay_write_index: u32,
    
    // Low-pass filter state
    lpf_state: [2]f32,
    lpf_cutoff: f32,
    
    // Distortion effect state
    distortion_exponent: f32,
}

@(private = "file")
audio_state := AudioState{
    delay_buffer_size = 48000 * 2,  // 1 second at 48kHz stereo
    lpf_cutoff = 100.0,
    distortion_exponent = 0.5,
}

// Audio callback procedures
@(private = "file")
sound_filters := [?]rl.AudioCallback {
    nil,
    distortion_filter,
    lowpass_filter,
    delay_filter,
    echo_filter,
}

main :: proc() {
    rl.InitWindow(800, 450, "Audio Effects Demo")
    defer rl.CloseWindow()

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    music := rl.LoadMusicStream("../a-faded-folk-song.mp3")
    defer rl.UnloadMusicStream(music)

    // Initialize delay buffer
    delay_slice := make([]f32, audio_state.delay_buffer_size)
    audio_state.delay_buffer = &delay_slice[0]
    defer delete(delay_slice)

    rl.PlayMusicStream(music)

    // UI state
    time_played: f32
    is_paused: bool
    active_effects := make(map[SoundFilter]bool)
    defer delete(active_effects)

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.UpdateMusicStream(music)

        // Handle input
        handle_input(&music, &is_paused, &active_effects)

        // Update progress bar
        time_played = rl.GetMusicTimePlayed(music) / rl.GetMusicTimeLength(music)
        if time_played > 1 do time_played = 1

        // Render UI
        render_ui(time_played, active_effects)
    }
}

handle_input :: proc(music: ^rl.Music, is_paused: ^bool, active_effects: ^map[SoundFilter]bool) {
    // Restart music
    if rl.IsKeyPressed(.SPACE) {
        rl.StopMusicStream(music^)
        rl.PlayMusicStream(music^)
    }

    // Pause/Resume
    if rl.IsKeyPressed(.P) {
        is_paused^ = !is_paused^
        if is_paused^ {
            rl.PauseMusicStream(music^)
        } else {
            rl.ResumeMusicStream(music^)
        }
    }

    // Toggle effects
    if rl.IsKeyPressed(.F) {
        toggle_effect(.LOWPASS, music^, active_effects)
    }
    if rl.IsKeyPressed(.D) {
        toggle_effect(.DELAY, music^, active_effects)
    }
    if rl.IsKeyPressed(.E) {
        toggle_effect(.ECHO, music^, active_effects)
    }
    if rl.IsKeyPressed(.T) {
        toggle_effect(.DISTORTION, music^, active_effects)
    }
}

toggle_effect :: proc(filter: SoundFilter, music: rl.Music, active_effects: ^map[SoundFilter]bool) {
    if filter == .NONE do return
    
    is_active := active_effects[filter]
    active_effects[filter] = !is_active
    
    if active_effects[filter] {
        rl.AttachAudioStreamProcessor(music.stream, sound_filters[i32(filter)])
    } else {
        rl.DetachAudioStreamProcessor(music.stream, sound_filters[i32(filter)])
    }
}

render_ui :: proc(time_played: f32, active_effects: map[SoundFilter]bool) {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    
    rl.ClearBackground(rl.RAYWHITE)

    // Title
    rl.DrawText("AUDIO EFFECTS DEMO", 280, 50, 20, rl.DARKGRAY)

    // Music status
    rl.DrawText("MUSIC PLAYING", 320, 120, 16, rl.LIGHTGRAY)

    // Progress bar
    progress_x: i32 = 200
    progress_y: i32 = 150
    progress_width: i32 = 400
    progress_height: i32 = 12
    
    rl.DrawRectangle(progress_x, progress_y, progress_width, progress_height, rl.LIGHTGRAY)
    rl.DrawRectangle(progress_x, progress_y, i32(time_played * f32(progress_width)), progress_height, rl.MAROON)
    rl.DrawRectangleLines(progress_x, progress_y, progress_width, progress_height, rl.GRAY)

    // Controls
    y_offset: i32 = 200
    rl.DrawText("CONTROLS:", 50, y_offset, 16, rl.DARKGRAY)
    y_offset += 30
    
    rl.DrawText("SPACE - Restart Music", 50, y_offset, 14, rl.GRAY)
    y_offset += 20
    rl.DrawText("P - Pause/Resume", 50, y_offset, 14, rl.GRAY)
    y_offset += 30
    
    rl.DrawText("EFFECTS:", 50, y_offset, 16, rl.DARKGRAY)
    y_offset += 30
    
    // Effect status
    draw_effect_status("F - Low Pass Filter", .LOWPASS, active_effects, 50, y_offset)
    y_offset += 20
    draw_effect_status("D - Delay", .DELAY, active_effects, 50, y_offset)
    y_offset += 20
    draw_effect_status("E - Echo", .ECHO, active_effects, 50, y_offset)
    y_offset += 20
    draw_effect_status("T - Distortion", .DISTORTION, active_effects, 50, y_offset)
}

draw_effect_status :: proc(text: cstring, filter: SoundFilter, active_effects: map[SoundFilter]bool, x, y: i32) {
    status := active_effects[filter] ? "ON" : "OFF"
    color := active_effects[filter] ? rl.GREEN : rl.GRAY
    
    full_text := rl.TextFormat("%s: %s", text, status)
    rl.DrawText(full_text, x, y, 14, color)
}

// Audio effect implementations
distortion_filter :: proc "c" (buffer: rawptr, frames: u32) {
    samples := cast([^]f32)buffer
    exp := audio_state.distortion_exponent

    for frame: u32 = 0; frame < frames; frame += 1 {
        left := &samples[frame * 2]
        right := &samples[frame * 2 + 1]

        left^ = math.pow(math.abs(left^), exp) * (left^ < 0.0 ? -1.0 : 1.0)
        right^ = math.pow(math.abs(right^), exp) * (right^ < 0.0 ? -1.0 : 1.0)
    }
}

lowpass_filter :: proc "c" (buffer: rawptr, frames: u32) {
    cutoff: f32 = audio_state.lpf_cutoff / 44100.0
    k: f32 = cutoff / (cutoff + 0.1591549431)
    samples := cast([^]f32)buffer

    for i: u32 = 0; i < frames * 2; i += 2 {
        l := samples[i]
        r := samples[i + 1]
        
        audio_state.lpf_state[0] += k * (l - audio_state.lpf_state[0])
        audio_state.lpf_state[1] += k * (r - audio_state.lpf_state[1])
        
        samples[i] = audio_state.lpf_state[0]
        samples[i + 1] = audio_state.lpf_state[1]
    }
}

delay_filter :: proc "c" (buffer: rawptr, frames: u32) {
    samples := cast([^]f32)buffer
    
    for i: u32 = 0; i < frames * 2; i += 2 {
        // Read delayed samples
        left_delay := audio_state.delay_buffer[audio_state.delay_read_index]
        audio_state.delay_read_index += 1
        right_delay := audio_state.delay_buffer[audio_state.delay_read_index]
        audio_state.delay_read_index += 1
        
        if audio_state.delay_read_index >= audio_state.delay_buffer_size {
            audio_state.delay_read_index = 0
        }
        
        // Mix current samples with delayed samples
        samples[i] = 0.7 * samples[i] + 0.3 * left_delay
        samples[i + 1] = 0.7 * samples[i + 1] + 0.3 * right_delay
        
        // Write current samples to delay buffer
        audio_state.delay_buffer[audio_state.delay_write_index] = samples[i]
        audio_state.delay_write_index += 1
        audio_state.delay_buffer[audio_state.delay_write_index] = samples[i + 1]
        audio_state.delay_write_index += 1
        
        if audio_state.delay_write_index >= audio_state.delay_buffer_size {
            audio_state.delay_write_index = 0
        }
    }
}

echo_filter :: proc "c" (buffer: rawptr, frames: u32) {
    // For now, echo is the same as delay but with different mix ratios
    samples := cast([^]f32)buffer
    
    for i: u32 = 0; i < frames * 2; i += 2 {
        left_delay := audio_state.delay_buffer[audio_state.delay_read_index]
        audio_state.delay_read_index += 1
        right_delay := audio_state.delay_buffer[audio_state.delay_read_index]
        audio_state.delay_read_index += 1
        
        if audio_state.delay_read_index >= audio_state.delay_buffer_size {
            audio_state.delay_read_index = 0
        }
        
        // Different mix ratio for echo effect
        samples[i] = 0.5 * samples[i] + 0.5 * left_delay
        samples[i + 1] = 0.5 * samples[i + 1] + 0.5 * right_delay
        
        audio_state.delay_buffer[audio_state.delay_write_index] = samples[i]
        audio_state.delay_write_index += 1
        audio_state.delay_buffer[audio_state.delay_write_index] = samples[i + 1]
        audio_state.delay_write_index += 1
        
        if audio_state.delay_write_index >= audio_state.delay_buffer_size {
            audio_state.delay_write_index = 0
        }
    }
}

// Public API for effect configuration
set_distortion_exponent :: proc(exp: f32) {
    audio_state.distortion_exponent = exp
}

set_lowpass_cutoff :: proc(cutoff: f32) {
    audio_state.lpf_cutoff = cutoff
}

// Alternative API for attaching/detaching filters globally
attach_sound_filter :: proc(filter: SoundFilter) {
    if filter == .NONE do return
    rl.AttachAudioMixedProcessor(sound_filters[i32(filter)])
}

detach_sound_filter :: proc(filter: SoundFilter) {
    if filter == .NONE do return
    rl.DetachAudioMixedProcessor(sound_filters[i32(filter)])
}