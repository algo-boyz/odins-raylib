package main

import "core:math"
import rl "vendor:raylib"

TEXT_SIZE :: 20 // Size of the orbiting text
ORBIT_RADIUS :: 100
ORBIT_SPEED :: 1.0 // Speed of the orbit in radians per second
FADE_IN_DURATION :: 2.0 // Duration of the fade-in effect in seconds

main :: proc() {
    WIDTH :: 800
    HEIGHT :: 450
    rl.InitWindow(WIDTH, HEIGHT, "Text Orbiting Object")
    rl.SetTargetFPS(60) 
    
    object_center := rl.Vector2{f32(WIDTH) / 2.0, f32(HEIGHT) / 2.0}
    object_color := rl.GREEN
    
    text :: "Orbiting Text!"
    text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, TEXT_SIZE, 0)
    
    orbit_angle: f32 = 0.0
    fade_in_alpha: f32 = 0.0
    start_time := rl.GetTime()

    for !rl.WindowShouldClose() {
        current_time := rl.GetTime()
        
        // Fade-in effect: Calculate alpha based on elapsed time
        if current_time - start_time < FADE_IN_DURATION {
            fade_in_alpha = f32((current_time - start_time) / FADE_IN_DURATION) // Normalise time to a value between 0 and 1
            if fade_in_alpha > 1.0 {
                fade_in_alpha = 1.0 // Limit alpha to 1.0 (fully opaque)
            }
        } else {
            fade_in_alpha = 1.0
            orbit_angle += ORBIT_SPEED * rl.GetFrameTime()
        }
        // Calculating the position of the text based on orbit angle
        text_position := rl.Vector2{
            object_center.x + math.cos(orbit_angle) * ORBIT_RADIUS - text_size.x / 2.0,
            object_center.y + math.sin(orbit_angle) * ORBIT_RADIUS - text_size.y / 2.0,
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        {
            // Draw the object at the center
            rl.DrawCircleV(object_center, 20, object_color)

            // Draw the orbiting text with fade-in effect
            text_color := rl.Fade(rl.BLACK, fade_in_alpha)
            rl.DrawTextEx(rl.GetFontDefault(), text, text_position, TEXT_SIZE, 0, text_color)
        }
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}