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

normalize :: proc(a: ^AL, offset, scale: f32) {
    for i := 0; i < BUFFER_SIZE; i += 1 {
        a.fft[i] = 0.0
        a.fft_nrml[i] = offset + (scale * (f32(i) / f32(BUFFER_SIZE)))
    }
}

get_alc_err :: proc(err: i32) -> string {
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
    // Run the FFT calc
    fft.rfft(fft_tmp, true)
    fft_tmp[0] = fft_tmp[2]
    fft.apply_window(fft_tmp[:BUFFER_SIZE], a.fft_nrml[:])

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
        // Update new values only if greater than prev
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
        // Compute averages of bars
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
    max_wait_iterations := 5000
    iterations := 0

    for samples < (BUFFER_SIZE - 1) && iterations < max_wait_iterations {
        al.get_integerv(a.device, al.CAPTURE_SAMPLES, 1, &samples)
        time.sleep(1 * time.Millisecond)
        iterations += 1
    }

    if iterations >= max_wait_iterations {
        fmt.println("Update: Timed out waiting for sufficient samples.")
        return
    }
    if samples < (BUFFER_SIZE - 1) {
         fmt.printf("Update: Loop exited but samples (%d) < required (%d). Not capturing.\n", samples, BUFFER_SIZE - 1)
         return
    }
    // fmt.printf("Update: Got %d samples. Proceeding to capture.\n", samples)
    sample_buf := make([]u8, BUFFER_SIZE)
    defer delete(sample_buf)

    al.capture_samples(a.device, raw_data(sample_buf), BUFFER_SIZE)
    apply_fft(a, sample_buf)
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
        rect_height := i32(h) - end_y

        next_bin_x := i32(f32(i + 1) * bin_width)
        bin_end := i32(f32(start_x) + bin_width)
        rect_width: i32
        if bin_end != next_bin_x {
            rect_width = i32(bin_width) + (next_bin_x - bin_end)
        } else {
            rect_width = i32(bin_width)
        }
        // if i == 0 || i == BUFFER_SIZE / 2 {
        //     fmt.printf("Bar %d: fft=%v, x=%d, y=%d, w=%d, h=%d\n", i, fft_val, start_x, end_y, rect_width, rect_height)
        // }
        rl.DrawRectangle(start_x, end_y, rect_width, rect_height, color)
    }
}

main :: proc() {
    a := AL{
        amplitude = 5000,
        avg_mode = 1,
        avg_size = 8,
        filter_constant = 1.0,
        decay = 80,
        device_idx = 0,
    }
    init_devices(&a)
    if a.devices_size == 0 {
        fmt.println("No devices found")
        return
    }
    list_devices(&a)
    init_device(&a)
    if a.device == nil {
        fmt.println("Could not initialize device capture")
        return
    }
    fmt.printf("Using device: %s\n", a.devices[a.device_idx])

    // Set up FFT normalization
    nrml_ofst := f32(0.04)
    nrml_scl := f32(0.5)
    normalize(&a, nrml_ofst, nrml_scl)

    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(500, 400, "FFT Visualizer")
    rl.SetTargetFPS(144)

    for !rl.WindowShouldClose() {
        update(&a)

        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{20, 20, 20, 255})

        draw_visualizer(&a)

        rl.EndDrawing()
    }
    al.capture_stop(a.device)
    al.capture_close_device(a.device)
    rl.CloseWindow()
}