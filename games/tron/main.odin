package tron

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Game Constants
SCREEN_WIDTH     :: 1000
SCREEN_HEIGHT    :: 1000
PLAYER_SPEED     :: 4.0
TRAIL_WIDTH      :: 4.0
AI_LOOKAHEAD     :: 15

// Neon Colors for Glow Effect
NEON_RED         :: rl.Color{255, 20, 50, 255}
NEON_BLUE        :: rl.Color{20, 200, 255, 255}
NEON_GREEN       :: rl.Color{57, 255, 20, 255}
NEON_WHITE       :: rl.Color{240, 240, 240, 255}

// Data Structures

Triangle :: struct {
    width:     f32,
    height:    f32,
    rotation:  f32,
    vertex:    [3]rl.Vector2,
}

Player :: struct {
    position:      rl.Vector2,
    triangle:      Triangle,
    color:         rl.Color,
    is_dead:       bool,
    score:         i32,
    trail:         [10000]rl.Vector2,
    trail_length:  int,
    keys:          struct { up, down, left, right: rl.KeyboardKey },
}

Game_State :: enum {
    MENU,
    GAMEPLAY,
    GAME_OVER,
}

Game_Mode :: enum {
    TWO_PLAYER,
    PLAYER_VS_AI,
}

// Global Game State
game_state:       Game_State
game_mode:        Game_Mode
player1:          Player
player2:          Player
texture:          rl.Texture2D
logo_rotation:    f32
font:             rl.Font
// New globals for shader and music
shader:           rl.Shader
render_target:    rl.RenderTexture2D
music:            rl.Music

main :: proc() {
    // Window configuration
    rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_HIGHDPI})
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tron")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    // NEW: Initialize Audio and Load Music
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    music = rl.LoadMusicStream("assets/tron_music.mp3") // CHANGE FILENAME IF NEEDED
    rl.SetMusicVolume(music, 0.5)
    rl.PlayMusicStream(music)
    defer rl.UnloadMusicStream(music)

    // Load custom font
    font = rl.LoadFontEx("assets/tr2n.ttf", 22, nil, 0)
    defer rl.UnloadFont(font)
    rl.SetTextureFilter(font.texture, .BILINEAR)
    rl.SetTextLineSpacing(12)
    
    // NEW: Load Shader and Render Target
    // Load the glow shader. The `fs_file_name` parameter is for fragment shaders.
    shader = rl.LoadShader(nil, "assets/glow.fs")
    defer rl.UnloadShader(shader)

    // Create a texture to render the whole game to
    render_target = rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
    defer rl.UnloadRenderTexture(render_target)


    // Load resources
    image := rl.LoadImage("assets/tron.png")
    if image.data != nil {
        texture = rl.LoadTextureFromImage(image)
        rl.UnloadImage(image)
        defer rl.UnloadTexture(texture)
    } else {
        fmt.println("Warning: Could not load texture 'assets/tron.png'.")
    }

    // Set initial game state
    game_state = .MENU
    init_players()

    // Main game loop
    for !rl.WindowShouldClose() {
        // NEW: Update Music Stream
        rl.UpdateMusicStream(music)

        // RENDER TO TEXTURE
        // All drawing now happens inside this block, targeting our off-screen texture
        rl.BeginTextureMode(render_target)
            rl.ClearBackground(rl.BLACK)
            update_controller()
        rl.EndTextureMode()

        // RENDER TO SCREEN with SHADER
        rl.BeginDrawing()
            rl.ClearBackground(rl.BLACK) // Clear the actual window background
            // Apply the glow shader
            rl.BeginShaderMode(shader)
                // Draw the texture we rendered our game to.
                // NOTE: The negative height in the source rectangle is to flip the texture
                // because of how OpenGL (used by shaders) and Raylib handle Y-coordinates.
                source_rect := rl.Rectangle{0, 0, f32(render_target.texture.width), -f32(render_target.texture.height)}
                dest_rect := rl.Rectangle{0, 0, f32(SCREEN_WIDTH), f32(SCREEN_HEIGHT)}
                rl.DrawTextureRec(render_target.texture, source_rect, rl.Vector2{0, 0}, rl.WHITE)
            rl.EndShaderMode()
        rl.EndDrawing()
    }
}

// Game State & Control Flow

