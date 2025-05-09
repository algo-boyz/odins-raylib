package main

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:os"
import "core:sync"
import "core:thread"
import "core:sync/chan"
import rl "vendor:raylib"

WIDTH  :: 900
HEIGHT :: 900
RUN_TIME :: 30.0  // sec
MAX_ITER :: 200 
INITIAL_SCALE :: 1.0 / 300.0
INITIAL_OFFSET_X :: -2.25
INITIAL_OFFSET_Y :: -1.5


// Chunk data structure to pass to threads
Chunk_Data :: struct {
    frame_buffer: []rl.Color,
    start_y, end_y: int,
    time, scale, offset_x, offset_y: f64,
    chunk_id: int,  // Add chunk identifier for debugging
}


fill_framebuffer :: proc(frame_buffer: []rl.Color, time: f64, scale: f64, offset_x, offset_y: f64) {
    if len(frame_buffer) != WIDTH * HEIGHT {
        fmt.eprintln("ERROR: Frame buffer size mismatch")
        return
    }
    CHUNK_SIZE := max(2, os.processor_core_count())
    
    chunk_height := HEIGHT / CHUNK_SIZE
    threads: [dynamic]^thread.Thread
    resize(&threads, CHUNK_SIZE)

    for chunk in 0..<CHUNK_SIZE {
        start_y := chunk * chunk_height
        end_y := start_y + chunk_height
        // Validate chunk boundaries
        if start_y < 0 || end_y > HEIGHT || start_y >= HEIGHT {
            fmt.eprintln("Invalid chunk boundaries:", start_y, end_y)
            continue
        }
        chunk_data := new(Chunk_Data)
        chunk_data^ = Chunk_Data {
            frame_buffer = frame_buffer,
            start_y = start_y,
            end_y = end_y,
            time = time,
            scale = scale,
            offset_x = offset_x,
            offset_y = offset_y,
            chunk_id = chunk,
        }
        threads[chunk] = thread.create(proc(t: ^thread.Thread) {
            context = runtime.default_context()
            chunk_data := (cast(^Chunk_Data)t.data)
            defer free(chunk_data)

            // fmt.println("Processing chunk:", chunk_data.chunk_id, 
            //             "Start Y:", chunk_data.start_y, 
            //             "End Y:", chunk_data.end_y)
            adaptive_max_iter := MAX_ITER * math.log(1/chunk_data.scale + 1, 10)

            for x in 0..<WIDTH {
                for y in chunk_data.start_y..<chunk_data.end_y {
                    // Rigorous boundary checks
                    if y < 0 || y >= HEIGHT || x < 0 || x >= WIDTH {
                        fmt.eprintln("Invalid coordinates: x =", x, "y =", y)
                        continue
                    }

                    idx := y * WIDTH + x
                    if idx < 0 || idx >= len(chunk_data.frame_buffer) {
                        fmt.eprintln("Invalid buffer index:", idx, "for x =", x, "y =", y)
                        continue
                    }
                    // Compute Mandelbrot set
                    c_re := f64(x) * chunk_data.scale + chunk_data.offset_x
                    c_im := f64(y) * chunk_data.scale + chunk_data.offset_y
                    res := mandelbrot(c_re, c_im, adaptive_max_iter)
                    // Safe pixel coloring
                    if res == adaptive_max_iter {
                        chunk_data.frame_buffer[idx] = rl.BLACK
                    } else {
                        r := u8(127.5 * math.cos(res * 0.3 + chunk_data.time) + 127.5)
                        g := u8(127.5 * math.cos(res * 0.7 + chunk_data.time) + 127.5)
                        b := u8(127.5 * math.cos(res * 0.9 + chunk_data.time) + 127.5)
                        chunk_data.frame_buffer[idx] = rl.Color{r, g, b, 255}
                    }
                }
            }
        })
        threads[chunk].data = chunk_data
        thread.start(threads[chunk])
    }
    // Wait for all threads to finish
    for chunk in 0..<CHUNK_SIZE {
        thread.destroy(threads[chunk])
    }
}

