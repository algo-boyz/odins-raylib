package main

import "core:strings"
import rl "vendor:raylib"

// TODO combine with https://www.shadertoy.com/view/4djBDW

WIDTH :: 800
HEIGHT :: 600

TEXT_SIZE :: 20
SCROLL_SPEED :: 50.0 // Pixels per second
FADE_DURATION :: 2.0 // Duration of the fade effect (in seconds)
PERSPECTIVE_ANGLE :: 10.0 // Angle in degrees for the perspective effect
VANISHING_POINT_Y :: f32(HEIGHT * 0.5) // Where text converges

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Star Wars")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    text_to_scroll :: 
        "A long time ago, in a galaxy far, far away...\n\n" +
        "Great unrest reigns in the Galactic Republic.\n" +
        "Taxes on trade routes to distant stars\n" +
        "are a subject of growing controversy.\n\n" +
        "Greedy, the Trade Federation has blockaded the small planet\n" +
        "Naboo with a fleet of powerful and deadly warships.\n\n" +
        "While the Congress of the Republic endlessly debates this series\n" +
        "of frightening events, the Supreme Chancellor has secretly\n" +
        "sent two Jedi Knights, the guardians of peace and justice in the\n" +
        "galaxy, to settle the conflict..."

    // Variables for scrolling effect
    scroll_offset: f32 = 0.0
    fade_timer: f32 = 0.0

    // Split text into lines for proper rendering
    lines := strings.split_lines(text_to_scroll)
    defer delete(lines)

    // Calculate total text height
    line_height := f32(TEXT_SIZE) * 1.5
    total_text_height := f32(len(lines)) * line_height

    for !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        // Scrolling
        scroll_offset += SCROLL_SPEED * delta_time
        // Fade effect timer
        fade_timer += delta_time
        // Reset when text scrolls completely off screen
        if scroll_offset > total_text_height + f32(HEIGHT) {
            scroll_offset = 0.0
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        // Draw each line of text with perspective
        current_y_offset := -scroll_offset
        for line, i in lines {
            if len(line) > 0 {
                // Convert Odin string to cstring for raylib
                line_cstr := strings.clone_to_cstring(line)
                defer delete(line_cstr)
                
                // Calculate the base Y position for this line
                base_y := f32(HEIGHT) + current_y_offset
                
                // Skip lines that are too far off screen
                if base_y < -100 || base_y > f32(HEIGHT) + 100 {
                    current_y_offset += line_height
                    continue
                }
                // Calculate perspective transformation
                // The further up the screen, the smaller and more centered the text becomes
                distance_from_bottom := (f32(HEIGHT) - base_y) / f32(HEIGHT)
                
                // Perspective scale: text gets smaller as it moves up
                scale_factor := 1.0 - (distance_from_bottom * 0.8)
                if scale_factor < 0.1 do scale_factor = 0.1
                
                // Calculate the Y position with perspective angle
                perspective_y := base_y - (distance_from_bottom * distance_from_bottom * 200.0)
                
                // Measure text to center it horizontally
                text_width := rl.MeasureText(line_cstr, TEXT_SIZE)
                scaled_width := f32(text_width) * scale_factor
                
                draw_pos: rl.Vector2 = {
                    f32(WIDTH) / 2.0 - scaled_width / 2.0,
                    perspective_y,
                }
                // Calculate alpha based on distance for fade effect
                alpha := scale_factor
                if alpha > 1.0 do alpha = 1.0
                if alpha < 0.0 do alpha = 0.0
                
                color := rl.Color{255, 255, 0, u8(alpha * 255)} // Yellow text like in the movies
                
                // Draw text with scaling
                rl.DrawTextEx(
                    rl.GetFontDefault(),
                    line_cstr,
                    draw_pos,
                    f32(TEXT_SIZE) * scale_factor,
                    1.0,
                    color
                )
            }
            current_y_offset += line_height
        }
        // Fade-in effect at the beginning
        if fade_timer < FADE_DURATION {
            alpha_value := fade_timer / FADE_DURATION
            rl.DrawRectangle(
                0, 0, 
                WIDTH, HEIGHT,
                rl.Fade(rl.BLACK, 1.0 - alpha_value),
            )
        }
        // Add some stars in the background for authenticity
        for i in 0..<100 {
            star_x := i32((i * 7919) % WIDTH)  // Pseudo-random positions
            star_y := i32((i * 3571) % HEIGHT)
            rl.DrawPixel(star_x, star_y, rl.Color{255, 255, 255, 50})
        }
        rl.EndDrawing()
    }
}