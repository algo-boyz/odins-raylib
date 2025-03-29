package main

import "core:time"
import rl "vendor:raylib"
import "../../../../rlutil"

draw_separator :: proc(offset, led_width, screen_height: i32, color: rl.Color) -> i32 {
    pad := (screen_height - 2 * led_width) / 3
    rl.DrawRectangle(offset + led_width, pad, led_width, led_width, color)
    rl.DrawRectangle(offset + led_width, pad + pad + led_width, led_width, led_width, color)
    return offset + 2 * led_width
}

draw_digit :: proc(
    offset, h_led_length, v_led_length, led_width, digit: i32,
    color: rl.Color,
) -> i32 {
    led_colors := [7]rl.Color{
        {84, 84, 84, 255},  // DARKGRAY
        {84, 84, 84, 255},
        {84, 84, 84, 255},
        {84, 84, 84, 255},
        {84, 84, 84, 255},
        {84, 84, 84, 255},
        {84, 84, 84, 255},
    }

    /*  000                                 *
     * 3   5                                *
     * 3   5                                *
     *  111                                 *
     * 4   6                                *
     * 4   6                                *
     *  222                                 * 
     *  This is the order of LEDs in array. */
    
    switch digit {
    case 0:
        led_colors[0] = color
        led_colors[2] = color
        led_colors[3] = color
        led_colors[4] = color
        led_colors[5] = color
        led_colors[6] = color
    case 1:
        led_colors[5] = color
        led_colors[6] = color
    case 2:
        led_colors[0] = color
        led_colors[1] = color
        led_colors[2] = color
        led_colors[4] = color
        led_colors[5] = color
    case 3:
        led_colors[0] = color
        led_colors[1] = color
        led_colors[2] = color
        led_colors[5] = color
        led_colors[6] = color
    case 4:
        led_colors[1] = color
        led_colors[3] = color
        led_colors[5] = color
        led_colors[6] = color
    case 5:
        led_colors[0] = color
        led_colors[1] = color
        led_colors[2] = color
        led_colors[3] = color
        led_colors[6] = color
    case 6:
        led_colors[0] = color
        led_colors[1] = color
        led_colors[2] = color
        led_colors[3] = color
        led_colors[4] = color
        led_colors[6] = color
    case 7:
        led_colors[0] = color
        led_colors[5] = color
        led_colors[6] = color
    case 8:
        led_colors[0] = color
        led_colors[1] = color
        led_colors[2] = color
        led_colors[3] = color
        led_colors[4] = color
        led_colors[5] = color
        led_colors[6] = color
    case 9:
        led_colors[0] = color
        led_colors[1] = color
        led_colors[2] = color
        led_colors[3] = color
        led_colors[5] = color
        led_colors[6] = color
    }

    // Top horizontal
    rl.DrawRectangle(led_width * 2 + offset, led_width, h_led_length, led_width, led_colors[0])
    
    // Middle horizontal
    rl.DrawRectangle(led_width * 2 + offset, led_width * 2 + v_led_length, h_led_length, led_width, led_colors[1])
    
    // Bottom horizontal
    rl.DrawRectangle(led_width * 2 + offset, led_width * 3 + v_led_length * 2, h_led_length, led_width, led_colors[2])
    
    // Topleft vertical
    rl.DrawRectangle(led_width + offset, led_width * 2, led_width, v_led_length, led_colors[3])
    
    // Bottomleft vertical
    rl.DrawRectangle(led_width + offset, led_width * 3 + v_led_length, led_width, v_led_length, led_colors[4])
    
    // Topright vertical
    rl.DrawRectangle(led_width * 2 + offset + h_led_length, led_width * 2, led_width, v_led_length, led_colors[5])
    
    // Bottomright vertical
    rl.DrawRectangle(led_width * 2 + offset + h_led_length, led_width * 3 + v_led_length, led_width, v_led_length, led_colors[6])
    
    return offset + 3 * led_width + h_led_length
}

main :: proc() {
    // Available LED colors
    led_options := []rl.Color{
        {0, 228, 48, 255},    // GREEN
        {0, 121, 241, 255},   // BLUE
        {230, 41, 55, 255},   // RED
        {255, 161, 0, 255},   // ORANGE
        {200, 122, 255, 255}, // PURPLE
        {253, 249, 0, 255},   // YELLOW
        {255, 255, 255, 255}, // WHITE
        {255, 0, 255, 255},   // MAGENTA
    }
    
    option_size := len(led_options)
    selected_color := 0

    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(640, 180, "Clock. Press space to change color.")
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        // Calculate dimensions based on the current window size
        screen_width := rl.GetScreenWidth()
        screen_height := rl.GetScreenHeight()
        led_width := screen_width / (23 * 2)
        h_led_length := (screen_width - led_width * 23) / 6
        v_led_length := (screen_height - led_width * 5) / 2

        // Get current time
        hour, minute, second, _ := rlutil.clock_from_nano(time.now()._nsec)
        // Handle input
        if rl.IsKeyPressed(.SPACE) {
            if selected_color == option_size - 1 {
                selected_color = 0
            } else {
                selected_color += 1
            }
        }

        rl.BeginDrawing()
        {
            rl.ClearBackground({0, 0, 0, 255}) // BLACK
            
            // Draw Hours
            offset := draw_digit(0, h_led_length, v_led_length, led_width, 
                                i32(hour / 10), led_options[selected_color])
            offset = draw_digit(offset, h_led_length, v_led_length, led_width, 
                                i32(hour % 10), led_options[selected_color])
            
            // Draw separator
            offset = draw_separator(offset, led_width, screen_height, led_options[selected_color])
            
            // Draw Minutes
            offset = draw_digit(offset, h_led_length, v_led_length, led_width, 
                                i32(minute / 10), led_options[selected_color])
            offset = draw_digit(offset, h_led_length, v_led_length, led_width, 
                                i32(minute % 10), led_options[selected_color])
            
            // Draw separator
            offset = draw_separator(offset, led_width, screen_height, led_options[selected_color])
            
            // Draw Seconds
            offset = draw_digit(offset, h_led_length, v_led_length, led_width, 
                                i32(second / 10), led_options[selected_color])
            offset = draw_digit(offset, h_led_length, v_led_length, led_width, 
                                i32(second % 10), led_options[selected_color])
        }
        rl.EndDrawing()
    }

    rl.CloseWindow()
}