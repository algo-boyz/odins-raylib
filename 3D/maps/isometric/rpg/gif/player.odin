package gif

import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

// Configuration constants
MAX_FRAME_DELAY :: 20
MIN_FRAME_DELAY :: 1
DEFAULT_FRAME_DELAY :: 8

// PlayerMode determines if the animation is from a single GIF or a directory of images
PlayerMode :: enum {
    GIF,
    Directory,
}

// GIF Player component state
GifPlayer :: struct {
    // Image and texture data
    image:           rl.Image,
    current_texture: rl.Texture2D,
    cached_textures: [dynamic]rl.Texture2D, // Used for directory mode

    // Animation properties
    total_frames:  c.int,
    current_frame: int,
    frame_delay:   int,
    frame_counter: int,

    // Display properties
    source_rect: rl.Rectangle,
    dest_rect:   rl.Rectangle,
    origin:      rl.Vector2,
    rotation:    f32,
    tint:        rl.Color,

    // State flags
    mode:       PlayerMode,
    is_loaded:  bool,
    is_playing: bool,
    loop:       bool,
}

// Create a new GIF player instance
gif_player_create :: proc() -> GifPlayer {
    return GifPlayer{
        frame_delay = DEFAULT_FRAME_DELAY,
        rotation    = 0,
        tint        = rl.WHITE,
        is_playing  = true,
        loop        = true,
    }
}

// Load a GIF file into the player
gif_player_load :: proc(player: ^GifPlayer, filepath: cstring) -> bool {
    if player.is_loaded {
        gif_player_unload(player)
    }

    player.image = rl.LoadImageAnim(filepath, &player.total_frames)
    if player.image.data == nil {
        rl.TraceLog(.WARNING, fmt.ctprintf("GIF file '%s' could not be loaded.", filepath))
        return false
    }

    player.current_texture = rl.LoadTextureFromImage(player.image)
    player.source_rect = rl.Rectangle{0, 0, f32(player.current_texture.width), f32(player.current_texture.height)}
    
    player.mode = .GIF
    player.current_frame = 0
    player.frame_counter = 0
    player.is_loaded = true

    return true
}

// [CORRECTED] Load an image sequence from a directory into the player
gif_player_load_from_dir :: proc(player: ^GifPlayer, dir_path: string) -> bool {
    if player.is_loaded {
        gif_player_unload(player)
    }

    // First, open the directory to get a handle
    dir_handle, err := os.open(dir_path)
    if err != 0 {
        rl.TraceLog(.WARNING, fmt.ctprintf("Could not open directory '%s'.", dir_path))
        return false
    }
    defer os.close(dir_handle)

    // Read all entries in the directory using the handle
    // The second argument (-1) tells it to read all entries.
    dir_entries, read_err := os.read_dir(dir_handle, -1)
    if read_err != 0 {
        rl.TraceLog(.WARNING, fmt.ctprintf("Could not read from directory '%s'.", dir_path))
        return false
    }
    // Use the special delete procedure to free the memory for each File_Info's fullpath
    defer os.file_info_slice_delete(dir_entries)

    // Filter for image files and store their paths
    image_filepaths := make([dynamic]string)
    defer delete(image_filepaths)

    for entry in dir_entries {
        // Use `!entry.is_dir` to check if the entry is a file
        if !entry.is_dir && _is_image_file(entry.name) {
            full_path := fmt.tprintf("%s/%s", dir_path, entry.name)
            append(&image_filepaths, full_path)
        }
    }

    if len(image_filepaths) == 0 {
        rl.TraceLog(.WARNING, fmt.ctprintf("No image files found in directory '%s'.", dir_path))
        return false
    }

    // Sort file paths alphabetically to ensure correct animation order
    slice.sort(image_filepaths[:])

    // Load all images as textures and cache them
    player.cached_textures = make([dynamic]rl.Texture2D, 0, len(image_filepaths))
    for path in image_filepaths {
        texture := rl.LoadTexture(strings.clone_to_cstring(path))
        if texture.id <= 0 {
            rl.TraceLog(.WARNING, fmt.ctprintf("Failed to load image texture: %s", path))
            continue
        }
        append(&player.cached_textures, texture)
    }

    if len(player.cached_textures) == 0 {
        rl.TraceLog(.WARNING, "Image loading failed for all files in directory.")
        return false
    }

    // Setup player state from cached textures
    player.total_frames = c.int(len(player.cached_textures))
    player.current_texture = player.cached_textures[0]
    player.source_rect = rl.Rectangle{0, 0, f32(player.current_texture.width), f32(player.current_texture.height)}

    player.mode = .Directory
    player.current_frame = 0
    player.frame_counter = 0
    player.is_loaded = true

    return true
}


