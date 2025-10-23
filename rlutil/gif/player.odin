package gif

import "core:c"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

MAX_FRAME_DELAY :: 20
MIN_FRAME_DELAY :: 1
DEFAULT_FRAME_DELAY :: 8

// PlayerMode determines if the animation is from a single GIF or a directory of images
PlayerMode :: enum { GIF, Directory }

Player :: struct {
	image:           rl.Image,
	current_texture: rl.Texture2D,
	cached_textures: [dynamic]rl.Texture2D,
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
new_player :: proc() -> Player {
	return Player{
		frame_delay = DEFAULT_FRAME_DELAY,
		tint        = rl.WHITE,
		is_playing  = true,
		loop        = true,
		rotation    = 0,
	}
}

// Load a GIF file into the player
player_load :: proc(player: ^Player, filepath: cstring) -> bool {
	if player.is_loaded {
		player_unload(player)
	}
	player.image = rl.LoadImageAnim(filepath, &player.total_frames)
	if player.image.data == nil {
		rl.TraceLog(.WARNING, "GIF file '%s' could not be loaded.", filepath)
		return false
	}
	player.current_texture = rl.LoadTextureFromImage(player.image)
	player.source_rect = rl.Rectangle{0, 0, f32(player.current_texture.width), f32(player.current_texture.height)}	
	player.current_frame = 0
	player.frame_counter = 0
	player.is_loaded = true
	player.mode = .GIF
	return true
}

// Load an image sequence from a directory into the player
player_load_dir :: proc(player: ^Player, dir_path: string) -> bool {
    if player.is_loaded {
        player_unload(player)
    }
    // First, open the directory to get a handle
    dir_handle, open_err := os.open(dir_path)
    if open_err != 0 {
        rl.TraceLog(.WARNING, "Could not open directory '%s'.", dir_path)
        return false
    }
    defer os.close(dir_handle)

    // Read all entries in the directory using the handle
    dir_entries, dir_err := os.read_dir(dir_handle, -1)
    if dir_err != 0 {
        rl.TraceLog(.WARNING, "Could not read from directory '%s'.", dir_path)
        return false
    }
    defer os.file_info_slice_delete(dir_entries)

    // Filter for image files and store their paths
    image_filepaths := make([dynamic]string)
    defer delete(image_filepaths)

    for entry in dir_entries {
        if !entry.is_dir && _is_image_file(entry.name) {
            full_path := fmt.tprintf("%s/%s", dir_path, entry.name)
            append(&image_filepaths, full_path)
        }
    }
    if len(image_filepaths) == 0 {
        rl.TraceLog(.WARNING, "No image files found in directory '%s'.", dir_path)
        return false
    }
    // Sort file paths alphabetically to ensure correct animation order
    slice.sort(image_filepaths[:])

    // Load all images as textures and cache them
    player.cached_textures = make([dynamic]rl.Texture2D, 0, len(image_filepaths))
    for path in image_filepaths {
        texture := rl.LoadTexture(strings.clone_to_cstring(path))
        if texture.id <= 0 {
            rl.TraceLog(.WARNING, "Failed to load image texture: %s", path)
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
player_update :: proc(player: ^Player) {
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

// Draw the player
player_draw :: proc(player: ^Player) {
    if !player.is_loaded {
        return
    }
    rl.DrawTexturePro(
        player.current_texture,
        player.source_rect,
        player.dest_rect,
        player.origin,
        player.rotation,
        player.tint,
    )
}

// Clean up resources
player_unload :: proc(player: ^Player) {
	if player.is_loaded {
		switch player.mode {
		case .GIF:
			rl.UnloadTexture(player.current_texture)
			rl.UnloadImage(player.image)
		case .Directory:
			for texture in player.cached_textures {
				rl.UnloadTexture(texture)
			}
			delete(player.cached_textures)
		}
		player.is_loaded = false
	}
}

// Stop playback and reset to the first frame
player_stop :: proc(player: ^Player) {
	player.is_playing = false
	player.current_frame = 0
	player.frame_counter = 0
	if player.is_loaded {
		_update_current_texture(player)
	}
}

// Update texture with current frame data
@(private)
_update_current_texture :: proc(player: ^Player) {
	if !player.is_loaded {
		return
	}
	switch player.mode {
	case .GIF:
		frame_size_bytes := player.image.width * player.image.height * 4
		offset := uintptr(frame_size_bytes) * uintptr(player.current_frame)
		frame_data_ptr := rawptr(cast(uintptr)player.image.data + offset)
		rl.UpdateTexture(player.current_texture, frame_data_ptr)
	case .Directory:
		player.current_texture = player.cached_textures[player.current_frame]
	}
}

// Check common image file extensions
@(private)
_is_image_file :: proc(filename: string) -> bool {
	return strings.has_suffix(filename, ".png") ||
	       strings.has_suffix(filename, ".bmp") ||
	       strings.has_suffix(filename, ".tga") ||
	       strings.has_suffix(filename, ".jpg") ||
	       strings.has_suffix(filename, ".jpeg")
}

// Set the destination rectangle for drawing
player_set_dest_rect :: proc(player: ^Player, dest: rl.Rectangle) {
	player.dest_rect = dest
}

// Set the origin point for rotation and scaling
player_set_origin :: proc(player: ^Player, origin: rl.Vector2) {
	player.origin = origin
}

// Set rotation angle in degrees
player_set_rotation :: proc(player: ^Player, rotation: f32) {
	player.rotation = rotation
}

// Set tint color
player_set_tint :: proc(player: ^Player, tint: rl.Color) {
	player.tint = tint
}

// Control playback
player_play :: proc(player: ^Player) {
	player.is_playing = true
}

player_pause :: proc(player: ^Player) {
	player.is_playing = false
}

// Set animation speed (frame delay)
player_set_speed :: proc(player: ^Player, frame_delay: int) {
	player.frame_delay = clamp(frame_delay, MIN_FRAME_DELAY, MAX_FRAME_DELAY)
}

// Get current playback information
player_get_current_frame :: proc(player: ^Player) -> int {
	return player.current_frame
}

player_get_total_frames :: proc(player: ^Player) -> int {
	return int(player.total_frames)
}

player_get_fps :: proc(player: ^Player) -> int {
	return 60 / player.frame_delay
}

player_is_playing :: proc(player: ^Player) -> bool {
	return player.is_playing
}