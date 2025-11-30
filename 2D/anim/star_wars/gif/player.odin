package gif

import "core:c"
import "core:fmt"

import rl "vendor:raylib"

MAX_FRAME_DELAY :: 20
MIN_FRAME_DELAY :: 1
DEFAULT_FRAME_DELAY :: 8

// GIF Player component state
GifPlayer :: struct {
    // Image and texture data
    image: rl.Image,
    texture: rl.Texture2D,
    
    // Animation properties
    total_frames: c.int,
    current_frame: int,
    frame_delay: int,
    frame_counter: int,
    
    // Display properties
    source_rect: rl.Rectangle,
    dest_rect: rl.Rectangle,
    origin: rl.Vector2,
    rotation: f32,
    tint: rl.Color,
    
    // State flags
    is_loaded: bool,
    is_playing: bool,
    loop: bool,
}

// Create a new GIF player instance
player_create :: proc() -> GifPlayer {
    return GifPlayer{
        frame_delay = DEFAULT_FRAME_DELAY,
        rotation = 0,
        tint = rl.WHITE,
        is_playing = true,
        loop = true,
    }
}

// Load a GIF file into the player
player_load :: proc(player: ^GifPlayer, filepath: cstring) -> bool {
    // Clean up existing resources if any
    if player.is_loaded {
        player_unload(player)
    }
    
    // Load GIF animation frames
    player.image = rl.LoadImageAnim(filepath, &player.total_frames)
    if player.image.data == nil {
        rl.TraceLog(.WARNING, fmt.ctprintf("GIF file '%s' could not be loaded.", filepath))
        return false
    }
    
    // Load texture from first frame
    player.texture = rl.LoadTextureFromImage(player.image)
    
    // Set up source rectangle (full image size)
    player.source_rect = rl.Rectangle{
        x = 0, 
        y = 0, 
        width = f32(player.texture.width), 
        height = f32(player.texture.height)
    }
    
    // Reset animation state
    player.current_frame = 0
    player.frame_counter = 0
    player.is_loaded = true
    
    return true
}

// Update the GIF player animation
player_update :: proc(player: ^GifPlayer) {
    if !player.is_loaded || !player.is_playing {
        return
    }
    
    player.frame_counter += 1
    
    // Check if it's time to advance to the next frame
    if player.frame_counter >= player.frame_delay {
        player.frame_counter = 0
        player.current_frame += 1
        
        // Handle looping or stopping at the end
        if player.current_frame >= int(player.total_frames) {
            if player.loop {
                player.current_frame = 0
            } else {
                player.current_frame = int(player.total_frames) - 1
                player.is_playing = false
            }
        }
        
        // Update texture with current frame data
        _update_texture_frame(player)
    }
}

// Set the destination rectangle for drawing
player_set_dest_rect :: proc(player: ^GifPlayer, dest: rl.Rectangle) {
    player.dest_rect = dest
}

// Set the origin point for rotation and scaling
player_set_origin :: proc(player: ^GifPlayer, origin: rl.Vector2) {
    player.origin = origin
}

// Set rotation angle in degrees
player_set_rotation :: proc(player: ^GifPlayer, rotation: f32) {
    player.rotation = rotation
}

// Set tint color
player_set_tint :: proc(player: ^GifPlayer, tint: rl.Color) {
    player.tint = tint
}

// Control playback
player_play :: proc(player: ^GifPlayer) {
    player.is_playing = true
}

player_pause :: proc(player: ^GifPlayer) {
    player.is_playing = false
}

player_stop :: proc(player: ^GifPlayer) {
    player.is_playing = false
    player.current_frame = 0
    player.frame_counter = 0
    if player.is_loaded {
        _update_texture_frame(player)
    }
}

// Set animation speed (frame delay)
player_set_speed :: proc(player: ^GifPlayer, frame_delay: int) {
    player.frame_delay = clamp(frame_delay, MIN_FRAME_DELAY, MAX_FRAME_DELAY)
}

// Get current playback information
player_get_current_frame :: proc(player: ^GifPlayer) -> int {
    return player.current_frame
}

player_get_total_frames :: proc(player: ^GifPlayer) -> int {
    return int(player.total_frames)
}

player_get_fps :: proc(player: ^GifPlayer) -> int {
    return 60 / player.frame_delay
}

player_is_playing :: proc(player: ^GifPlayer) -> bool {
    return player.is_playing
}

// Draw the GIF player
player_draw :: proc(player: ^GifPlayer) {
    if !player.is_loaded {
        return
    }
    rl.DrawTexturePro(
        player.texture,
        player.source_rect,
        player.dest_rect,
        player.origin,
        player.rotation,
        player.tint
    )
}

// Clean up resources
player_unload :: proc(player: ^GifPlayer) {
    if player.is_loaded {
        rl.UnloadTexture(player.texture)
        rl.UnloadImage(player.image)
        player.is_loaded = false
    }
}

// Private helper to update texture with current frame data
_update_texture_frame :: proc(player: ^GifPlayer) {
    if !player.is_loaded {
        return
    }
    
    // Calculate frame size in bytes (RGBA = 4 bytes per pixel)
    frame_size_bytes := player.image.width * player.image.height * 4
    
    // Calculate offset to current frame data
    offset := uintptr(frame_size_bytes) * uintptr(player.current_frame)
    
    // Get pointer to current frame data
    frame_data_ptr := rawptr(cast(uintptr)player.image.data + offset)
    
    // Update GPU texture
    rl.UpdateTexture(player.texture, frame_data_ptr)
}