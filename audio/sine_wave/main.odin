package sine_wave

import "core:sync"
import "core:mem"
import "core:thread"
import "core:time"
import "core:fmt"
import "base:runtime"
import "core:math"
import "core:strings"

import ma "vendor:miniaudio"
import rl "vendor:raylib"

AUDIO_BUFFER_TYPE     :: f32
OUTPUT_CHANNELS   	  :: 2
SAMPLE_RATE    		  :: 48000
PREFERRED_BUFFER_SIZE :: 512
OUTPUT_BUFFER_SIZE    :: SAMPLE_RATE * size_of(f32) * OUTPUT_CHANNELS

// Visualization constants
WAVE_PLOT_WIDTH  :: 600
WAVE_PLOT_HEIGHT :: 150
WAVE_PLOT_X      :: 100
WAVE_PLOT_Y      :: 450
WAVE_SAMPLES     :: 400

App :: struct {
	buffer_size:   int,
	ring_buffer:   Buffer,
	device:        ma.device,
	mutex:         sync.Mutex,
	sema:          sync.Sema,
	hz:            f32,
	time:          f32,
	key_pressed:   string,
	// Visualization data
	wave_samples:  [WAVE_SAMPLES]f32,
	sample_index:  int,
}

app: App

main :: proc() {
	rl.InitWindow(800, 650, "Sine Wave Generator with Visualization")
	rl.SetTargetFPS(60)

	fmt.println("Init audio buffer")
	result: ma.result

	// set audio device settings
	device_config := ma.device_config_init(ma.device_type.playback)
	device_config.playback.format    = ma.format.f32
	device_config.playback.channels  = OUTPUT_CHANNELS
	device_config.sampleRate         = SAMPLE_RATE
	device_config.dataCallback       = ma.device_data_proc(audio_callback)
	device_config.periodSizeInFrames = PREFERRED_BUFFER_SIZE

	if (ma.device_init(nil, &device_config, &app.device) != .SUCCESS) {
		fmt.println("Failed to open playback device.")
		return
	}
	// get audio device info just so we can get thre real device buffer size
	info: ma.device_info
	ma.device_get_info(&app.device, ma.device_type.playback, &info)
	app.buffer_size = int(app.device.playback.internalPeriodSizeInFrames)

	// initialize ring buffer to be 8 times the size of the audio device buffer...
	buffer_init(&app.ring_buffer, app.buffer_size * OUTPUT_CHANNELS * 8)

	// starts the audio device and the audio callback thread
	fmt.println("Starting MiniAudio Device:", runtime.cstring_to_string(cstring(&info.name[0])))
	if (ma.device_start(&app.device) != .SUCCESS) {
		fmt.println("Failed to start playback device.")
		ma.device_uninit(&app.device)
		return
	}
	// start separate thread for generating audio samples
	// pass in a pointer to "app" as the data
	thread.run_with_data(&app, sample_generator_thread_proc)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.DrawText("Press Key:", 200, 150, 60, rl.WHITE)
		rl.DrawText(rl.TextFormat("Freq: %4v", app.hz), 200, 210, 60, rl.WHITE)

		// 				KEYS
		//     | s | d |    | g | h | j |
		//   | z | x | c | v | b | n | m |

		notes         := []f32 { 60,61,62,63,64,65,66,67,68,69,70,71 }
		keyboard_keys := []rl.KeyboardKey {.Z,.S,.X,.D,.C,.V,.G,.B,.H,.N,.J,.M}
		key_names     := []cstring { "Z","S","X","D","C","V","G","B","H","N","J","M" }
		offsets       := [][2]i32{ {200,350}, {230,290}, {260,350}, {290,290}, {320,350}, {380,350}, {410,290}, {440,350}, {470,290}, {500,350}, {530,290}, {560,350} }

		get_key_color :: proc(k:string) -> rl.Color {
			if app.key_pressed == k do return rl.WHITE
			return rl.GRAY
		}
		for key, ki in keyboard_keys {
			key_name := string(key_names[ki])
			// draw keyboard
			rl.DrawText(key_names[ki], offsets[ki].x, offsets[ki].y, 60, get_key_color(key_name))
			
			// get note frequency from key presses
			if rl.IsKeyPressed(key) {
				app.hz = calc_freq_from_midi_note(notes[ki])
				app.key_pressed = key_name
			}
		}

		// Draw waveform visualization
		draw_waveform()
	}
  	audio_quit()
}