// Update the GIF player animation
gif_player_update :: proc(player: ^GifPlayer) {
    if !player.is_loaded || !player.is_playing {
        return
    }

    player.frame_counter += 1

    if player.frame_counter >= player.frame_delay {
        player.frame_counter = 0
        player.current_frame += 1

        if player.current_frame >= int(player.total_frames) {
            if player.loop {
                player.current_frame = 0
            } else {
                player.current_frame = int(player.total_frames) - 1
                player.is_playing = false
            }
        }

        // Update texture with current frame data based on mode
        _update_current_texture(player)
    }
}

// Draw the GIF player
gif_player_draw :: proc(player: ^GifPlayer) {
    if !player.is_loaded {
        return
    }
    
    rl.DrawTexturePro(
        player.current_texture, // Use the current texture
        player.source_rect,
        player.dest_rect,
        player.origin,
        player.rotation,
        player.tint,
    )
}

// Clean up resources
gif_player_unload :: proc(player: ^GifPlayer) {
    if player.is_loaded {
        switch player.mode {
        case .GIF:
            rl.UnloadTexture(player.current_texture)
            rl.UnloadImage(player.image)
            player.is_loaded = false
        case .Directory:
            for texture in player.cached_textures {
                rl.UnloadTexture(texture)
            }
            delete(player.cached_textures)
            player.is_loaded = false
        }
    }
}


// Stop playback and reset to the first frame
gif_player_stop :: proc(player: ^GifPlayer) {
    player.is_playing = false
    player.current_frame = 0
    player.frame_counter = 0
    if player.is_loaded {
        _update_current_texture(player)
    }
}


// Private helper to update texture with current frame data
_update_current_texture :: proc(player: ^GifPlayer) {
    if !player.is_loaded {
        return
    }

    switch player.mode {
    case .GIF:
        // For GIFs, we update the texture data on the GPU
        // CORRECTED: Pointer arithmetic to get the correct frame data
        frame_size_bytes := player.image.width * player.image.height * 4 // 4 bytes per pixel (RGBA)
        offset := uintptr(frame_size_bytes) * uintptr(player.current_frame)
        frame_data_ptr := rawptr(cast(uintptr)player.image.data + offset)
        rl.UpdateTexture(player.current_texture, frame_data_ptr)

    case .Directory:
        // For directories, we just point to the already-loaded texture (fast!)
        player.current_texture = player.cached_textures[player.current_frame]
    }
}

// Private helper to check for common image file extensions
_is_image_file :: proc(filename: string) -> bool {
    return strings.has_suffix(filename, ".png") ||
           strings.has_suffix(filename, ".bmp") ||
           strings.has_suffix(filename, ".tga") ||
           strings.has_suffix(filename, ".jpg") ||
           strings.has_suffix(filename, ".jpeg")
}


// --- Unchanged Procedures ---

// Set the destination rectangle for drawing
gif_player_set_dest_rect :: proc(player: ^GifPlayer, dest: rl.Rectangle) {
    player.dest_rect = dest
}

// Set the origin point for rotation and scaling
gif_player_set_origin :: proc(player: ^GifPlayer, origin: rl.Vector2) {
    player.origin = origin
}

// Set rotation angle in degrees
gif_player_set_rotation :: proc(player: ^GifPlayer, rotation: f32) {
    player.rotation = rotation
}

// Set tint color
gif_player_set_tint :: proc(player: ^GifPlayer, tint: rl.Color) {
    player.tint = tint
}

// Control playback
gif_player_play :: proc(player: ^GifPlayer) {
    player.is_playing = true
}

gif_player_pause :: proc(player: ^GifPlayer) {
    player.is_playing = false
}

// Set animation speed (frame delay)
gif_player_set_speed :: proc(player: ^GifPlayer, frame_delay: int) {
    player.frame_delay = math.clamp(frame_delay, MIN_FRAME_DELAY, MAX_FRAME_DELAY)
}

// Get current playback information
gif_player_get_current_frame :: proc(player: ^GifPlayer) -> int {
    return player.current_frame
}

gif_player_get_total_frames :: proc(player: ^GifPlayer) -> int {
    return int(player.total_frames)
}

gif_player_get_fps :: proc(player: ^GifPlayer) -> int {
    // Assumes a 60Hz update rate, which is typical for raylib games.
    // The actual FPS depends on your game loop's update frequency.
    return 60 / player.frame_delay
}

gif_player_is_playing :: proc(player: ^GifPlayer) -> bool {
    return player.is_playing
}
