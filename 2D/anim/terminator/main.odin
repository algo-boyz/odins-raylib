package main

import "core:strings"
import "core:unicode/utf8"
import "core:fmt"
import "core:math"
import tw "typewriter"
import rl "vendor:raylib"

screen_width :: 1280
screen_height :: 720

main :: proc() {    
    rl.InitWindow(screen_width, screen_height, "T-800 Typewriter Demo")
    rl.SetTargetFPS(60)

    bg := rl.LoadImage("assets/terminator.jpg")
    rl.ImageResize(&bg, screen_width, screen_height)
    tex := rl.LoadTextureFromImage(bg)
    rl.UnloadImage(bg)

    rl.InitAudioDevice()
    fx_ogg := rl.LoadSound("assets/terminal.ogg")

    // Create typewriter configurations
    fast_config := tw.TypewriterConfig{
        chars_per_second = 25.0,
        glow_intensity = 1.0,
        glow_radius = 2.0,
        sound_enabled = true,
        skip_space_sounds = true,
    }
    
    slow_config := tw.TypewriterConfig{
        chars_per_second = 8.0,
        glow_intensity = 0.6,
        glow_radius = 1.2,
        sound_enabled = true,
        skip_space_sounds = true,
    }

    // Setup text content
    information := []string{
        "LOADING TRAJECTORY:",
        "********************",
        "5430 543 7980 10930                          3430 343 3430",
        "PRIORITY OVERRIDE                         MULTI TARGET"
    }
    
    details := []string{
        "THREAT ASSESSMENT",
        "SELECT ALL", 
        "TERMINATION OVERRIDE",
        "TARGETS ONLY"
    }
    
    // Create typewriter instances
    info_typewriter := tw.init_typewriter(
        information, 
        110, 100, 30, 
        rl.RAYWHITE, rl.GREEN,
        fx_ogg, fast_config
    )
    
    details_typewriter := tw.init_typewriter(
        details,
        110, 540, 30,
        rl.GREEN, rl.LIME,
        fx_ogg, slow_config
    )
    
    for !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        
        // Update typewriters
        tw.update_typewriter(&info_typewriter, delta_time)
        
        // Start details typewriter only after info is complete
        if tw.is_typewriter_complete(&info_typewriter) {
            tw.update_typewriter(&details_typewriter, delta_time)
        }
        
        // Reset demo when both are complete (for continuous demo)
        if tw.is_typewriter_complete(&info_typewriter) && tw.is_typewriter_complete(&details_typewriter) {
            // Optional: Add delay before reset
            // reset_typewriter(&info_typewriter)
            // reset_typewriter(&details_typewriter)
        }
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.DrawTexture(tex, 0, 0, rl.WHITE)
        
        // Draw typewriters
        tw.draw_typewriter(&info_typewriter)
        if tw.is_typewriter_complete(&info_typewriter) {
            tw.draw_typewriter(&details_typewriter)
        }
        
        rl.EndDrawing()
    }
    
    rl.UnloadSound(fx_ogg)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}