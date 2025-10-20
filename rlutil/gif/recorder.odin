package gif

import "core:c"
import "core:c/libc"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"
import "core:time"
import "core:os"
import rl "vendor:raylib"
import "giflib"

MAX_RECORDING_FRAMES :: 1800 // 30 seconds at 60fps
DEFAULT_RECORDING_FPS :: 12

RecordingState :: enum {
	Idle,
	Recording,
	Processing,
	Error,
}

Color :: struct {
	r, g, b: u8,
}

Recorder :: struct {
	captured_frames: [dynamic]rl.Image,
	fps,
	max_frames,
	skipped_frames,
	skip_ratio,
	frame_width,
	frame_height,
	frame_counter: int, // Skip every N frames to reach target FPS
	state:         RecordingState,
	start_time:    time.Time,
	output_path:   string,

}

// Create a new GIF recorder instance
new_recorder :: proc(output_path: string, target_fps: int = DEFAULT_RECORDING_FPS, max_frames: int = MAX_RECORDING_FRAMES) -> Recorder {
	recorder := Recorder{
		captured_frames = make([dynamic]rl.Image, 0, max_frames),
		fps      = target_fps,
		max_frames      = max_frames,
		output_path     = output_path,
		state           = .Idle,
		frame_width     = int(rl.GetScreenWidth()),
		frame_height    = int(rl.GetScreenHeight()),
	}
	// Calculate skip ratio based on target FPS
	screen_fps := rl.GetFPS()
	if screen_fps > 0 {
		recorder.skip_ratio = max(1, int(screen_fps) / target_fps)
	} else {
		recorder.skip_ratio = 60 / target_fps // Default
	}
	return recorder
}

// Start screen recording
recorder_start :: proc(rec: ^Recorder) -> bool {
	if rec.state != .Idle {
		rl.TraceLog(.WARNING, "Recorder is already active")
		return false
	}
	// Clear prev frames
	for frame in rec.captured_frames {
		rl.UnloadImage(frame)
	}
	clear(&rec.captured_frames)
	
	rec.state = .Recording
	rec.frame_counter = 0
	rec.skipped_frames = 0
	rec.start_time = time.now()
	rec.frame_width = int(rl.GetScreenWidth())
	rec.frame_height = int(rl.GetScreenHeight())

	rl.TraceLog(.INFO, "Started GIF recording: %dx%d @ %d fps",
		rec.frame_width, rec.frame_height, rec.fps)
	return true
}

recorder_handle_input :: proc(rec: ^Recorder) {
	// Start recording on SPACE key
	if rl.IsKeyPressed(.SPACE) && !is_recording(rec) {
		recorder_start(rec)
	}
	// Stop recording on ENTER key
	if rl.IsKeyPressed(.ENTER) && is_recording(rec) {
		recorder_stop(rec)
		recorder_giflib_save(rec) // Save the GIF
	}
}

// Update the recorder (call this every frame in your main loop)
recorder_update :: proc(rec: ^Recorder) {
	recorder_handle_input(rec)
	if rec.state != .Recording {
		return
	}
	// Check if frame should be skipped
	if rec.skipped_frames < rec.skip_ratio - 1 {
		rec.skipped_frames += 1
		return
	}
	rec.skipped_frames = 0
	
	// Check if we've reached max frames
	if len(rec.captured_frames) >= rec.max_frames {
		rl.TraceLog(.WARNING, "Maximum recording frames reached, stopping recording")
		recorder_stop(rec)
		return
	}
	// Capture the current frame
	img := rl.LoadImageFromScreen()
	if img.data != nil {
		append(&rec.captured_frames, img)
		rec.frame_counter += 1
	} else {
		rl.TraceLog(.WARNING, "Failed to capture screen frame")
	}
}

// Stop recording
recorder_stop :: proc(rec: ^Recorder) {
	if rec.state != .Recording {
		return
	}
	rec.state = .Processing
	duration := time.since(rec.start_time)
	
	rl.TraceLog(.INFO, "Recording stopped. Captured %d frames in %.2f seconds", 
		len(rec.captured_frames), time.duration_seconds(duration))
}