// Manages the game's current state (menu, gameplay, game over)
update_controller :: proc() {
    switch game_state {
    case .MENU:
        draw_menu()
        if rl.IsKeyPressed(.ONE) {
            game_mode = .PLAYER_VS_AI
            game_state = .GAMEPLAY
            reset_round()
        }
        if rl.IsKeyPressed(.TWO) {
            game_mode = .TWO_PLAYER
            game_state = .GAMEPLAY
            reset_round()
        }
    case .GAMEPLAY:
        update_game_stage()
    case .GAME_OVER:
        draw_game_over()
        if rl.IsKeyPressed(.R) {
            reset_round()
            game_state = .GAMEPLAY
        }
    }
}

draw_menu :: proc() {
    logo_rotation += 0.2
    draw_text_with_glow(font, "TRON", rl.Vector2{220, 350}, 100, 10, NEON_RED)
    // Using neon colors for the menu text
    draw_text_with_glow(font, "1: 1 vs AI", rl.Vector2{250, 500}, 40, 10, NEON_GREEN)
    draw_text_with_glow(font, "2: 1 vs 1", rl.Vector2{250, 560}, 40, 10, NEON_GREEN)
}

draw_game_over :: proc() {
    switch {
    case player1.is_dead && player2.is_dead:
        draw_text_with_glow(font, "Both players crashed!", rl.Vector2{250, 400}, 40, 10, NEON_WHITE)
    case player1.is_dead:
        winner_text := game_mode == .PLAYER_VS_AI ? "AI wins!" : "Player 2 WINS!"
        draw_text_with_glow(font, fmt.ctprintf("%s", winner_text), rl.Vector2{400, 400}, 40, 10, NEON_BLUE)
    case player2.is_dead:
        draw_text_with_glow(font, "Player 1 WINS!", rl.Vector2{340, 400}, 40, 10, NEON_RED)
    }
    
    draw_text_with_glow(font, fmt.ctprintf("P1 Score: %d", player1.score), rl.Vector2{400, 500}, 30, 10, NEON_RED)
    draw_text_with_glow(font, fmt.ctprintf("P2 Score: %d", player2.score), rl.Vector2{400, 550}, 30, 10, NEON_BLUE)
    draw_text_with_glow(font, "Press 'R' for Replay", rl.Vector2{280, 650}, 30, 10, NEON_WHITE)
}

draw_text_with_glow :: proc(font: rl.Font, text: cstring, position: rl.Vector2, font_size: f32, spacing: f32, color: rl.Color) {
    // Draw a blurry background for the text by drawing it multiple times with offsets and transparency.
    // This gives the main glow shader something to work with.
    rl.DrawTextEx(font, text, position + rl.Vector2{1, 1}, font_size, spacing, rl.Fade(color, 0.5))
    rl.DrawTextEx(font, text, position + rl.Vector2{-1, -1}, font_size, spacing, rl.Fade(color, 0.4))
    rl.DrawTextEx(font, text, position + rl.Vector2{1, -1}, font_size, spacing, rl.Fade(color, 0.3))
    rl.DrawTextEx(font, text, position + rl.Vector2{-1, 1}, font_size, spacing, rl.Fade(color, 0.2))

    // Draw the main, sharp text on top.
    rl.DrawTextEx(font, text, position, font_size, spacing, color)
}

update_game_stage :: proc() {
    move_player(&player1)
    switch game_mode {
    case .TWO_PLAYER:   move_player(&player2)
    case .PLAYER_VS_AI: move_ai(&player2)
    }
    check_all_collisions()

    if player1.is_dead || player2.is_dead {
        if player1.is_dead && player2.is_dead {
            player1.score += 1
            player2.score += 1
        } else if player1.is_dead {
            player2.score += 1
        } else if player2.is_dead {
            player1.score += 1
        }
        game_state = .GAME_OVER
    }
    
    render_game()
    // Using neon colors for scores
    draw_text_with_glow(font, fmt.ctprintf("P1 Score: %d", player1.score), rl.Vector2{20, 10}, 30, 10, NEON_RED)
    draw_text_with_glow(font, fmt.ctprintf("P2 Score: %d", player2.score), rl.Vector2{SCREEN_WIDTH - 320, 10}, 30, 10, NEON_BLUE)
}

init_players :: proc() {
    player1 = {
        position      = {SCREEN_WIDTH * 0.5, SCREEN_HEIGHT * 0.2},
        triangle      = {width = 30, height = 15, rotation = 90},
        color         = NEON_RED,
        keys          = {.W, .S, .A, .D},
        score         = 0,
    }
    player2 = {
        position      = {SCREEN_WIDTH * 0.5, SCREEN_HEIGHT * 0.8},
        triangle      = {width = 30, height = 15, rotation = 270},
        color         = NEON_BLUE,
        keys          = {.UP, .DOWN, .LEFT, .RIGHT},
        score         = 0,
    }
}