Test :: struct {
    frame_count: int,
    avg_fps: f64,
    start_time: f64,
    elapsed_time: f64,
}

mandelbrot :: proc(c_re, c_im: f64, max_iter: f64) -> f64 {
    // quick escape for main cardioid and bulb
    q := (c_re - 0.25) * (c_re - 0.25) + c_im * c_im
    if q * (q + (c_re - 0.25)) <= 0.25 * c_im * c_im {
        return max_iter
    }
    // aggressive pre-checks
    c_norm := c_re * c_re + c_im * c_im
    if c_norm < 0.0001 || c_norm > 4.0 {
        return max_iter
    }
    // adaptive iteration
    z_re, z_im: f64 = 0, 0
    iter: f64 = 0
    for iter < max_iter {
        z_re_sqr := z_re * z_re
        z_im_sqr := z_im * z_im
        // early escape condition
        if z_re_sqr + z_im_sqr > 4.0 {
            return iter - math.log2(math.log2(z_re_sqr + z_im_sqr))
        }
        z_im = 2 * z_re * z_im + c_im
        z_re = z_re_sqr - z_im_sqr + c_re

        iter += 1
    }
    return max_iter
}

draw_avg_fps :: proc(test: ^Test, run_time: f64) {
    if test.elapsed_time < run_time {
        test.elapsed_time = rl.GetTime() - test.start_time
        test.avg_fps = f64(test.frame_count) / test.elapsed_time
        rl.DrawText(rl.TextFormat("FPS: %d", int(test.avg_fps)), 10, 10, 30, rl.RAYWHITE)
    } else {
        rl.DrawRectangle(0, 0, WIDTH, HEIGHT, rl.BLACK)
        rl.DrawText("Avg FPS:", 180, 150, 80, rl.RAYWHITE)
        
        col := rl.GREEN
        if test.avg_fps < 30.0 do col = rl.RED
        else if test.avg_fps < 60.0 do col = rl.ORANGE

        rl.DrawText(rl.TextFormat("%.1f", test.avg_fps), 370, 250, 80, col)
    }
}

main :: proc() {
    rl.SetTraceLogLevel(.NONE)
    rl.InitWindow(WIDTH, HEIGHT, "Mandelbrot Fractal")
    defer rl.CloseWindow()

    frame_buffer := make([]rl.Color, WIDTH * HEIGHT)
    defer delete(frame_buffer)

    texture := rl.LoadTextureFromImage(rl.GenImageColor(WIDTH, HEIGHT, rl.BLACK))
    defer rl.UnloadTexture(texture)

    test: Test
    test.start_time = rl.GetTime()

    // Zoom and pan variables
    scale := INITIAL_SCALE
    offset_x := INITIAL_OFFSET_X
    offset_y := INITIAL_OFFSET_Y
    zoom_speed := 0.9
    for !rl.WindowShouldClose() {

        mouse_wheel := rl.GetMouseWheelMove()
        if mouse_wheel != 0 {
            mouse_x := rl.GetMouseX()
            mouse_y := rl.GetMouseY()
            // Calculate mouse position in fractal coordinates
            mouse_re := f64(mouse_x) * scale + offset_x
            mouse_im := f64(mouse_y) * scale + offset_y
            // Zoom in or out
            if mouse_wheel > 0 {
                scale *= zoom_speed
                offset_x = mouse_re - f64(mouse_x) * scale
                offset_y = mouse_im - f64(mouse_y) * scale
            } else {
                scale /= zoom_speed
                offset_x = mouse_re - f64(mouse_x) * scale
                offset_y = mouse_im - f64(mouse_y) * scale
            }
        }

        fill_framebuffer(frame_buffer, rl.GetTime(), scale, offset_x, offset_y)
        rl.UpdateTexture(texture, raw_data(frame_buffer))

        rl.BeginDrawing()
        rl.DrawTexture(texture, 0, 0, rl.WHITE)
        draw_avg_fps(&test, RUN_TIME)
        rl.EndDrawing()

        test.frame_count += 1
    }
}