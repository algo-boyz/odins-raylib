package main

import rl "vendor:raylib"

GLSL_VERSION :: 330
MAP_TILE_SIZE :: 32
PLAYER_SIZE :: 16
PLAYER_TILE_VISIBILITY :: 2

Map :: struct {
    tiles_x: u32,
    tiles_y: u32,
    tile_ids: []u8,
    tile_fog: []u8,
}

main :: proc() {
    screen_width :i32 = 800
    screen_height :i32 = 450
    
    rl.InitWindow(screen_width, screen_height, "Odin + Raylib - Color Mix Shader")
    defer rl.CloseWindow()
    
    // Initialize map
    tile_map := Map{
        tiles_x = 25,
        tiles_y = 15,
        tile_ids = make([]u8, 25 * 15),
        tile_fog = make([]u8, 25 * 15),
    }
    defer delete(tile_map.tile_ids)
    defer delete(tile_map.tile_fog)
    
    // Create two render textures for the mix effect
    base_color := rl.GenImageColor(screen_width, screen_height, rl.BLUE)
    tex_base := rl.LoadTextureFromImage(base_color)
    rl.UnloadImage(base_color)
    defer rl.UnloadTexture(tex_base)
    
    fog_color := rl.GenImageColor(screen_width, screen_height, rl.BLACK)
    tex_fog := rl.LoadTextureFromImage(fog_color)
    rl.UnloadImage(fog_color)
    defer rl.UnloadTexture(tex_fog)
    
    // Load and setup shader
    shader := rl.LoadShader("", "assets/color_mix.fs")
    defer rl.UnloadShader(shader)
    
    // Get shader locations
    tex_fog_loc := rl.GetShaderLocation(shader, "texture1")
    divider_loc := rl.GetShaderLocation(shader, "divider")
    divider_value: f32 = 0.5
    
    // Player position (pixel coordinates)
    player_position := rl.Vector2{180, 130}
    player_tile_x := 0
    player_tile_y := 0
    
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        // Update player position
        if rl.IsKeyDown(.RIGHT) {
            player_position.x += 5
            divider_value += 0.01
        }
        if rl.IsKeyDown(.LEFT) {
            player_position.x -= 5
            divider_value -= 0.01
        }
        if rl.IsKeyDown(.DOWN) do player_position.y += 5
        if rl.IsKeyDown(.UP) do player_position.y -= 5
        
        // Clamp values
        player_position.x = clamp(player_position.x, 0, f32(tile_map.tiles_x) * MAP_TILE_SIZE - PLAYER_SIZE)
        player_position.y = clamp(player_position.y, 0, f32(tile_map.tiles_y) * MAP_TILE_SIZE - PLAYER_SIZE)
        divider_value = clamp(divider_value, 0, 1)
        
        // Calculate current tile position
        player_tile_x = int(player_position.x + f32(MAP_TILE_SIZE)/2) / MAP_TILE_SIZE
        player_tile_y = int(player_position.y + f32(MAP_TILE_SIZE)/2) / MAP_TILE_SIZE
        
        // Update shader value
        rl.SetShaderValue(shader, divider_loc, &divider_value, .FLOAT)
        
        // Draw
        rl.BeginDrawing()
        {
            rl.ClearBackground(rl.RAYWHITE)
            
            rl.BeginShaderMode(shader)
            {
                // Set the second texture for mixing
                rl.SetShaderValueTexture(shader, tex_fog_loc, tex_fog)
                
                // Draw the base texture which will be mixed with the fog texture
                rl.DrawTexture(tex_base, 0, 0, rl.WHITE)
            }
            rl.EndShaderMode()
            
            // Draw player
            rl.DrawRectangleV(
                player_position, 
                rl.Vector2{PLAYER_SIZE, PLAYER_SIZE}, 
                rl.RED,
            )
            
            // Draw UI
            rl.DrawText(
                rl.TextFormat("Current tile: [%d,%d]", player_tile_x, player_tile_y), 
                10, 
                10, 
                20, 
                rl.WHITE,
            )
            rl.DrawText(
                "LEFT/RIGHT to move transition", 
                10, 
                i32(screen_height - 25), 
                20, 
                rl.WHITE,
            )
            rl.DrawText(
                rl.TextFormat("Divider: %.2f", divider_value),
                10,
                40,
                20,
                rl.WHITE,
            )
        }
        rl.EndDrawing()
    }
}

clamp :: proc(value, min, max: f32) -> f32 {
    if value < min do return min
    if value > max do return max
    return value
}