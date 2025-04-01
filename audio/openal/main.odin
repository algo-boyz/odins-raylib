package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"
import "al"
import rl "vendor:raylib"
import "../../rlutil/fft"

SAMPLE_RATE :: 10000
BUFFER_SIZE :: 256  // Number of samples

AL :: struct {
    amplitude:       int,
    avg_mode:        int,
    avg_size:        int,
    decay:           int,
    filter_constant: f32,

    fft:             [BUFFER_SIZE]f32,
    fft_nrml:        [BUFFER_SIZE]f32,
    fft_fltr:        [BUFFER_SIZE]f32,

    device:          al.Device,
    device_idx:      int,

    devices:         []string,
    devices_size:    int,

    gui:             bool,
}

min_int :: proc(x, y: int) -> int {
    if x > y {
        return y
    }
    return x
}

max_int :: proc(x, y: int) -> int {
    if x < y {
        return y
    }
    return x
}

init_devices :: proc(a: ^AL) {
    // Get list of audio capture devices
    devices_str := al.get_string(nil, al.CAPTURE_DEVICE_SPECIFIER)
    if devices_str == nil {
        fmt.println("No capture devices found")
        return
    }
    // Parse device list (null-separated string)
    devices_list := strings.split(string(cstring(devices_str)), "\x00")
    // Remove last empty entry (due to double null termination)
    if len(devices_list) > 0 && devices_list[len(devices_list)-1] == "" {
        devices_list = devices_list[:len(devices_list)-1]
    }
    a.devices = devices_list
    a.devices_size = len(devices_list)
}

list_devices :: proc(a: ^AL) {
    for i := 0; i < a.devices_size; i += 1 {
        fmt.printf("%d: %s\n", i, a.devices[i])
    }
}

init_device :: proc(a: ^AL) {
    if a.device_idx >= a.devices_size {
        fmt.println("Invalid device index")
        return
    }
    device_name := strings.clone_to_cstring(a.devices[a.device_idx])
    defer delete(device_name)

    a.device = al.capture_open_device(
        cast(^u8)device_name,
        SAMPLE_RATE,
        al.FORMAT_MONO8,
        BUFFER_SIZE
    )
    if a.device == nil {
        fmt.println("Failed to open capture device")
        return
    }
    al.capture_start(a.device)
}

set_normalization :: proc(a: ^AL, offset, scale: f32) {
    for i := 0; i < BUFFER_SIZE; i += 1 {
        a.fft[i] = 0.0
        a.fft_nrml[i] = offset + (scale * (f32(i) / f32(BUFFER_SIZE)))
    }
}

get_alc_error_string :: proc(err: i32) -> string {
    switch err {
    case al.NO_ERROR: return "NO_ERROR"
    case al.INVALID_DEVICE: return "INVALID_DEVICE"
    case al.INVALID_CONTEXT: return "INVALID_CONTEXT"
    case al.INVALID_ENUM: return "INVALID_ENUM"
    case al.INVALID_VALUE: return "INVALID_VALUE"
    case al.OUT_OF_MEMORY: return "OUT_OF_MEMORY"
    case: return fmt.tprintf("Unknown ALC Error (%d)", err)
    }
}

