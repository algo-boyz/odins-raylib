package main

import "core:math"
import rl "vendor:raylib"

FONT_SIZE :: 40

main :: proc() {
    WIDTH  :: 800
    HEIGHT :: 450
    rl.InitWindow(700, 600, "Wavy text effect")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    // Text to display
    text_to_display :: "Wave effect"
    font_size :: FONT_SIZE
    text_color := rl.RAYWHITE

    // Initial position of the text (centered)
    // Ensure floating point division for precise centering with Vector2
    text_measure_width := rl.MeasureText(text_to_display, font_size)
    text_base_position := rl.Vector2 {
        (f32(WIDTH) - f32(text_measure_width)) / 2.0,
        f32(HEIGHT) / 2.0,
    }
    // Wave effect parameters
    wave_frequency: f32 = 0.05
    wave_amplitude: f32 = 10.0
    wave_speed: f32 = 1.0 // Increase for a faster wave
    wave_offset: f32 = 0.0

    for !rl.WindowShouldClose() {
        // Increment offset to animate the wave
        wave_offset += wave_speed * rl.GetFrameTime()

        rl.BeginDrawing()
        rl.ClearBackground(rl.DARKBLUE)

        // Draw each letter with a vertical offset based on the wave effect
        for i in 0..<len(text_to_display) {
            // Calculate the horizontal position of the current character.
            // This measures the width of the text preceding the current character.
            prefix_text_to_measure: cstring
            prefix_text_to_measure = rl.TextSubtext(text_to_display, 0, i32(i))
            
            width_of_prefix := rl.MeasureText(prefix_text_to_measure, font_size)
            char_x_pos := text_base_position.x + f32(width_of_prefix)

            // Calculate the vertical position with the wave effect
            // f32(i) ensures the index contributes as a float in the sine wave calculation
            char_y_pos := text_base_position.y + math.sin(wave_offset + f32(i) * wave_frequency) * wave_amplitude

            // Get the current character as a new string to draw
            // (DrawText expects a string, not a single rune)
            current_char_as_string := rl.TextSubtext(text_to_display, i32(i), 1)

            // Draw the character
            // rl.draw_text expects integer positions, so cast float positions
            rl.DrawText(current_char_as_string, i32(char_x_pos), i32(char_y_pos), font_size, text_color)
        }
        rl.DrawText("Press ESC to exit", 10, 10, 20, rl.LIGHTGRAY)
        rl.EndDrawing()
    }
}