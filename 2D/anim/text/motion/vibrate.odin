package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 450
TEXT :: "Hello Raylib!"
FONT_SIZE :: 40
TEXT_COLOR :: rl.WHITE

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Text that Jumps and Vibrates")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    // Variables for animation
    // Note: Explicit f32 casts are used for calculations involving integer constants to ensure floating-point arithmetic.
    text_x := f32(WINDOW_WIDTH) / 2.0 - f32(rl.MeasureText(TEXT, FONT_SIZE)) / 2.0
    text_y := f32(WINDOW_HEIGHT) / 2.0
    
    offset_y: f32 = 0.0         // Vertical displacement for the jump
    offset_rotation: f32 = 0.0  // Rotation for vibration
    time: f32 = 0.0

    for !rl.WindowShouldClose() {
        time += rl.GetFrameTime()

        // Jump animation: Use a sinusoidal function for smooth movement
        offset_y = math.sin(time * 5.0) * 20.0 // Speed * Amplitude

        // Vibration animation: Small, quick rotation
        offset_rotation = math.sin(time * 15.0) * 2.0 // Speed * Amplitude (of rotation)

        rl.BeginDrawing()
        rl.ClearBackground(rl.DARKGRAY)

        text_draw_position := rl.Vector2{text_x, text_y}
        text_origin := rl.Vector2{
            f32(rl.MeasureText(TEXT, FONT_SIZE)) / 2.0,
            f32(FONT_SIZE) / 2.0,
        }
        rl.DrawTextPro(
            rl.GetFontDefault(),    // Default font
            TEXT,                     // Text to draw
            text_draw_position,       // Position (center of the text, without offsetY applied as per original C)
            text_origin,              // Origin for rotation (center of the measured text)
            offset_rotation,          // Rotation in degrees
            100.0,                    // Font size for drawing (different from FONT_SIZE used for measurement)
            1.0,                      // Spacing between characters (if multiple lines)
            TEXT_COLOR,               // Text color
        )
        // Display debug info
        debug_text_offset_y := fmt.ctprintf("Offset Y: %.2f", offset_y)
        rl.DrawText(debug_text_offset_y, 10, 10, 20, rl.GREEN)

        debug_text_rotation := fmt.ctprintf("Rotation: %.2f", offset_rotation)
        rl.DrawText(debug_text_rotation, 10, 40, 20, rl.GREEN)
        
        rl.EndDrawing()
    }
}