// Apply FFT to captured audio samples
apply_fft :: proc(a: ^AL, sample_buf: []u8) {
    // Check if raw buffer has non-constant values (e.g., not all 128)
    // fmt.printf("apply_fft Input Check: buf[0]=%v, buf[%d]=%v, buf[%d]=%v\n",
    // sample_buf[0], BUFFER_SIZE/2, sample_buf[BUFFER_SIZE/2], BUFFER_SIZE-1, sample_buf[BUFFER_SIZE-1])

    fft_tmp := make([]f32, BUFFER_SIZE * 2)
    defer delete(fft_tmp)

    for i := 0; i < BUFFER_SIZE; i += 1 {
        // Clear buffers
        fft_tmp[i] = 0
        // Decay prev values
        a.fft[i] *= f32(a.decay) / 100.0
    }
    for i := 0; i < BUFFER_SIZE * 2; i += 1 {
        if i/2 < len(sample_buf) {
            fft_tmp[i] = (f32(sample_buf[i/2]) - (f32(BUFFER_SIZE)/2.0)) * 
                        (f32(a.amplitude) / (f32(BUFFER_SIZE)/2.0))
        }
    }
    // Run the FFT calculation
    fft.rfft(fft_tmp, true)
    fft_tmp[0] = fft_tmp[2]
    fft.apply_window(fft_tmp[:BUFFER_SIZE], a.fft_nrml[:])

    // Compute FFT magnitude
    for i := 0; i < BUFFER_SIZE/2; i += 2 {
        // Compute magnitude from real and imaginary components of FFT
        fftmag := f32(math.sqrt(f64(fft_tmp[i] * fft_tmp[i] + 
                                 fft_tmp[i+1] * fft_tmp[i+1])))
        // Apply slight log filter to minimize noise from low freqs
        fftmag = (0.5 * f32(math.log10(f64(1.1 * fftmag)))) + (0.9 * fftmag)
        // Limit magnitude
        if fftmag > 1.0 {
            fftmag = 1.0
        }
        // Update new values only if greater than previous
        if fftmag > a.fft[i*2] {
            a.fft[i*2] = fftmag
        }
        // Prevent negative values
        if a.fft[i*2] < 0.0 {
            a.fft[i*2] = 0.0
        }
        // Set odd indexes to match their corresponding even index
        a.fft[(i*2)+1] = a.fft[i*2]
        a.fft[(i*2)+2] = a.fft[i*2]
        a.fft[(i*2)+3] = a.fft[i*2]
    }

    if a.avg_mode == 0 {
        // Apply averaging over given number of values
        sum1 := f32(0)
        sum2 := f32(0)
        k := 0
        for k = 0; k < a.avg_size; k += 1 {
            sum1 += a.fft[k]
            sum2 += a.fft[BUFFER_SIZE-1-k]
        }
        // Compute averages for end bars
        sum1 /= f32(k)
        sum2 /= f32(k)
        for k = 0; k < a.avg_size; k += 1 {
            a.fft[k] = sum1
            a.fft[BUFFER_SIZE-1-k] = sum2
        }
        for i := 0; i < (BUFFER_SIZE - a.avg_size); i += a.avg_size {
            sum := f32(0)
            for j := 0; j < a.avg_size; j += 1 {
                sum += a.fft[i+j]
            }
            avg := sum / f32(a.avg_size)
            for j := 0; j < a.avg_size; j += 1 {
                a.fft[i+j] = avg
            }
        }
    } else if a.avg_mode == 1 {
        for i := 0; i < a.avg_size; i += 1 {
            sum1 := f32(0)
            sum2 := f32(0)
            j := 0
            for j = 0; j <= i + a.avg_size; j += 1 {
                sum1 += a.fft[j]
                sum2 += a.fft[BUFFER_SIZE-1-j]
            }
            a.fft[i] = sum1 / f32(j)
            a.fft[BUFFER_SIZE-1-i] = sum2 / f32(j)
        }
        
        for i := a.avg_size; i < BUFFER_SIZE-1-a.avg_size; i += 1 {
            sum := f32(0)
            for j := 1; j <= a.avg_size; j += 1 {
                sum += a.fft[i-j]
                sum += a.fft[i+j]
            }
            sum += a.fft[i]
            a.fft[i] = sum / f32(2 * a.avg_size + 1)
        }
    }
    for i := 0; i < BUFFER_SIZE; i += 1 {
        a.fft_fltr[i] = a.fft_fltr[i] + (a.filter_constant * (a.fft[i] - a.fft_fltr[i]))
    }
}

update :: proc(a: ^AL) {
    samples: i32 = 0
    // You can keep the timeout for safety, or remove it if confident.
    max_wait_iterations := 5000
    iterations := 0

    // --- MODIFY THE LOOP CONDITION ---
    // Wait until samples are at least BUFFER_SIZE - 1 (i.e., 255)
    for samples < (BUFFER_SIZE - 1) && iterations < max_wait_iterations {
    // --- END MODIFICATION ---
        al.get_integerv(a.device, al.CAPTURE_SAMPLES, 1, &samples)
        // Optional: Keep minimal logging if needed during testing
        // if iterations % 100 == 0 {
        //     fmt.printf("Update: samples available = %d (waiting for %d)\n", samples, BUFFER_SIZE - 1)
        // }
        time.sleep(1 * time.Millisecond)
        iterations += 1
    }

    // --- Optional: Adjust post-loop checks if you keep them ---
    if iterations >= max_wait_iterations {
        fmt.println("Update: Timed out waiting for sufficient samples (>= 255).")
        return // Still return if timeout occurs
    }
    // Ensure samples actually reached the threshold (should be true if no timeout)
    if samples < (BUFFER_SIZE - 1) {
         fmt.printf("Update: Loop exited but samples (%d) < required (%d). Not capturing.\n", samples, BUFFER_SIZE - 1)
         return
    }
    // fmt.printf("Update: Got %d samples. Proceeding to capture.\n", samples) // Optional log


    sample_buf := make([]u8, BUFFER_SIZE)
    defer delete(sample_buf)

    // --- IMPORTANT: Still request the full BUFFER_SIZE (256) ---
    // Even though we waited for 255, request 256. OpenAL might:
    // a) Block briefly until the 256th sample is ready.
    // b) Provide the 256 samples immediately if they became ready just after the check.
    al.capture_samples(a.device, raw_data(sample_buf), BUFFER_SIZE)
    // fmt.println("Update: Samples captured.") // Optional

    apply_fft(a, sample_buf)
    // fmt.println("Update: FFT applied.") // Optional
}

