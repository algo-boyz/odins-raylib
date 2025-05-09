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

AVERAGE_TYPE :: enum {
    // groups the frequencies as avg_size blocks
    // as the amp being the avg value of the frequencies
    // in that block
    BLOCK,
    // smooths out amps as it takes the average value
    // of the neighboring frequencies amps and makes it
    // the result value of each frequency
    BOX_FILTER,
    // runs box filter twice
    DOUBLE_BOX_FILTER,
    // box filter, the only difference being that
    // more distant frequencies from each frequency
    // contribute less to the avarage
    WEIGHTED_FILTER,
    // smooths out the fft as it uses the `alpha` value
    // to control how much the neighboring (left/right)
    // frequencies contribute to the smoothing
    EXPONENTIAL_FILTER,
}

AL :: struct {
    avg_mode:        AVERAGE_TYPE,
    avg_size:        int,
    decay:           int,
    amplitude:       int,
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
    // tmp storage of fft on samples
    fft_tmp := make([]f32, BUFFER_SIZE)
    defer delete(fft_tmp)
    // since samples are u8, shifting them by 256/2 to the left
    // gets 0 when there is no sound, instead of a 128
    shift := f32(256.0 / 2)
    for i := 0; i < BUFFER_SIZE; i += 1 {
        // scale amplitude a bit for better visuals
        fft_tmp[i] = (f32(sample_buf[i]) - shift) * (f32(a.amplitude) / shift)
    }
    // run the fft
    fft.rfft(fft_tmp, true)
    // remove dc component
    fft_tmp[0] = fft_tmp[2]
    fft.apply_window(fft_tmp[:BUFFER_SIZE], a.fft_nrml[:])
    // fade out previous amps
    for i := 0; i < BUFFER_SIZE; i += 1 {
        a.fft[i] = a.fft[i] * (f32(a.decay) / 100.0)
    }
    // Compute FFT magnitude
    for i := 0; i < BUFFER_SIZE/2; i += 2 {
        // Compute magnitude from real and imaginary components of FFT and apply
        // simple LPF
        fftmag := f32(math.sqrt(f64(fft_tmp[i] * fft_tmp[i] + 
                               fft_tmp[i+1] * fft_tmp[i+1])))
        // Apply a slight logarithmic filter to minimize noise from very low
        // amplitude frequencies
        fftmag = (0.5 * f32(math.log10(f64(1.1 * fftmag)))) + (0.9 * fftmag)
        // Limit FFT magnitude to 1.0
        if fftmag > 1.0 {
            fftmag = 1.0
        }
        // Update to new values only if greater than previous values
        if fftmag > a.fft[i*2] {
            a.fft[i*2] = fftmag
        }
        // Prevent from going negative
        if a.fft[i*2] < 0.0 {
            a.fft[i*2] = 0.0
        }
        // Result fft from rfft is N/2 and
        // half of the result are imaginary numbers
        // divided into 4 bins of values that are equal
        a.fft[(i*2)+1] = a.fft[i*2]
        a.fft[(i*2)+2] = a.fft[i*2]
        a.fft[(i*2)+3] = a.fft[i*2]
    }
    // apply an averaging filter
    avg_fft(a);
}

apply_exponential_smoothing :: proc(a: ^AL, alpha: f32) {
    tmp := make([]f32, BUFFER_SIZE)
    defer delete(tmp)

    tmp[0] = a.fft[0]
    for i := 1; i < BUFFER_SIZE; i += 1 {
        tmp[i] = alpha * a.fft[i] + (1.0 - alpha) * tmp[i - 1]
    }
    a.fft[BUFFER_SIZE - 1] = tmp[BUFFER_SIZE - 1]
    for i := BUFFER_SIZE - 2; i >= 0; i -= 1 {
        a.fft[i] = alpha * tmp[i] + (1.0 - alpha) * a.fft[i + 1]
    }
}

apply_weighted_avg :: proc(a: ^AL, avg_size: int) {
    tmp := make([]f32, BUFFER_SIZE)
    defer delete(tmp)

    for i := 0; i < BUFFER_SIZE; i += 1 {
        sum := f32(0)
        weight_sum := f32(0)

        start := math.max(i - avg_size, 0)
        end := math.min(i + avg_size, BUFFER_SIZE - 1)
        for j := start; j <= end; j += 1 {
            weight := 1.0 - f32(math.abs(i - j)) / f32(avg_size)
            sum += a.fft[j] * weight
            weight_sum += weight
        }
        tmp[i] = sum / weight_sum
    }
    for i := 0; i < BUFFER_SIZE; i += 1 {
        a.fft[i] = tmp[i]
    }
}

apply_box_filter :: proc(a: ^AL, avg_size: int) {
    tmp := make([]f32, BUFFER_SIZE)
    defer delete(tmp)

    for i := 0; i < BUFFER_SIZE; i += 1 {
        sum := f32(0)
        start := math.max(i - avg_size, 0)
        end := math.min(i + avg_size, BUFFER_SIZE - 1)
        for j := start; j <= end; j += 1 {
            sum += a.fft[j]
        }
        avg := sum / f32((end - start) + 1)
        tmp[i] = avg
    }
    for i := 0; i < BUFFER_SIZE; i += 1 {
        a.fft[i] = tmp[i]
    }
}

apply_block_avg :: proc(a: ^AL, avg_size: int) {
    for i := 0; i < BUFFER_SIZE; i += avg_size {
        sum := f32(0)
        end := math.min(i + avg_size, BUFFER_SIZE - 1)
        for j := i; j <= end; j += 1 {
            sum += a.fft[j]
        }
        avg := sum / f32((end - i) + 1)
        for j := i; j <= end; j += 1 {
            a.fft[j] = avg
        }
    }
}

avg_fft :: proc(a: ^AL) {
    switch a.avg_mode {
    case AVERAGE_TYPE.BLOCK:
        apply_block_avg(a, a.avg_size)
    case AVERAGE_TYPE.BOX_FILTER:
        apply_box_filter(a, a.avg_size)
    case AVERAGE_TYPE.DOUBLE_BOX_FILTER:
        apply_box_filter(a, a.avg_size)
        apply_box_filter(a, a.avg_size)
    case AVERAGE_TYPE.WEIGHTED_FILTER:
        apply_weighted_avg(a, a.avg_size)
    case AVERAGE_TYPE.EXPONENTIAL_FILTER:
        apply_exponential_smoothing(a, a.filter_constant)
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
        avg_mode = .DOUBLE_BOX_FILTER,
        avg_size = 8,
        decay = 80,
        amplitude = 5000,
        filter_constant = 1.0,
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