draw_waveform :: proc() {
	// Draw plot background
	rl.DrawRectangleLines(WAVE_PLOT_X - 5, WAVE_PLOT_Y - 5, WAVE_PLOT_WIDTH + 10, WAVE_PLOT_HEIGHT + 10, rl.DARKGRAY)
	
	// Draw center line
	center_y:i32 = WAVE_PLOT_Y + WAVE_PLOT_HEIGHT / 2
	rl.DrawLine(WAVE_PLOT_X, center_y, WAVE_PLOT_X + WAVE_PLOT_WIDTH, center_y, rl.DARKGRAY)
	
	// Draw waveform
	if app.hz > 0 {
		sync.lock(&app.mutex)
		for i in 0..<WAVE_SAMPLES-1 {
			x1 := WAVE_PLOT_X + i32(i * WAVE_PLOT_WIDTH / WAVE_SAMPLES)
			x2 := WAVE_PLOT_X + i32((i+1) * WAVE_PLOT_WIDTH / WAVE_SAMPLES)
			
			// Scale amplitude to fit in plot area
			y1 := center_y - i32(app.wave_samples[i] * f32(WAVE_PLOT_HEIGHT) / 2.5)
			y2 := center_y - i32(app.wave_samples[i+1] * f32(WAVE_PLOT_HEIGHT) / 2.5)
			
			rl.DrawLine(x1, y1, x2, y2, rl.GREEN)
		}
		sync.unlock(&app.mutex)
	}
	
	// Draw labels
	rl.DrawText("Waveform", WAVE_PLOT_X, WAVE_PLOT_Y - 25, 20, rl.WHITE)
}

calc_freq_from_midi_note :: proc(note:f32) -> f32 {
	note := note - 9
	hz := 27.5 * math.pow(2, (note / 12))
	fmt.println("New frequency:", hz)
	return hz
}

audio_quit :: proc() {
	ma.device_stop(&app.device)	
	ma.device_uninit(&app.device)
}

audio_callback :: proc(device: ^ma.device, output, input: rawptr, frame_count: u32) {
	buffer_size := int(frame_count*OUTPUT_CHANNELS)
	device_buffer := mem.slice_ptr((^f32)(output), buffer_size) // get device buffer

	// if there are enough samples written to the ring buffer to fill the device buffer, read them
	if app.ring_buffer.written > buffer_size {
		sync.lock(&app.mutex)
		buffer_read(device_buffer, &app.ring_buffer, true)		
		sync.unlock(&app.mutex)
	}
	// if the ring buffer is at least half empty, tell the sampler generator to start up again
	if app.ring_buffer.written < len(app.ring_buffer.data)/2 do sync.sema_post(&app.sema)
}

sample_generator_thread_proc :: proc(data:rawptr) {
	// cast the "data" we passed into the thread to ^App
	a := (^App)(data)
	// loop infinitely in this new thread
	for {
		// we only want write new samples if there is enough "free" space in the ring buffer
		// so stall the thread if we've filled over half the buffer
		// and wait until the audio callback calls sema_post()
		for a.ring_buffer.written > len(app.ring_buffer.data)/2 do sync.sema_wait(&a.sema)

		sync.lock(&a.mutex)
		for i in 0..<a.buffer_size {
			// generate sample from note frequency
			sample := math.sin(f32(math.PI) * 2 * a.hz * a.time)
			
			// Store sample for visualization (downsample for display)
			if i % (a.buffer_size / WAVE_SAMPLES) == 0 && a.sample_index < WAVE_SAMPLES {
				a.wave_samples[a.sample_index] = sample
				a.sample_index = (a.sample_index + 1) % WAVE_SAMPLES
			}
			
			// write two samples, one for each channel
			buffer_write_sample(&a.ring_buffer, sample, true)
			buffer_write_sample(&a.ring_buffer, sample, true)
			// advance time
			a.time += 1/f32(SAMPLE_RATE)
		}
		sync.unlock(&a.mutex)
	}
}

// simple ring buffer
Buffer :: struct {
	data:       []f32,
	written:    int,
	write_pos:  int,
	read_pos:   int,
}

buffer_init :: proc(b:^Buffer, size:int) {
	b.data = make([]f32, size)
}

// this writes a single sample of data to the buffer, overwriting what was previously there
buffer_write_sample :: proc(b:^Buffer, sample:f32, advance_pos:bool) {
	buffer_write_slice(b, {sample}, advance_pos)
}

// this writes a slice data to the buffer, overwriting what was previously there
buffer_write_slice :: proc(b:^Buffer, data:[]f32, advance_pos:bool) {
	assert(len(b.data) - b.written > len(data))
	write_pos := b.write_pos
	for di in 0..<len(data) {
		write_pos += 1
		if write_pos >= len(b.data) do write_pos = 0
		b.data[write_pos] = data[di]
	}
	if advance_pos {
		b.written += len(data)
		b.write_pos = write_pos
	}
}

// this reads data from the buffer and copies it into the dst slice
buffer_read :: proc(dst:[]f32, b:^Buffer, advance_index:bool=true) {
	read_pos := b.read_pos
	for di in 0..<len(dst) {
		read_pos += 1
		if read_pos >= len(b.data) do read_pos = 0
		dst[di] = b.data[read_pos]
		b.data[read_pos] = 0
	}
	if advance_index {
		b.written -= len(dst)
		b.read_pos = read_pos
	}
}