draw_visualizer :: proc(a: ^AL) {
    w := rl.GetScreenWidth()
    h := rl.GetScreenHeight()
    color := rl.Color{200, 50, 50, 255}
    bin_width := f32(w) / f32(BUFFER_SIZE)

    for i := 0; i < BUFFER_SIZE; i += 1 {
        start_x := i32(f32(i) * bin_width)
        fft_val := a.fft[i] // Get value once
        end_y := i32(f32(h) - (f32(h) * fft_val)) // Top of the bar

        // Clamp end_y to prevent drawing outside vertically? (Optional but good practice)
        // if end_y < 0 { end_y = 0 }
        // if end_y > h { end_y = h } // Should not happen if fft_val >= 0

        rect_height := i32(h) - end_y // Calculate height based on clamped end_y

        // Clamp height (just in case)
        // if rect_height < 0 { rect_height = 0 }

        // Calculate width (original logic seems okay)
        next_bin_x := i32(f32(i + 1) * bin_width)
        bin_end := i32(f32(start_x) + bin_width)
        rect_width: i32
        if bin_end != next_bin_x {
            rect_width = i32(bin_width) + (next_bin_x - bin_end)
        } else {
            rect_width = i32(bin_width)
        }
        // Ensure width is at least 1? (Optional)
        // if rect_width < 1 { rect_width = 1 }


        // --- ADD LOGGING for first and middle bar ---
        if i == 0 || i == BUFFER_SIZE / 2 {
            fmt.printf("Bar %d: fft=%v, x=%d, y=%d, w=%d, h=%d\n", i, fft_val, start_x, end_y, rect_width, rect_height)
        }
        // --- END LOGGING ---

        // Draw using calculated values
        rl.DrawRectangle(start_x, end_y, rect_width, rect_height, color)
    }
}

main :: proc() {
    // Initialize our application state
    a := AL{
        amplitude = 5000,
        avg_mode = 1,
        avg_size = 8,
        filter_constant = 1.0,
        decay = 80,
        // --- CHANGE THIS LINE ---
        device_idx = 0, // Use index 0 for the first available device
        // --- END CHANGE ---
        gui = true,
    }

    // Initialize audio device list
    init_devices(&a)
    if a.devices_size == 0 {
        fmt.println("No devices found")
        return
    }

    list_devices(&a) // Will print "0: MacBook Pro Microphone"

    // Initialize the selected audio device (now using index 0)
    init_device(&a)
    if a.device == nil {
        fmt.println("Could not initialize device capture")
        return
    }
    // This should now correctly print the device name
    fmt.printf("Using device: %s\n", a.devices[a.device_idx])

    // Set up FFT normalization
    nrml_ofst := f32(0.04)
    nrml_scl := f32(0.5)
    set_normalization(&a, nrml_ofst, nrml_scl)

    // Initialize Raylib window if GUI is enabled
    if a.gui {
        rl.SetConfigFlags({.WINDOW_RESIZABLE})
        rl.InitWindow(500, 400, "FFT Visualizer")
        rl.SetTargetFPS(144)
    }

    // Main loop
    for !rl.WindowShouldClose() {
        update(&a)

        if !a.gui {
            continue
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{20, 20, 20, 255})

        draw_visualizer(&a)

        rl.EndDrawing()
    }

    // Cleanup
    al.capture_stop(a.device)
    al.capture_close_device(a.device)
    rl.CloseWindow()
}