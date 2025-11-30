package main
import "core:fmt"
import "core:slice"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "../../../../rlutil"

main :: proc() {
    WIDTH:  f32 = 1600
    HEIGHT: f32 = 1200
    font_size:     f32 = 64

    rl.InitWindow(i32(WIDTH), i32(HEIGHT), "Odin - Star Wars Text Effect")
    rl.SetTargetFPS(60)

    // --- FONT LOADING ---
    font_path :: "assets/trueno.otf"
    font := rl.LoadFontEx(font_path, i32(font_size), nil, 0)
    
    if font.texture.id == 0 {
        fmt.eprintf("ERROR: FAILED TO LOAD FONT: '%s'\n", font_path)
        fmt.eprintf("Please ensure the font file exists and the path is correct.\n")
    }

    rl.GenTextureMipmaps(&font.texture)
    rl.SetTextureFilter(font.texture, .TRILINEAR)

    msg := `A long time ago in a galaxy
far, far away....

It is a period of civil war.
Rebel spaceships, striking
from a hidden base, have won
their first victory against
the evil Galactic Empire.

During the battle, Rebel
spies managed to steal secret
plans to the Empire's
ultimate weapon, the DEATH
STAR, an armored space
station with enough power to
destroy an entire planet.
`
    text_lines := rlutil.text_split_by_newlines(msg)

    slice.reverse(text_lines[:]) // Reverse the order for proper scrolling

    // Get text dimensions and calculate the total length of the crawl
    total_text_length: f32 = 0
    line_spacing: f32 = 1.8 // Reduced spacing to prevent overlapping
    for &text_line in text_lines {
        line_text_measure := rl.MeasureTextEx(font, text_line.line, font_size, 0)
        text_line.line_width = line_text_measure.x
        text_line.line_height = line_text_measure.y
        total_text_length += text_line.line_height * line_spacing
    }

    camera: rl.Camera3D
    camera.position = {0.0, 200.0, -50.0}     // Higher up, closer to action
    camera.target = {0.0, -100.0, 400.0}      // Look down and far into distance
    camera.up = {0.0, 1.0, 0.0}               // Y is up
    camera.fovy = 75.0                        // Wide FOV for maximum screen use
    camera.projection = .PERSPECTIVE

    // Continuous scroll position (not discrete)
    scroll_offset: f32 = 0.0
    scroll_speed: f32 = 50.0 // Speed in units per second

    for !rl.WindowShouldClose() {
        // smooth continuous movement
        delta_time := rl.GetFrameTime()
        scroll_offset += scroll_speed * delta_time

        // Reset when all text has scrolled past
        if scroll_offset > total_text_length + 500.0 {
            scroll_offset = 0.0
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)
        {
            // Calculate current position offset for smooth scroll
            current_line_offset: f32 = 0.0
            
            for i in 0 ..< len(text_lines) {
                line := &text_lines[i]
                
                // Calculate the Z position for this line based on continuous scroll
                line_z_pos := scroll_offset - total_text_length + current_line_offset
                
                if len(line.line) == 0 {
                    current_line_offset += line.line_height * line_spacing
                    continue
                }
                // Calculate screen-space Y position for fade calculation
                // Project the 3D position to screen space
                world_pos := rl.Vector3{0, 0, line_z_pos}
                screen_pos := rl.GetWorldToScreen(world_pos, camera)
                
                // Calculate alpha based on screen position
                screen_y_normalized := screen_pos.y / HEIGHT
                alpha: f32 = 1.0
                
                // Fade out near top of screen
                if screen_y_normalized < 0.3 {
                    alpha = screen_y_normalized / 0.3
                } else if screen_y_normalized > 0.9 { // Fade out near bottom of screen
                    alpha = (1.0 - screen_y_normalized) / 0.1
                }
                alpha = clamp(alpha, 0.0, 1.0)
                
                // Skip if not visible or too transparent
                if alpha <= 0.01 || line_z_pos < camera.position.z - 100.0 || line_z_pos > 1000.0 {
                    current_line_offset += line.line_height * line_spacing
                    continue
                }

                rlgl.PushMatrix()
                {
                    // Position the text in 3D space
                    rlgl.Translatef(line.line_width / 2, 0.0, line_z_pos)
                    
                    // Create the classic Star Wars crawl angle
                    rlgl.Rotatef(75.0, 1.0, 0.0, 0.0) // 75 degrees for perspective
                    rlgl.Rotatef(180.0, 0.0, 0.0, 1.0) // flip 180 degrees around Z-axis

                    // Create color with smooth fade
                    text_color := rl.Color{255, 255, 0, u8(alpha * 255)} // Yellow with fade
                    
                    // Draw the text
                    rl.DrawTextEx(font, line.line, {0, 0}, font_size, 0, text_color)
                }
                rlgl.PopMatrix()
                // Move to next line position
                current_line_offset += line.line_height * line_spacing
            }
        }
        rl.EndMode3D()
        
        // Add some stars for atmosphere
        for i in 0..<200 {
            star_x := i32(i * 7919) % i32(WIDTH)
            star_y := i32(i * 3571) % i32(HEIGHT)
            rl.DrawPixel(star_x, star_y, rl.Color{255, 255, 255, 30})
        }
        rl.DrawText(fmt.ctprintf("Font Loaded: %v", font.texture.id > 0), 10, 10, 20, rl.LIME)
        rl.DrawFPS(10, 40)
        rl.EndDrawing()
    }
    rl.UnloadFont(font)
    rl.CloseWindow()
}