reset_round :: proc() {
    // Reset Player 1's state for the new round
    player1.position       = {SCREEN_WIDTH * 0.5, SCREEN_HEIGHT * 0.2}
    player1.triangle.rotation = 90
    player1.is_dead        = false
    player1.trail_length   = 0

    // Reset Player 2's state for the new round
    player2.position       = {SCREEN_WIDTH * 0.5, SCREEN_HEIGHT * 0.8}
    player2.triangle.rotation = 270
    player2.is_dead        = false
    player2.trail_length   = 0
}

// Updates a player's position based on key presses
move_player :: proc(player: ^Player) {
    // Determine current movement axis
    // Rotation 0, 180 -> horizontal. Rotation 90, 270 -> vertical.
    is_moving_horizontal := player.triangle.rotation == 0 || player.triangle.rotation == 180

    // Handle Input
    // Only allow turns, not reversing or stopping
    if rl.IsKeyDown(player.keys.up) && is_moving_horizontal {
        player.triangle.rotation = 270
    } else if rl.IsKeyDown(player.keys.down) && is_moving_horizontal {
        player.triangle.rotation = 90
    } else if rl.IsKeyDown(player.keys.left) && !is_moving_horizontal {
        player.triangle.rotation = 180
    } else if rl.IsKeyDown(player.keys.right) && !is_moving_horizontal {
        player.triangle.rotation = 0
    }

    // Update Position
    move_forward(player)
    save_player_pos(player)
}

// Core AI logic to decide the next move
move_ai :: proc(ai: ^Player) {
    // Get Potential Moves
    current_rotation := ai.triangle.rotation
    
    // Calculate rotations for left and right turns
    // The modulo arithmetic ensures the rotation wraps around correctly (e.g., 270 + 90 = 360 -> 0)
    left_turn_rotation  := f32(math.floor_mod(i64(current_rotation) - 90, 360))
    right_turn_rotation := f32(math.floor_mod(i64(current_rotation) + 90, 360))

    // Check if Paths are Safe
    // Check if the path directly ahead is blocked
    is_forward_safe := !is_path_colliding(ai, current_rotation, AI_LOOKAHEAD)
    
    if !is_forward_safe {
        // If the way forward is blocked, check the side paths
        is_left_safe  := !is_path_colliding(ai, left_turn_rotation,  AI_LOOKAHEAD)
        is_right_safe := !is_path_colliding(ai, right_turn_rotation, AI_LOOKAHEAD)

        // Decision Making
        if is_left_safe && is_right_safe {
            // If both turns are safe, pick one randomly
            ai.triangle.rotation = rand.int31_max(1) == 0 ? left_turn_rotation : right_turn_rotation
        } else if is_left_safe {
            ai.triangle.rotation = left_turn_rotation
        } else if is_right_safe {
            ai.triangle.rotation = right_turn_rotation
        }
        // If no path is safe, the AI doesn't turn and will crash.
    }

    // Update Position
    move_forward(ai)
    save_player_pos(ai)
}

// Moves a player forward based on their current rotation
move_forward :: proc(player: ^Player) {
    switch player.triangle.rotation {
    case 0:   player.position.x += PLAYER_SPEED // Right
    case 90:  player.position.y += PLAYER_SPEED // Down
    case 180: player.position.x -= PLAYER_SPEED // Left
    case 270: player.position.y -= PLAYER_SPEED // Up
    }
}

// Stores the player's current position to create a trail
save_player_pos :: proc(player: ^Player) {
    if player.trail_length < len(player.trail) {
        player.trail[player.trail_length] = player.position
        player.trail_length += 1
    }
}

// Rendering & Collision

// Main render call: draws players, trails, and checks for collisions
render_game :: proc() {
    // Define the shape of the triangles before drawing
    define_triangle_shape(&player1)
    define_triangle_shape(&player2)

    // Draw the players
    rl.DrawTriangle(player1.triangle.vertex[0], player1.triangle.vertex[1], player1.triangle.vertex[2], player1.color)
    rl.DrawTriangle(player2.triangle.vertex[0], player2.triangle.vertex[1], player2.triangle.vertex[2], player2.color)

    // Draw the trails
    draw_trail(&player1)
    draw_trail(&player2)
}

