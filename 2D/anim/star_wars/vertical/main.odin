package main

import rl "vendor:raylib"
import "../../../../rlutil"

main :: proc() {
    WIDTH:  f32 = 1600
    HEIGHT: f32 = 1200
    font_size:     f32 = 64

    rl.InitWindow(i32(WIDTH), i32(HEIGHT), "Aliased Font Scroll")
    rl.SetTargetFPS(60)

    // Load font from file
    font := rl.LoadFontEx("assets/trueno.otf", i32(font_size), nil, 0)
    rl.GenTextureMipmaps(&font.texture)
    rl.SetTextureFilter(font.texture, .TRILINEAR)

    msg := `Lorem ipsum dolor sit amet,
consetetur sadipscing elitr,
sed diam nonumy eirmod tempor
invidunt ut labore et dolore
magna aliquyam erat, sed diam
voluptua. At vero eos et accusam
et justo duo dolores et ea rebum.
Stet clita kasd gubergren, no sea
takimata sanctus est Lorem ipsum
dolor sit amet. Lorem ipsum dolor
sit amet, consetetur sadipscing elitr,
sed diam nonumy eirmod tempor invidunt
ut labore et dolore magna aliquyam erat,
sed diam voluptua. At vero eos et
accusam et justo duo dolores et ea
rebum. Stet clita kasd gubergren, no
sea takimata sanctus est Lorem ipsum
dolor sit amet.
****
`
    // Convert text to a slice of Text_Line
    text_lines := rlutil.text_split_by_newlines(msg)

    // Get text dimensions of each line
    for &text_line in text_lines {
        line_text_measure := rl.MeasureTextEx(font, text_line.line, font_size, 0)
        text_line.line_width = line_text_measure.x
        text_line.line_height = line_text_measure.y
        text_line.line_offset = -1 // Indicates not yet set
    }

    move_speed: f32 = 1.0
    text_position: rl.Vector2

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        for i in 0 ..< len(text_lines) {
            // Update offset for the text lines
            if text_lines[i].line_offset == -1 {
                if i > 0 {
                    text_lines[i].line_offset = text_lines[i-1].line_offset + text_lines[i-1].line_height
                } else {
                    text_lines[i].line_offset = HEIGHT
                }
            } else if text_lines[i].line_offset <= -text_lines[i].line_height {
                continue
            } else {
                text_lines[i].line_offset -= move_speed
            }

            // Calculate horizontal position for line
            text_position.x = WIDTH / 2 - text_lines[i].line_width / 2
            text_position.y = text_lines[i].line_offset

            // Draw the text
            rl.DrawTextEx(font, text_lines[i].line, text_position, f32(font.baseSize), 0, rl.WHITE)
        }
        rl.EndDrawing()
        
        // Reset scrolling after it has been completely shown
        if len(text_lines) > 0 {
            last_line := &text_lines[len(text_lines)-1]
            if last_line.line_offset != -1 && last_line.line_offset <= -last_line.line_height {
                for i in 0 ..< len(text_lines) {
                    text_lines[i].line_offset = -1
                }
            }
        }
    }
    // Unload font
    rl.UnloadFont(font)
    
    // Close window and OpenGL context
    rl.CloseWindow()
}