// Save the recorded frames as a GIF
recorder_save :: proc(rec: ^Recorder) -> bool {
	if rec.state != .Processing || len(rec.captured_frames) == 0 {
		rl.TraceLog(.WARNING, "No frames to save or recorder not in processing state")
		return false
	}
	rl.TraceLog(.INFO, "Saving GIF with %d frames to '%s'", len(rec.captured_frames), rec.output_path)
	// Save each frame as a PNG file in directory
	for frame, i in rec.captured_frames {
		frame_filename := fmt.tprintf("frame_%04d.png", i)
		frame_path := strings.clone_to_cstring(frame_filename)
		defer delete(frame_path)
		
		success := rl.ExportImage(frame, frame_path)
		if !success {
			rl.TraceLog(.ERROR, "Failed to save frame %d", i)
			rec.state = .Error
			return false
		}
	}
	rec.state = .Idle
	rl.TraceLog(.INFO, "Saved %d frames as PNG files", len(rec.captured_frames))
	return true
}

ColorPair :: struct{color: Color, count: int}

// Generate an optimized color palette from all frames using median cut algorithm
generate_color_palette :: proc(frames: []rl.Image, max_colors: int = 256) -> []Color {
	// Collect all unique colors from all frames
	color_counts := make(map[Color]int)
	defer delete(color_counts)
	
	for frame in frames {
		// Convert to RGBA if not already in that format
		rgba_frame := frame
		needs_conversion := frame.format != rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
		if needs_conversion {
			rgba_frame = rl.ImageCopy(frame)
			rl.ImageFormat(&rgba_frame, .UNCOMPRESSED_R8G8B8A8)
		}
		defer if needs_conversion do rl.UnloadImage(rgba_frame)
		
		rgba_data := cast([^]u8)rgba_frame.data
		pixel_count := rgba_frame.width * rgba_frame.height
		
		for i in 0..<pixel_count {
			pixel_idx := i * 4  // RGBA = 4 bytes per pixel
			color := Color{
				r = rgba_data[pixel_idx],
				g = rgba_data[pixel_idx + 1],
				b = rgba_data[pixel_idx + 2],
			}
			color_counts[color] += 1
		}
	}
	rl.TraceLog(.INFO, "Found %d unique colors", len(color_counts))
	
	// Convert map to slice for processing
	unique_colors := make([dynamic]Color)
	defer delete(unique_colors)
	
	for color in color_counts {
		append(&unique_colors, color)
	}
	// GIF requires at least 2 colors - add black and white if we have too few
	if len(unique_colors) == 0 {
		rl.TraceLog(.WARNING, "No colors found, using default black/white palette")
		result := make([]Color, 2)
		result[0] = Color{}
		result[1] = Color{255, 255, 255}
		return result
	} else if len(unique_colors) == 1 {
		rl.TraceLog(.WARNING, "Only 1 color found, adding white as second color")
		result := make([]Color, 2)
		result[0] = unique_colors[0]
		result[1] = Color{255, 255, 255}  // Add white as second color
		return result
	}
	// If we have fewer colors than max_colors, return all of them
	if len(unique_colors) <= max_colors {
		result := make([]Color, len(unique_colors))
		copy(result, unique_colors[:])
		return result
	}
	// Use a simple color quantization approach - take the most frequent colors
	color_freq_pairs := make([dynamic]ColorPair)
	defer delete(color_freq_pairs)
	
	for color, count in color_counts {
		append(&color_freq_pairs, ColorPair{color = color, count = count})
	}
	// Sort by count (descending)
	slice.sort_by(color_freq_pairs[:], proc(a, b: ColorPair) -> bool {
		return a.count > b.count
	})
	// Take the top max_colors
	result := make([]Color, min(max_colors, len(color_freq_pairs)))
	for i in 0..<len(result) {
		result[i] = color_freq_pairs[i].color
	}
	return result
}

// Find the closest color in the palette for a given color
find_closest_color :: proc(target: Color, palette: []Color) -> u8 {
	if len(palette) == 0 {
		return 0
	}
	min_dist := f32(math.INF_F32)
	closest_index := 0
	
	for color, i in palette {
		// Calculate Euclidean distance in RGB space
		dr := f32(target.r) - f32(color.r)
		dg := f32(target.g) - f32(color.g)
		db := f32(target.b) - f32(color.b)
		distance := dr*dr + dg*dg + db*db
		if distance < min_dist {
			min_dist = distance
			closest_index = i
		}
	}
	return u8(closest_index)
}

