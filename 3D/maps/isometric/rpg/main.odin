package main

import "core:fmt"
import "core:c"
import rl "vendor:raylib"
import g "./gif" // Import the local gif package

MAPWIDTH :: 14
MAPHEIGHT :: 20

screen_width: i32 = 1280
screen_height: i32 = 720

x_axis_color := rl.RED
y_axis_color := rl.GREEN
z_axis_color := rl.BLUE
axis_length: f32 = 10.0
z_offset: f32 = 0.6

game_map := [MAPHEIGHT][MAPWIDTH]i32{
    {0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1},
    {0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1},
    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
    {0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
    {0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
    {0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
    {1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1},
    {1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1},
    {1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1},
    {0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0},
    {0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0},
    {0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0},
}

draw_map :: proc() {
    for x in 0..<MAPWIDTH {
        for y in 0..<MAPHEIGHT {
            tile_id := game_map[y][x]
            if tile_id == 1 {
                // Checkerboard pattern
                color := rl.WHITE if (x + y) % 2 == 0 else rl.DARKGRAY
                position := rl.Vector3{f32(x), 0, f32(y)}
                rl.DrawCube(position, 1, 0.1, 1, color)
            }
        }
    }
}

draw_axis_lines :: proc() {
    // X axis
    rl.DrawLine3D(
        rl.Vector3{0, 0, 0},
        rl.Vector3{axis_length, 0, 0},
        x_axis_color,
    )
    // Y axis
    rl.DrawLine3D(
        rl.Vector3{0, 0, 0},
        rl.Vector3{0, axis_length, 0},
        y_axis_color,
    )
    // Z axis
    rl.DrawLine3D(
        rl.Vector3{0, 0, 0},
        rl.Vector3{0, 0, axis_length},
        z_axis_color,
    )
}

check_floor_tile :: proc(position: rl.Vector2) -> bool {
    if position.y >= 0 && position.y < MAPHEIGHT && position.x >= 0 && position.x < MAPWIDTH {
        return game_map[i32(position.y)][i32(position.x)] == 1
    }
    return false
}

main :: proc() {
    // Raylib Init
    rl.InitWindow(screen_width, screen_height, "Odin 3D Game")
    rl.InitAudioDevice()
    rl.SetTargetFPS(60)

    // --- Resource Declarations ---
    background_music: rl.Music
    char_model: rl.Model
    gif_player: g.GifPlayer

    music_loaded := false
    model_loaded := false

    // --- Defer block for resource cleanup ---
    // This block ensures all loaded resources are properly unloaded when the program exits.
    defer {
        if music_loaded {
            rl.UnloadMusicStream(background_music)
        }
        if model_loaded {
            rl.UnloadModel(char_model)
        }
        // Unload the gif player, which handles its own internal texture and image
        g.gif_player_unload(&gif_player)

        rl.CloseAudioDevice()
        rl.CloseWindow()
    }

    // --- Load Assets ---

    // Try to load background music (optional)
    if rl.FileExists("assets/bg.mp3") {
        background_music = rl.LoadMusicStream("assets/bg.mp3")
        if background_music.ctxData != nil {
            music_loaded = true
            rl.PlayMusicStream(background_music)
        }
    }
    
    // Load background GIF using the GifPlayer
    gif_player = g.gif_player_create()
    if rl.FileExists("assets/bg.gif") {
        if g.gif_player_load(&gif_player, "assets/bg.gif") {
            // Scale the GIF to cover the entire screen
            dest_rect := rl.Rectangle{0, 0, f32(screen_width), f32(screen_height)}
            g.gif_player_set_dest_rect(&gif_player, dest_rect)
        }
    }
    
    // Load models (optional)
    if rl.FileExists("assets/char.obj") {
        char_model = rl.LoadModel("assets/char.obj")
        model_loaded = true
    }
    
    // --- Game State Initialization ---
    
    // Set up Camera
    camera := rl.Camera3D{
        position   = {-11, 10, 10},
        target     = {0, 0, 0},
        up         = {0, 1, 0}, // Y is up
        fovy       = 45,
        projection = .PERSPECTIVE,
    }
    
    camera_speed: f32 = 0.2
    player_speed: f32 = 1.0
    
    battling := false
    
    char_pos := rl.Vector2{1, 1}
    emn_pos := rl.Vector2{8, 6}
    
    // --- GAME LOOP ---
    for !rl.WindowShouldClose() {
        
        // --- UPDATE ---

        if rl.IsKeyPressed(.SPACE) {
            battling = false // failsafe to stop battle
        }
        
        // Update the game state if not in a battle
        if !battling {
            if music_loaded {
                rl.UpdateMusicStream(background_music)
            }
            
            // Update background animation using the GifPlayer
            g.gif_player_update(&gif_player)
            
            // --- Input Handling ---
            
            // Camera zoom
            if rl.IsKeyDown(.Q) {
                camera.position.y += camera_speed
            }
            if rl.IsKeyDown(.W) {
                camera.position.y -= camera_speed
            }

            // Player movement
            char_movement_vector := rl.Vector2{0, 0}
            if rl.IsKeyPressed(.LEFT)  { char_movement_vector.x = -player_speed }
            if rl.IsKeyPressed(.RIGHT) { char_movement_vector.x =  player_speed }
            if rl.IsKeyPressed(.UP)    { char_movement_vector.y = -player_speed }
            if rl.IsKeyPressed(.DOWN)  { char_movement_vector.y =  player_speed }
            
            // --- State Update ---
            if char_movement_vector.x != 0 || char_movement_vector.y != 0 {
                new_char_pos := rl.Vector2{
                    char_pos.x + char_movement_vector.x,
                    char_pos.y + char_movement_vector.y,
                }
                
                // Check if the new position is valid and on a floor tile
                if check_floor_tile(new_char_pos) {
                    // Check for collision with the enemy
                    if new_char_pos.x == emn_pos.x && new_char_pos.y == emn_pos.y {
                        battling = true
                    } else {
                        char_pos = new_char_pos
                    }
                }
            }
            
            // Make the camera follow the player
            camera.target = rl.Vector3{char_pos.x, z_offset, char_pos.y}
        }
        
        // --- DRAW ---
        rl.BeginDrawing()
        
        // Clear background to a solid color first
        rl.ClearBackground(rl.BLACK)
        
        // Draw the 2D background GIF
        g.gif_player_draw(&gif_player)
        
        // Render the 3D scene
        rl.BeginMode3D(camera)
        
        // Draw characters, using placeholders if models failed to load
        if model_loaded {
            rl.DrawModel(char_model, rl.Vector3{char_pos.x, z_offset, char_pos.y}, 1.0, rl.BEIGE)
            rl.DrawModel(char_model, rl.Vector3{emn_pos.x, z_offset, emn_pos.y}, 1.0, rl.RED)
        } else {
            rl.DrawCube(rl.Vector3{char_pos.x, z_offset, char_pos.y}, 0.8, 1.0, 0.8, rl.BEIGE)
            rl.DrawCube(rl.Vector3{emn_pos.x, z_offset, emn_pos.y}, 0.8, 1.0, 0.8, rl.RED)
        }
        
        // Draw the map and coordinate axes
        draw_map()
        draw_axis_lines()
        
        rl.EndMode3D()
        
        // --- Draw UI / Overlays ---

        // Draw battle window if active
        if battling {
            // Draw a semi-transparent overlay
            rl.DrawRectangle(0, 0, screen_width, screen_height, rl.Color{0, 0, 0, 150})
            // Draw the battle box
            rl.DrawRectangleV(
                rl.Vector2{f32(screen_width) / 2 - f32(screen_width) / 4, f32(screen_height) / 2 - f32(screen_height) / 4},
                rl.Vector2{f32(screen_width) / 2, f32(screen_height) / 2},
                rl.Color{0, 50, 100, 255},
            )
             rl.DrawText("BATTLE!", i32(f32(screen_width)/2) - 100, i32(f32(screen_height)/2) - 20, 40, rl.WHITE)
        }
        
        // Draw debug info text
        pos_text := fmt.ctprintf("Char: ({:.1f}, {:.1f}) | Enemy: ({:.1f}, {:.1f})", char_pos.x, char_pos.y, emn_pos.x, emn_pos.y)
        rl.DrawText(pos_text, 10, 10, 20, rl.WHITE)
        rl.DrawText("Arrow keys: Move | Q/W: Cam zoom | Space: Exit battle", 10, 35, 16, rl.WHITE)
        
        rl.EndDrawing()
    }
}