// Calculates the vertex positions of a player's triangle based on its rotation
define_triangle_shape :: proc(player: ^Player) {
    p_center := player.position
    p_width  := player.triangle.width
    p_height := player.triangle.height

    // Define the triangle shape around the origin {0,0}
    p1 := rl.Vector2{p_center.x + p_width / 2, p_center.y}
    p2 := rl.Vector2{p_center.x - p_width / 2, p_center.y - p_height / 2}
    p3 := rl.Vector2{p_center.x - p_width / 2, p_center.y + p_height / 2}

    // Rotate points around the player's center
    player.triangle.vertex[0] = rotate_point(p1, p_center, player.triangle.rotation)
    player.triangle.vertex[1] = rotate_point(p2, p_center, player.triangle.rotation)
    player.triangle.vertex[2] = rotate_point(p3, p_center, player.triangle.rotation)
}

// Renders a player's trail with proper thickness
draw_trail :: proc(player: ^Player) {
    // Use DrawLineEx to create a thick trail, which matches the collision logic
    if player.trail_length > 1 {
        for i in 0 ..< player.trail_length - 1 {
            rl.DrawLineEx(player.trail[i], player.trail[i+1], TRAIL_WIDTH, player.color)
        }
    }
}

// Collision Detection

check_all_collisions :: proc() {
    if !player1.is_dead {
        player1.is_dead = is_colliding(&player1, &player2)
    }
    if !player2.is_dead {
        player2.is_dead = is_colliding(&player2, &player1)
    }
}

// Checks if a player is colliding with anything (borders, trails, other player)
is_colliding :: proc(aggressor: ^Player, victim: ^Player) -> bool {
    head_pos := aggressor.triangle.vertex[0]

    // 1. Border Collisions
    if head_pos.x > SCREEN_WIDTH || head_pos.y > SCREEN_HEIGHT || head_pos.x < 0 || head_pos.y < 0 {
        return true
    }

    // 2. Player-vs-Player Collision (Triangle intersection)
    for i in 0 ..< 3 {
        if rl.CheckCollisionPointTriangle(head_pos, victim.triangle.vertex[0], victim.triangle.vertex[1], victim.triangle.vertex[2]) {
            return true
        }
    }

    // 3. Trail Collisions (Self and other)
    // Using a more robust circle check instead of direct equality
    // Check against victim's trail
    // Start loop a bit ahead to avoid colliding with the trail right at the start of the bike
    trail_check_start_index := game_mode == .PLAYER_VS_AI ? 10 : 1
    if victim.trail_length > trail_check_start_index {
        for i in 0 ..< victim.trail_length - trail_check_start_index {
            if rl.CheckCollisionPointCircle(head_pos, victim.trail[i], TRAIL_WIDTH / 2) {
                return true
            }
        }
    }

    // Check against own trail
    // The offset `-20` prevents instant death upon starting to move.
    if aggressor.trail_length > 20 {
        for i in 0 ..< aggressor.trail_length - 20 {
            if rl.CheckCollisionPointCircle(head_pos, aggressor.trail[i], TRAIL_WIDTH / 2) {
                return true
            }
        }
    }

    return false
}

// AI Helper: Checks if a projected path is safe
is_path_colliding :: proc(ai: ^Player, rotation: f32, distance: int) -> bool {
    // Get the direction vector for the given rotation
    direction: rl.Vector2
    switch rotation {
    case 0:   direction = {1, 0}
    case 90:  direction = {0, 1}
    case 180: direction = {-1, 0}
    case 270: direction = {0, -1}
    }

    // Check points along the path for collisions
    for i in 1 ..= distance {
        check_pos := ai.position + direction * f32(i) * PLAYER_SPEED
        
        // Check against borders
        if check_pos.x >= SCREEN_WIDTH || check_pos.y >= SCREEN_HEIGHT || check_pos.x <= 0 || check_pos.y <= 0 {
            return true
        }
        
        // Check against P1's trail
        for trail_point in player1.trail[:player1.trail_length] {
            if rl.CheckCollisionPointCircle(check_pos, trail_point, TRAIL_WIDTH) { return true }
        }
        
        // Check against its own trail (avoiding the very recent parts)
        if ai.trail_length > 20 {
            for trail_point in ai.trail[:ai.trail_length-20] {
                if rl.CheckCollisionPointCircle(check_pos, trail_point, TRAIL_WIDTH) { return true }
            }
        }
    }

    return false
}

// Rotates a point around a given center
rotate_point :: proc(point, center: rl.Vector2, rotation_degrees: f32) -> rl.Vector2 {
    rad := rotation_degrees * (math.PI / 180.0)
    cos_r := math.cos(rad)
    sin_r := math.sin(rad)

    p := point - center
    
    rotated: rl.Vector2
    rotated.x = p.x * cos_r - p.y * sin_r + center.x
    rotated.y = p.x * sin_r + p.y * cos_r + center.y
    return rotated
}