// Use libgif library to save the recorded frames as one GIF with color palette
recorder_giflib_save :: proc(rec: ^Recorder) -> bool {
	if rec.state != .Processing || len(rec.captured_frames) == 0 {
		rl.TraceLog(.WARNING, "No frames to save or recorder not in processing state")
		return false
	}
	rl.TraceLog(.INFO, "Saving GIF with %d frames to '%s'", len(rec.captured_frames), rec.output_path)

	// Generate optimal color palette from all frames
	rl.TraceLog(.INFO, "Generating color palette...")
	palette := generate_color_palette(rec.captured_frames[:], 256)
	defer delete(palette)
	rl.TraceLog(.INFO, "Generated palette with %d colors", len(palette))

	// Ensure we have at least 2 colors for GIF
	if len(palette) < 2 {
		rl.TraceLog(.ERROR, "Palette must have at least 2 colors, got %d", len(palette))
		rec.state = .Error
		return false
	}

	// Init encoder
	err: c.int
	encoder := giflib.EGifOpenFileName(fmt.ctprint(rec.output_path), false, &err)
	if encoder == nil {
		rl.TraceLog(.ERROR, "Failed to create GIF encoder: %s", giflib.err_msg(err))
		rec.state = .Error
		return false
	}
	defer {
		close_err: c.int
		result := giflib.EGifCloseFile(encoder, &close_err)
		
		// Only log actual errors (non-success error codes)
		if result != giflib.OK && close_err != giflib.E_GIF_SUCCESS {
			err_msg := giflib.err_msg(close_err)
			if err_msg != "" && len(err_msg) > 0 {
				rl.TraceLog(.ERROR, "Failed to close GIF file: %s", err_msg)
			} else {
				rl.TraceLog(.ERROR, "Failed to close GIF file: error code %d", close_err)
			}
		}
	}
	// Get dimensions from first frame
	width := rec.captured_frames[0].width
	height := rec.captured_frames[0].height
	
	// Round up to nearest power of 2 for GIF color map (GIF requirement)
	color_count := len(palette)
	gif_color_count := 2
	for gif_color_count < color_count {
		gif_color_count *= 2
	}
	gif_color_count = min(gif_color_count, 256)
	
	// Create color map from our generated palette
	color_map := giflib.GifMakeMapObject(c.int(gif_color_count), nil)
	if color_map == nil {
		rl.TraceLog(.ERROR, "Failed to create color map with %d colors", gif_color_count)
		rec.state = .Error
		return false
	}
	defer giflib.GifFreeMapObject(color_map)

	// Fill the color map with our palette
	for color, i in palette {
		if i < gif_color_count {
			color_map.colors[i] = giflib.ColorType{
				r = giflib.ByteType(color.r),
				g = giflib.ByteType(color.g), 
				b = giflib.ByteType(color.b),
			}
		}
	}
	
	// Fill remaining slots with black
	for i in len(palette)..<gif_color_count {
		color_map.colors[i] = giflib.ColorType{r = 0, g = 0, b = 0}
	}
	
	// Set up the GIF file header
	encoder.width = giflib.Word(width)
	encoder.height = giflib.Word(height)
	encoder.resolution = 8  // 8 bits per pixel
	encoder.background = 0
	encoder.aspect_byte = 0
	encoder.color_map = color_map

	// Calculate frame delay in centiseconds (GIF uses 1/100th second units)
	frame_delay_cs := max(1, 100 / rec.fps)

	// Allocate memory for all saved images at once
	encoder.image_count = c.int(len(rec.captured_frames))
	saved_images_size := c.size_t(len(rec.captured_frames)) * size_of(giflib.SavedImage)
	encoder.saved_images = cast([^]giflib.SavedImage)libc.malloc(saved_images_size)
	if encoder.saved_images == nil {
		rl.TraceLog(.ERROR, "Failed to allocate memory for saved images")
		rec.state = .Error
		return false
	}
	defer libc.free(encoder.saved_images)

	// Add application extension for looping (only for the first frame)
	first_frame_extensions := make([]giflib.ExtensionBlock, 2)
	defer delete(first_frame_extensions)
	
	// NETSCAPE 2.0 application identifier
	first_frame_extensions[0] = giflib.ExtensionBlock{
		byte_count = 11,
		bytes = raw_data([]u8{'N','E','T','S','C','A','P','E','2','.','0'}),
		func = giflib.APPLICATION_EXT,
	}
	// Loop count data (0 = infinite loop)
	loop_data := [3]u8{1, 0, 0}
	first_frame_extensions[1] = giflib.ExtensionBlock{
		byte_count = 3,
		bytes = raw_data(loop_data[:]),
		func = 0, // Continuation block
	}
	
	// Process each frame
	for frame, frame_idx in rec.captured_frames {
		// Convert to RGBA if needed (same as in palette generation)
		rgba_frame := frame
		needs_conversion := frame.format != rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
		if needs_conversion {
			rgba_frame = rl.ImageCopy(frame)
			rl.ImageFormat(&rgba_frame, .UNCOMPRESSED_R8G8B8A8)
		}
		defer if needs_conversion do rl.UnloadImage(rgba_frame)
		
		// Convert RGBA image to indexed color using our palette
		indexed_data := make([]u8, width * height)
		// Note: We don't defer delete here because we need this data to persist
		// until the GIF is written. It will be cleaned when the app exits.
		
		rgba_data := cast([^]u8)rgba_frame.data
		for y in 0..<height {
			for x in 0..<width {
				pixel_idx := (y * width + x) * 4  // RGBA = 4 bytes per pixel
				color := Color{
					r = rgba_data[pixel_idx],
					g = rgba_data[pixel_idx + 1],
					b = rgba_data[pixel_idx + 2],
				}
				// Find closest color in palette
				palette_index := find_closest_color(color, palette)
				indexed_data[y * width + x] = palette_index
			}
		}
		
		// Create graphics control extension for frame delay
		gcb_extension := make([]giflib.ExtensionBlock, 1)
		// Note: Not deferring delete - needs to persist until GIF is written
		gcb := giflib.GraphicsControlBlock{
			disposal_mode = giflib.DISPOSE_DO_NOT,
			user_input_flag = false,
			delay_time = c.int(frame_delay_cs),
			transparent_color = giflib.NO_TRANSPARENT_COLOR,
		}
		gcb_data := make([]u8, 4)
		gcb_size := giflib.EGifGCBToExtension(&gcb, raw_data(gcb_data))
		gcb_extension[0] = giflib.ExtensionBlock{
			byte_count = c.int(gcb_size),
			bytes = raw_data(gcb_data),
			func = giflib.GRAPHICS_EXT,
		}
		
		// Set up the saved image
		saved_image := &encoder.saved_images[frame_idx]
		saved_image.image_desc = giflib.ImgDesc{
			left = 0,
			top = 0,
			width = giflib.Word(width),
			height = giflib.Word(height),
			interlace = false,
			color_map = nil, // Use global color map
		}
		saved_image.raster_bits = raw_data(indexed_data)
		
		// Set up extensions for this frame
		if frame_idx == 0 {
			// First frame gets both application extension and graphics control
			all_extensions := make([]giflib.ExtensionBlock, 3)
			all_extensions[0] = first_frame_extensions[0]
			all_extensions[1] = first_frame_extensions[1]
			all_extensions[2] = gcb_extension[0]
			saved_image.extension_block_count = 3
			saved_image.extension_blocks = raw_data(all_extensions)
		} else {
			// Other frames get only graphics control extension
			saved_image.extension_block_count = 1
			saved_image.extension_blocks = raw_data(gcb_extension)
		}
	}
	
	// Write the entire GIF using EGifSpew
	if giflib.EGifSpew(encoder) == giflib.ERR {
		rl.TraceLog(.ERROR, "Failed to write GIF file")
		rec.state = .Error
		return false
	}
	
	rec.state = .Idle
	rl.TraceLog(.INFO, "%d frames saved as color GIF with %d colors", len(rec.captured_frames), len(palette))
	return true
}

recorder_cleanup :: proc(rec: ^Recorder) {
	for frame in rec.captured_frames {
		rl.UnloadImage(frame)
	}
	delete(rec.captured_frames)
	rec.state = .Idle
}

recorder_get_state :: proc(rec: ^Recorder) -> RecordingState {
	return rec.state
}

get_frame_count :: proc(rec: ^Recorder) -> int {
	return len(rec.captured_frames)
}

is_recording :: proc(rec: ^Recorder) -> bool {
	return rec.state == .Recording
}

get_duration :: proc(rec: ^Recorder) -> f64 {
	if rec.state == .Idle {
		return 0
	}
	return time.duration_seconds(time.since(rec.start_time))
}

recorder_dbg :: proc(rec: ^Recorder) {
	if !is_recording(rec) {
		rl.DrawText(fmt.ctprintf("Captured: %d Frames", get_frame_count(rec)), 10, 40, 20, rl.RED)
	}
}