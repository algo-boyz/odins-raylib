package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

MAP_TILE_SIZE :: 32         // Tiles size 32x32 pixels
PLAYER_SIZE :: 16           // Player size
PLAYER_TILE_VISIBILITY :: 2 // Player can see 2 tiles around its position

// Map data type
Map :: struct {
    tiles_x: u32,          // Number of tiles in X axis
    tiles_y: u32,          // Number of tiles in Y axis
    tile_ids: []u8,        // Tile ids (tiles_x*tiles_y), defines type of tile to draw
    tile_fog: []u8,        // Tile fog state (tiles_x*tiles_y), defines if a tile has fog or half-fog
}

main :: proc() {
    rl.InitWindow(800, 450, "Fog of war")

    m: Map
    m.tiles_x = 25
    m.tiles_y = 15

    // NOTE: We can have up to 256 values for tile ids and for tile fog state,
    // probably we don't need that many values for fog state, it can be optimized
    // to use only 2 bits per fog state (reducing size by 4) but logic will be a bit more complex
    m.tile_ids = make([]u8, m.tiles_x * m.tiles_y)
    m.tile_fog = make([]u8, m.tiles_x * m.tiles_y)

    // Load map tiles (generating 2 random tile ids for testing)
    // NOTE: Map tile ids should be probably loaded from an external map file
    for i := 0; i < int(m.tiles_y * m.tiles_x); i += 1 {
        m.tile_ids[i] = u8(rand.int_max(2))
    }

    // Player position on the screen (pixel coordinates, not tile coordinates)
    player_position := rl.Vector2{180, 130}
    player_tile_x := 0
    player_tile_y := 0

    // Render texture to render fog of war
    // NOTE: To get an automatic smooth-fog effect we use a render texture to render fog
    // at a smaller size (one pixel per tile) and scale it on drawing with bilinear filtering
    fog_of_war := rl.LoadRenderTexture(i32(m.tiles_x), i32(m.tiles_y))
    rl.SetTextureFilter(fog_of_war.texture, .BILINEAR)
    
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        // Move player around
        if rl.IsKeyDown(.RIGHT) do player_position.x += 5
        if rl.IsKeyDown(.LEFT) do player_position.x -= 5
        if rl.IsKeyDown(.DOWN) do player_position.y += 5
        if rl.IsKeyDown(.UP) do player_position.y -= 5

        // Check player position to avoid moving outside tilemap limits
        if player_position.x < 0 {
            player_position.x = 0
        } else if (player_position.x + PLAYER_SIZE) > (f32(m.tiles_x) * MAP_TILE_SIZE) {
            player_position.x = f32(m.tiles_x) * MAP_TILE_SIZE - PLAYER_SIZE
        }
        
        if player_position.y < 0 {
            player_position.y = 0
        } else if (player_position.y + PLAYER_SIZE) > (f32(m.tiles_y) * MAP_TILE_SIZE) {
            player_position.y = f32(m.tiles_y) * MAP_TILE_SIZE - PLAYER_SIZE
        }

        // Previous visited tiles are set to partial fog
        for i := 0; i < int(m.tiles_x * m.tiles_y); i += 1 {
            if m.tile_fog[i] == 1 do m.tile_fog[i] = 2
        }
        
        // Get current tile position from player pixel position
        player_tile_x = int((player_position.x + MAP_TILE_SIZE/2) / MAP_TILE_SIZE)
        player_tile_y = int((player_position.y + MAP_TILE_SIZE/2) / MAP_TILE_SIZE)

        // Check visibility and update fog
        // NOTE: We check tilemap limits to avoid processing tiles out-of-array-bounds (it could crash program)
        for y := (player_tile_y - PLAYER_TILE_VISIBILITY); y < (player_tile_y + PLAYER_TILE_VISIBILITY); y += 1 {
            for x := (player_tile_x - PLAYER_TILE_VISIBILITY); x < (player_tile_x + PLAYER_TILE_VISIBILITY); x += 1 {
                if (x >= 0) && (x < int(m.tiles_x)) && (y >= 0) && (y < int(m.tiles_y)) {
                    m.tile_fog[y * int(m.tiles_x) + x] = 1
                }
            }
        }
        // Draw fog of war to a small render texture for automatic smoothing on scaling
        rl.BeginTextureMode(fog_of_war)
            rl.ClearBackground(rl.BLANK)
            for y := 0; y < int(m.tiles_y); y += 1 {
                for x := 0; x < int(m.tiles_x); x += 1 {
                    if m.tile_fog[y * int(m.tiles_x) + x] == 0 {
                        rl.DrawRectangle(i32(x), i32(y), 1, 1, rl.BLACK)
                    } else if m.tile_fog[y * int(m.tiles_x) + x] == 2 {
                        rl.DrawRectangle(i32(x), i32(y), 1, 1, rl.Fade(rl.BLACK, 0.8))
                    }
                }
            }
        rl.EndTextureMode()

        rl.BeginDrawing()
            rl.ClearBackground(rl.RAYWHITE)

            for y := 0; y < int(m.tiles_y); y += 1 {
                for x := 0; x < int(m.tiles_x); x += 1 {
                    // Draw tiles from id (and tile borders)
                    if m.tile_ids[y * int(m.tiles_x) + x] == 0 {
                        rl.DrawRectangle(i32(x * MAP_TILE_SIZE), i32(y * MAP_TILE_SIZE), 
                                        MAP_TILE_SIZE, MAP_TILE_SIZE, rl.BLUE)
                    } else {
                        rl.DrawRectangle(i32(x * MAP_TILE_SIZE), i32(y * MAP_TILE_SIZE), 
                                        MAP_TILE_SIZE, MAP_TILE_SIZE, rl.Fade(rl.BLUE, 0.9))
                    }
                    rl.DrawRectangleLines(i32(x * MAP_TILE_SIZE), i32(y * MAP_TILE_SIZE), 
                                         MAP_TILE_SIZE, MAP_TILE_SIZE, rl.Fade(rl.DARKBLUE, 0.5))
                }
            }
            // Draw player
            rl.DrawRectangleV(player_position, rl.Vector2{PLAYER_SIZE, PLAYER_SIZE}, rl.RED)

            // Draw fog of war (scaled to full map, bilinear filtering)
            rl.DrawTexturePro(
                fog_of_war.texture, 
                rl.Rectangle{0, 0, f32(fog_of_war.texture.width), f32(-fog_of_war.texture.height)},
                rl.Rectangle{0, 0, f32(m.tiles_x * MAP_TILE_SIZE), f32(m.tiles_y * MAP_TILE_SIZE)},
                rl.Vector2{0, 0}, 
                0.0, 
                rl.WHITE
            )
            // Draw player current tile
            rl.DrawText(fmt.ctprintf("Current tile: [%i,%i]", player_tile_x, player_tile_y), 10, 10, 20, rl.RAYWHITE)
            rl.DrawText("ARROW KEYS to move", 10, 425, 20, rl.RAYWHITE)

        rl.EndDrawing()
    }
    // Clean up resources
    delete(m.tile_ids)
    delete(m.tile_fog)
    rl.UnloadRenderTexture(fog_of_war)
    rl.CloseWindow()
}