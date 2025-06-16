package moog_filter

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"
import "../"

MAX_SAMPLES            :: 512
MAX_SAMPLES_PER_UPDATE :: 4096

frequency : f64 = 440.0          // Cycles per second (hz)
audio_frequency : f64 = 440.0    // Audio frequency, for smoothing
old_frequency : f64 = 1.0        // Previous value, used to test if sine needs to be rewritten, and to smoothly modulate frequency
sine_idx : f64 = 0.0             // Index for audio rendering
moog_filter_cutoff : f64 = 500.0 // Hz

// Audio input processing callback
audio_input_callback :: proc "c" (/* void * */ buffer : rawptr, frames : c.uint) {
    audio_frequency = frequency + (audio_frequency - frequency) * 0.95
    audio_frequency += 1.0
    audio_frequency -= 1.0
    incr : f64 = audio_frequency / 48000.0
    d_ptr : ^i16  = (^i16)(buffer)

    // Create the buffer of samples to be written.
    data_f64 : [MAX_SAMPLES_PER_UPDATE]f64 

    for i := 0; i < int(frames); i += 1 {
      
        data_f64[i] = 32000.0 * math.sin(2 * math.PI * sine_idx)
        sine_idx += incr
        if sine_idx > 1.0 {
            sine_idx -= 1.0
        }
    }
    context = runtime.default_context()
    // Process a multiple samples.
    data_f64_slice := moog.process(moog_filter, data_f64[:])
    // Write the buffer of samples to output buffer.
    for i := 0; i < int(frames); i += 1 {

        d_ptr = mem.ptr_offset(d_ptr, 1)
        d_ptr^ = i16(data_f64_slice[i] * 16_000.0)
    }
}

// Create moog ladder filter.
moog_filter : ^moog.LadderFilter = nil

main :: proc () {
    // Set initial filter params.
    sample_rate := 48000 // 26040 // 44100
    moog_filter = moog.ladder_filter_create(sample_rate, moog_filter_cutoff /* 500, 2000, 1500 */,
                                             resonance = 0.1, drive = 1.0)
    defer moog.ladder_filter_destroy(moog_filter)

    // Set filter parameters during runtime.
    // moog_ladder_filter_set_cutoff(moog_filter, 1000.0)
    // moog_ladder_filter_set_resonance(moog_filter, 0.5)

    // Create a buffer of 1 second samples with a sine wave off 1000 Hz.
    
    // size : int = sample_rate
    // buffer := make([]f64, size)
    // for i := 0; i < size; i += 1 {
    //     buffer[i] = math.sin(2.0 * math.PI * 1000.0 * f64(i) / f64(sample_rate))
    // }

    // Process a multiple samples.
    // moog_process(moog_filter, buffer)

    screen_width  : i32 = 800
    screen_height : i32 = 450
    rl.InitWindow(screen_width, screen_height, "Moog Ladder Filter");
    rl.InitAudioDevice();
    rl.SetAudioStreamBufferSizeDefault(MAX_SAMPLES_PER_UPDATE)

    // Init raw audio stream (sample rate: 44100, sample size: 16bit-short, channels: 1-mono)
    stream : rl.AudioStream = rl.LoadAudioStream(48000, 16, 1)

    rl.SetAudioStreamCallback(stream, audio_input_callback)

    // Buffer for the single cycle waveform we are synthesizing
    data : ^[MAX_SAMPLES]i16 = new([MAX_SAMPLES]i16)
    defer free(data)

    // Frame buffer, describing the waveform when repeated over the course of a frame
    writeBuf : ^[MAX_SAMPLES_PER_UPDATE]i16 = new([MAX_SAMPLES_PER_UPDATE]i16)
    defer free(writeBuf)

    rl.PlayAudioStream(stream)

    // Computed size in samples of the sine wave
    wave_length : int = 1
    position : rl.Vector2 = { 0, 0 }
    rl.SetTargetFPS(30);
    for !rl.WindowShouldClose()
    {
        mouse_pos := rl.GetMousePosition()

        if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
            fp : f64 = f64(mouse_pos.y)
            frequency = 40.0 + f64(fp)
            pan : f64 = f64(mouse_pos.x) / f64(screen_width)
            rl.SetAudioStreamPan(stream, f32(pan))
        }
        // Rewrite the sine wave
        // Compute two cycles to allow the buffer padding, simplifying any modulation, resampling, etc.
        if frequency != old_frequency {
            // Compute wavelength. Limit size in both directions.
            wave_length = int(24000 / frequency)
            if wave_length > MAX_SAMPLES / 2 {
                wave_length = MAX_SAMPLES / 2
            }
            if (wave_length < 1) {
                wave_length = 1
            }
            // Write sine wave
            for i := 0; i < wave_length * 2; i += 1 {
                data[i] = i16(math.sin(((2 * math.PI * f64(i) /  f64(wave_length)))) * 32000)
            }
            // Make sure the rest of the line is flat
            for j := wave_length * 2; j < MAX_SAMPLES; j += 1 {
                data[j] = 0
            }
            old_frequency = frequency
        }
        rl.BeginDrawing();
            rl.ClearBackground(rl.RAYWHITE)

            s := fmt.aprintf("sine freq: %v Moog_Ladder_Filter: %v Hz", int(frequency), int(moog_filter_cutoff))
            defer delete(s)
            c_str := strings.clone_to_cstring(s)
            defer delete(c_str)

            rl.DrawText(c_str, rl.GetScreenWidth() - 400 /* 220 */, 10, 17 /* 20 */, rl.GRAY)
            rl.DrawText("Click mouse button to change freq. or pan", 10, 10, 17 /* 20 */, rl.DARKGRAY)

            // Draw the current buffer state proportionate to screen
            for i := 0; i < int(screen_width); i += 1 {
                position.x = f32(i)
                position.y = f32(250 + 50 * data[i * MAX_SAMPLES / int(screen_width)] / (32000.0 / 40))
                rl.DrawPixelV(position, rl.GRAY)
            }
        rl.EndDrawing();
    }
    rl.UnloadAudioStream(stream)
    rl.CloseAudioDevice()
    rl.CloseWindow()
    // moog_ladder_filter_destroy(moog_filter)
}
