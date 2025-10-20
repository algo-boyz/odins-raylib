package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import gif "../../../rlutil/gif"

WIDTH  :: 1000
HEIGHT :: 900

ShaderMode :: enum {
    NONE,
    RADIAL_ZOOM,
    HYPERSPACE,
    MOTION_BLUR,
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "The Universe")
    defer rl.CloseWindow()

    // Create GIF players
    player1 := gif.new_player()
    defer gif.player_unload(&player1)

    player2 := gif.new_player()
    defer gif.player_unload(&player2)

    // Load GIF files
    if !gif.player_load(&player1, "../assets/universe.gif") {
        return
    }
    // Set up player 1 (full screen with some padding for zoom effect)
    padding := f32(50)
    gif.player_set_dest_rect(&player1, rl.Rectangle{-padding, -padding, f32(WIDTH) + padding*2, f32(HEIGHT) + padding*2})
    
    // Set up player 2 (small corner display)
    gif.player_load(&player2, "../assets/nexus.gif")
    gif.player_set_dest_rect(&player2, rl.Rectangle{WIDTH - 200, 10, 180, 120})

    // Load shaders
    radial_shader := rl.LoadShader("", "shaders/radial_zoom.fs")
    defer rl.UnloadShader(radial_shader)
    
    hyperspace_shader := rl.LoadShader("", "shaders/hyperspace.fs")
    defer rl.UnloadShader(hyperspace_shader)
    
    motion_blur_shader := rl.LoadShader("", "shaders/motion_blur.fs")
    defer rl.UnloadShader(motion_blur_shader)

    // Get shader uniform locations
    time_loc_radial := rl.GetShaderLocation(radial_shader, "time")
    resolution_loc_radial := rl.GetShaderLocation(radial_shader, "resolution")
    
    time_loc_hyperspace := rl.GetShaderLocation(hyperspace_shader, "time")
    resolution_loc_hyperspace := rl.GetShaderLocation(hyperspace_shader, "resolution")
    
    time_loc_motion := rl.GetShaderLocation(motion_blur_shader, "time")
    resolution_loc_motion := rl.GetShaderLocation(motion_blur_shader, "resolution")

    // Create render texture for post-processing
    render_target := rl.LoadRenderTexture(WIDTH, HEIGHT)
    defer rl.UnloadRenderTexture(render_target)

    // Animation state
    zoom_factor := f32(1.0)
    rotation := f32(0.0)
    pulse_intensity := f32(0.0)
    shader_mode := ShaderMode.NONE
    auto_zoom := false
    
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        time := rl.GetTime()
        
        // Handle input for player 1
        if rl.IsKeyPressed(.RIGHT) {
            current_delay := player1.frame_delay
            gif.player_set_speed(&player1, current_delay + 1)
        } else if rl.IsKeyPressed(.LEFT) {
            current_delay := player1.frame_delay
            gif.player_set_speed(&player1, current_delay - 1)
        }
        
        if rl.IsKeyPressed(.SPACE) {
            if gif.player_is_playing(&player1) {
                gif.player_pause(&player1)
            } else {
                gif.player_play(&player1)
            }
        }
        
        // Shader mode switching
        if rl.IsKeyPressed(.ONE) do shader_mode = ShaderMode.NONE
        if rl.IsKeyPressed(.TWO) do shader_mode = ShaderMode.RADIAL_ZOOM  
        if rl.IsKeyPressed(.THREE) do shader_mode = ShaderMode.HYPERSPACE
        if rl.IsKeyPressed(.FOUR) do shader_mode = ShaderMode.MOTION_BLUR
        
        // Toggle auto-zoom
        if rl.IsKeyPressed(.Z) do auto_zoom = !auto_zoom
        
        // Manual zoom controls
        if rl.IsKeyDown(.UP) do zoom_factor += dt * 0.5
        if rl.IsKeyDown(.DOWN) do zoom_factor -= dt * 0.5
        zoom_factor = clamp(zoom_factor, 0.1, 3.0)
        
        // Auto zoom effect
        if auto_zoom {
            zoom_factor = 1.0 + math.sin(f32(time) * 0.8) * 0.3
            rotation += dt * 5.0
        }
        
        // Pulse effect based on frame changes
        current_frame := gif.player_get_current_frame(&player1)
        pulse_intensity = math.sin(f32(current_frame) * 0.2) * 0.1 + 1.0

        // Update players
        gif.player_update(&player1)
        gif.player_update(&player2)

        // Update shader uniforms
        resolution := [2]f32{f32(WIDTH), f32(HEIGHT)}
        
        // Render to texture first
        rl.BeginTextureMode(render_target)
        rl.ClearBackground(rl.BLACK)
        
        // Apply transformations
        rl.BeginMode2D(rl.Camera2D{
            target = {f32(WIDTH)/2, f32(HEIGHT)/2},
            offset = {f32(WIDTH)/2, f32(HEIGHT)/2},
            rotation = rotation,
            zoom = zoom_factor * pulse_intensity,
        })
        
        // Draw main GIF
        gif.player_draw(&player1)
        
        rl.EndMode2D()
        rl.EndTextureMode()

        // Main drawing
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        // Apply shader effects
        switch shader_mode {
        case .RADIAL_ZOOM:
            rl.BeginShaderMode(radial_shader)
            rl.SetShaderValue(radial_shader, time_loc_radial, &time, .FLOAT)
            rl.SetShaderValue(radial_shader, resolution_loc_radial, &resolution, .VEC2)
            
        case .HYPERSPACE:
            rl.BeginShaderMode(hyperspace_shader)
            rl.SetShaderValue(hyperspace_shader, time_loc_hyperspace, &time, .FLOAT)
            rl.SetShaderValue(hyperspace_shader, resolution_loc_hyperspace, &resolution, .VEC2)
            
        case .MOTION_BLUR:
            rl.BeginShaderMode(motion_blur_shader)
            rl.SetShaderValue(motion_blur_shader, time_loc_motion, &time, .FLOAT)
            rl.SetShaderValue(motion_blur_shader, resolution_loc_motion, &resolution, .VEC2)
            
        case .NONE:
            // No shader
        }
        
        // Draw the render texture
        rl.DrawTextureRec(
            render_target.texture,
            rl.Rectangle{0, 0, f32(WIDTH), -f32(HEIGHT)}, // Flip Y
            rl.Vector2{0, 0},
            rl.WHITE
        )
        
        if shader_mode != .NONE do rl.EndShaderMode()
        
        // Draw small corner GIF (no effects)
        gif.player_draw(&player2)
        
        // Enhanced UI with more options
        y_offset := f32(30)
        rl.DrawText(fmt.ctprintf("TOTAL FRAMES: %02d", gif.player_get_total_frames(&player1)), 50, i32(y_offset), 20, rl.LIGHTGRAY)
        y_offset += 30
        rl.DrawText(fmt.ctprintf("CURRENT FRAME: %02d", gif.player_get_current_frame(&player1)), 50, i32(y_offset), 20, rl.GRAY)
        y_offset += 30
        rl.DrawText(fmt.ctprintf("FPS: %02d", gif.player_get_fps(&player1)), 50, i32(y_offset), 20, rl.GRAY)
        y_offset += 30
        rl.DrawText(fmt.ctprintf("ZOOM: %.2f", zoom_factor), 50, i32(y_offset), 20, rl.GRAY)
        y_offset += 30
        
        shader_names := [4]string{"NONE", "RADIAL", "HYPERSPACE", "MOTION BLUR"}
        rl.DrawText(fmt.ctprintf("SHADER: %s", shader_names[int(shader_mode)]), 50, i32(y_offset), 20, rl.YELLOW)
        y_offset += 30
        
        if auto_zoom {
            rl.DrawText("AUTO-ZOOM: ON", 50, i32(y_offset), 20, rl.GREEN)
        } else {
            rl.DrawText("AUTO-ZOOM: OFF", 50, i32(y_offset), 20, rl.RED)
        }
        
        // Controls
        controls_y :: HEIGHT - 120
        rl.DrawText("LEFT/RIGHT: Speed | SPACE: Play/Pause", 50, controls_y, 16, rl.LIGHTGRAY)
        rl.DrawText("UP/DOWN: Manual Zoom | Z: Toggle Auto-Zoom", 50, controls_y + 20, 16, rl.LIGHTGRAY)
        rl.DrawText("1-4: Shader Effects", 50, controls_y + 40, 16, rl.LIGHTGRAY)
        
        rl.EndDrawing()
    }
}