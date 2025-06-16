// https://github.com/Soare-Robert-Daniel/wav-file-visualizer-odin-raylib
package wav

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

FPS :: 60
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
WAVE_HEIGHT_PADDING: i32 : 100

main :: proc() {

	// if len(os.args) < 2 {
	// 	fmt.println("Usage: program <path_to_audio_file>")
	// 	os.exit(1)
	// }

	// audio_sample_file_path := os.args[1]
	audio_sample_file_path := "../stringpluck.wav"

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	audio_samples := load_sample(audio_sample_file_path)

	rl.SetTargetFPS(FPS)

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Audio Waveform Visualization")
	defer rl.CloseWindow()

	window_width := rl.GetScreenWidth()
	window_height := rl.GetScreenHeight()

	wave_heights := compute_wave_height(audio_samples, window_width, window_height)

	delete(audio_samples)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		draw_waveform(wave_heights, wave_draw_offset = window_height / 2)

		rl.DrawText("Audio Waveform Visualization", 10, 10, 20, rl.DARKGRAY)
		rl.EndDrawing()
	}
}

load_sample :: proc(sample_file_path: string) -> []f32 {
	audio_wave := rl.LoadWave(strings.clone_to_cstring(sample_file_path))
	defer rl.UnloadWave(audio_wave)

	samples_len := audio_wave.frameCount * audio_wave.channels
	fmt.printfln(
		"[INFO][Audio] Channels: %d | Frame Count: %d | Total samples: %d",
		audio_wave.channels,
		audio_wave.frameCount,
		samples_len,
	)

	audio_samples := make([]f32, samples_len)

	// Normalize the amplitude in the samples.
	switch audio_wave.sampleSize {
	case 8:
		slice8 := mem.slice_ptr(cast(^u8)audio_wave.data, cast(int)samples_len)
		for i in 0 ..< samples_len {
			audio_samples[i] = f32(slice8[i]) / 255.0 * 2 - 1
		}

	case 16:
		slice16 := mem.slice_ptr(cast(^i16)audio_wave.data, cast(int)samples_len)
		for i in 0 ..< samples_len {
			audio_samples[i] = f32(slice16[i]) / 32768.0
		}

	case 32:
		slice32 := mem.slice_ptr(cast(^f32)audio_wave.data, cast(int)samples_len)
		for i in 0 ..< samples_len {
			audio_samples[i] = slice32[i]
		}

	case:
		fmt.println("Unsupported sample size:", audio_wave.sampleSize)
	}

	return audio_samples
}

compute_wave_height :: proc(samples: []f32, window_width: i32, window_height: i32) -> []i32 {
	wave_heights := make([]i32, window_width)

	waveform_height := f32(window_height - WAVE_HEIGHT_PADDING)

	sample_count := cast(i32)len(samples)
	samples_per_pixel := max(1, sample_count / window_width)

	for x: i32 = 0; x < window_width; x += 1 {
		start_sample := x * samples_per_pixel
		end_sample := min((x + 1) * samples_per_pixel, sample_count)

		// Only the max normalized amplitude will be used in rendering.
		max_amplitude: f32 = 0
		for i := start_sample; i < end_sample; i += 1 {
			max_amplitude = max(max_amplitude, abs(samples[i]))
		}

		wave_heights[x] = cast(i32)(max_amplitude * waveform_height / 2)
	}

	return wave_heights
}

draw_waveform :: proc(wave_heights: []i32, wave_draw_offset: i32) {
	wave_num := cast(i32)len(wave_heights)

	for x: i32 = 0; x < wave_num; x += 1 {
		rl.DrawLine(
			x,
			wave_draw_offset - wave_heights[x],
			x,
			wave_draw_offset + wave_heights[x],
			rl.BLUE,
		)
	}
}